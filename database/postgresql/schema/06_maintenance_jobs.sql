-- ============================================================
-- Archivo   : 06_maintenance_jobs.sql
-- Descripción: Trabajos de mantenimiento periódico para Ecommify.
--              Incluye pg_cron jobs (disponibles en Supabase),
--              funciones de monitoreo OLTP y OLAP, y consultas
--              de diagnóstico listas para ejecutar.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- ── SECCIÓN 1: Jobs con pg_cron ───────────────────────────────
--
-- pg_cron está disponible en Supabase como extensión administrada.
-- Requiere: CREATE EXTENSION IF NOT EXISTS pg_cron;
-- (con permisos de superuser o vía Supabase Dashboard)
--
-- Descomentar los bloques SELECT cron.schedule(...) para activar.

-- ── 1a. VACUUM ANALYZE diario (2:00 AM) ──────────────────────
-- VACUUM recupera espacio de filas muertas y actualiza las
-- estadísticas del planner. Crítico en tablas de alta rotación.
/*
SELECT cron.schedule(
  'vacuum-orders-daily',
  '0 2 * * *',
  $$VACUUM ANALYZE orders; VACUUM ANALYZE order_items; VACUUM ANALYZE payments;$$
);
*/

-- ── 1b. Refresh de vistas materializadas (domingos 2:00 AM) ──
-- CONCURRENTLY permite lectura sin bloqueo durante el refresh.
-- Requiere UNIQUE INDEX en cada MV (creados en 04_materialized_views.sql).
/*
SELECT cron.schedule(
  'refresh-mvs-weekly',
  '0 2 * * 0',
  $$CALL sp_refresh_all_mvs();$$
);
*/

-- ── 1c. Crear partición del trimestre siguiente (día 1 del mes) ─
/*
SELECT cron.schedule(
  'create-next-partition-monthly',
  '0 3 1 * *',
  $$SELECT fn_create_next_orders_partition();$$
);
*/

-- ── 1d. REINDEX mensual en índices críticos (1er domingo, 4 AM) ─
-- CONCURRENTLY evita bloqueos; solo disponible en índices únicos
-- y de tablas no particionadas. Para particionadas, reindexar
-- partición por partición.
/*
SELECT cron.schedule(
  'reindex-monthly',
  '0 4 1-7 * 0',
  $$
    REINDEX INDEX CONCURRENTLY idx_customers_email;
    REINDEX INDEX CONCURRENTLY idx_products_name_trgm;
    REINDEX INDEX CONCURRENTLY idx_products_specifications;
    REINDEX INDEX CONCURRENTLY idx_products_tags;
  $$
);
*/

-- ── 1e. Limpiar alertas de stock resueltas (mensual) ─────────
/*
SELECT cron.schedule(
  'clean-stock-alerts-monthly',
  '0 5 1 * *',
  $$DELETE FROM stock_alerts WHERE resolved = TRUE AND alerted_at < NOW() - INTERVAL '90 days';$$
);
*/

-- ── Listar/cancelar jobs pg_cron ─────────────────────────────
-- SELECT jobid, jobname, schedule, command, active FROM cron.job;
-- SELECT cron.unschedule('nombre-del-job');

-- ============================================================
-- SECCIÓN 2: Monitoreo OLTP
-- ============================================================

-- ── 2a. Cache hit ratio ───────────────────────────────────────
-- Un ratio < 95% indica que la base de datos está leyendo más
-- del disco de lo esperado → aumentar shared_buffers.
CREATE OR REPLACE VIEW v_cache_hit_ratio AS
SELECT
  'index'                                         AS tipo,
  SUM(idx_blks_hit)                               AS hits,
  SUM(idx_blks_read)                              AS reads,
  ROUND(
    SUM(idx_blks_hit)::NUMERIC /
    NULLIF(SUM(idx_blks_hit + idx_blks_read), 0) * 100, 2
  )                                               AS hit_ratio_pct
FROM pg_statio_user_indexes
UNION ALL
SELECT
  'heap',
  SUM(heap_blks_hit),
  SUM(heap_blks_read),
  ROUND(
    SUM(heap_blks_hit)::NUMERIC /
    NULLIF(SUM(heap_blks_hit + heap_blks_read), 0) * 100, 2
  )
FROM pg_statio_user_tables;

COMMENT ON VIEW v_cache_hit_ratio IS
  'Monitoreo de caché de PostgreSQL. '
  'Objetivo: hit_ratio_pct > 95% en producción. '
  'Si es menor, considerar aumentar shared_buffers.';

-- ── 2b. Conexiones activas por estado ────────────────────────
CREATE OR REPLACE VIEW v_active_connections AS
SELECT
  state,
  wait_event_type,
  wait_event,
  COUNT(*)          AS count,
  MAX(NOW() - query_start) AS max_duration
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
GROUP BY state, wait_event_type, wait_event
ORDER BY count DESC;

COMMENT ON VIEW v_active_connections IS
  'Resumen de conexiones activas agrupadas por estado. '
  'Detecta conexiones colgadas (state = idle in transaction).';

-- ── 2c. Queries lentas (pg_stat_statements) ──────────────────
-- Requiere pg_stat_statements (01_extensions.sql).
CREATE OR REPLACE VIEW v_slow_queries AS
SELECT
  LEFT(query, 120)                               AS query_snippet,
  calls,
  ROUND(total_exec_time::NUMERIC / 1000, 2)      AS total_sec,
  ROUND(mean_exec_time::NUMERIC,  2)             AS avg_ms,
  ROUND(stddev_exec_time::NUMERIC, 2)            AS stddev_ms,
  rows,
  shared_blks_hit,
  shared_blks_read
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY mean_exec_time DESC
LIMIT 20;

COMMENT ON VIEW v_slow_queries IS
  'Top 20 queries más lentas (avg_ms). '
  'Ejecutar: SELECT * FROM v_slow_queries; '
  'Resetear estadísticas: SELECT pg_stat_statements_reset();';

-- ── 2d. Índices no usados (candidatos a eliminar) ────────────
CREATE OR REPLACE VIEW v_unused_indexes AS
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
  idx_scan  AS scans,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexname NOT LIKE '%_pkey'
  AND indexname NOT LIKE '%_key'
ORDER BY pg_relation_size(indexname::regclass) DESC;

COMMENT ON VIEW v_unused_indexes IS
  'Índices con 0 escaneos desde el último pg_stat_reset. '
  'Revisar antes de eliminar: pueden ser útiles en queries esporádicas.';

-- ── 2e. Tablas con más dead tuples (candidatas a VACUUM) ─────
CREATE OR REPLACE VIEW v_bloat_tables AS
SELECT
  relname                                         AS tabla,
  n_dead_tup                                      AS dead_tuples,
  n_live_tup                                      AS live_tuples,
  ROUND(n_dead_tup::NUMERIC /
        NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS bloat_pct,
  last_vacuum,
  last_autovacuum,
  last_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 15;

-- ============================================================
-- SECCIÓN 3: Monitoreo OLAP
-- ============================================================

-- ── 3a. Tamaño de cada partición de orders ───────────────────
CREATE OR REPLACE VIEW v_partition_sizes AS
SELECT
  c.relname                                                 AS particion,
  pg_size_pretty(pg_total_relation_size(c.oid))             AS tamaño_total,
  pg_size_pretty(pg_relation_size(c.oid))                   AS tamaño_datos,
  pg_size_pretty(pg_indexes_size(c.oid))                    AS tamaño_indices,
  pg_total_relation_size(c.oid)                             AS bytes
FROM pg_class c
JOIN pg_inherits i ON i.inhrelid = c.oid
JOIN pg_class p    ON p.oid      = i.inhparent
WHERE p.relname = 'orders'
ORDER BY bytes DESC;

COMMENT ON VIEW v_partition_sizes IS
  'Tamaño de cada partición de orders. '
  'Ejecutar mensualmente para planificar archivado de datos fríos.';

-- ── 3b. Antigüedad del último refresh de cada MV ─────────────
CREATE OR REPLACE VIEW v_mv_freshness AS
SELECT
  schemaname,
  matviewname,
  pg_size_pretty(pg_total_relation_size(matviewname::regclass)) AS size,
  ispopulated,
  -- pg_stat_user_tables registra el último analyze/vacuum de la MV
  (SELECT last_analyze FROM pg_stat_user_tables
   WHERE relname = matviewname)                                   AS last_analyzed,
  NOW() - (SELECT last_analyze FROM pg_stat_user_tables
            WHERE relname = matviewname)                          AS age
FROM pg_matviews
WHERE schemaname = 'public'
ORDER BY matviewname;

COMMENT ON VIEW v_mv_freshness IS
  'Antigüedad del último refresh de las vistas materializadas. '
  'Si age > 7 días, ejecutar: CALL sp_refresh_all_mvs();';

-- ── 3c. Estadísticas de particiones (filas por partición) ────
CREATE OR REPLACE VIEW v_partition_stats AS
SELECT
  c.relname                                   AS particion,
  c.reltuples::BIGINT                         AS filas_estimadas,
  pg_size_pretty(pg_relation_size(c.oid))     AS tamaño_datos
FROM pg_class c
JOIN pg_inherits i ON i.inhrelid = c.oid
JOIN pg_class p    ON p.oid      = i.inhparent
WHERE p.relname = 'orders'
ORDER BY c.relname;

-- ── Cheatsheet de mantenimiento manual ───────────────────────
-- Ejecutar en psql o SQL editor de Supabase:
--
-- 1. VACUUM manual urgente:
--    VACUUM (ANALYZE, VERBOSE) orders;
--
-- 2. Refresh manual de MVs:
--    CALL sp_refresh_all_mvs();
--
-- 3. Crear partición del próximo trimestre:
--    SELECT fn_create_next_orders_partition();
--
-- 4. Ver queries activas largas (> 30 seg):
--    SELECT pid, now() - pg_stat_activity.query_start AS duracion,
--           query, state
--    FROM pg_stat_activity
--    WHERE (now() - pg_stat_activity.query_start) > interval '30 seconds';
--
-- 5. Cancelar query bloqueada:
--    SELECT pg_cancel_backend(<pid>);
--
-- 6. Ver jobs pg_cron activos:
--    SELECT jobid, jobname, schedule, active FROM cron.job;
