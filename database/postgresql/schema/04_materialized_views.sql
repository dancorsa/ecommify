-- ============================================================
-- Archivo   : 04_materialized_views.sql
-- Descripción: Vistas materializadas OLAP para Ecommify.
--              Adaptadas al esquema real (orders.status, orders.created_at,
--              order_items.subtotal, payments.amount). Ejecutar DESPUÉS
--              de 03_partitioning.sql.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- ── MV 1: Ventas por categoría y mes ─────────────────────────
--
-- Por qué una vista materializada y no una vista normal:
--   • La agregación cruza orders + order_items + products (3 tablas).
--   • En producción con millones de órdenes, una vista normal tarda
--     varios segundos. La MV pre-computa el resultado y lo sirve
--     en milisegundos desde el índice UNIQUE.
--   • Se refresca semanalmente (domingos 2am) con CONCURRENTLY para
--     no bloquear queries de lectura durante el refresh.
--
-- Nota: products.category se agrega en 02_advanced_types.sql.
--       order_items.subtotal = unit_price * qty (columna GENERATED).

DROP MATERIALIZED VIEW IF EXISTS mv_sales_by_category_monthly;

CREATE MATERIALIZED VIEW mv_sales_by_category_monthly AS
SELECT
  DATE_PART('year',  o.created_at)::INT  AS year,
  DATE_PART('month', o.created_at)::INT  AS month,
  COALESCE(p.category, 'sin_categoria')  AS category,
  COUNT(DISTINCT o.id)                   AS total_orders,
  SUM(oi.subtotal)                       AS total_revenue,
  AVG(oi.subtotal)                       AS avg_item_value,
  SUM(o.total) / NULLIF(COUNT(DISTINCT o.id), 0) AS avg_order_value,
  COUNT(oi.id)                           AS total_items
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.id        = oi.product_id
WHERE o.status = 'delivered'
GROUP BY 1, 2, 3
WITH DATA;

-- Índice UNIQUE requerido para REFRESH CONCURRENTLY
CREATE UNIQUE INDEX ON mv_sales_by_category_monthly (year, month, category);
-- Índice adicional para filtros frecuentes en el dashboard
CREATE INDEX ON mv_sales_by_category_monthly (category);
CREATE INDEX ON mv_sales_by_category_monthly (year, month);

COMMENT ON MATERIALIZED VIEW mv_sales_by_category_monthly IS
  'Ventas por categoría y mes (solo órdenes entregadas). '
  'REFRESH: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_by_category_monthly; '
  'Programar domingos 2am con pg_cron (ver 06_maintenance_jobs.sql).';

-- ── MV 2: Segmentación RFM de clientes ────────────────────────
--
-- RFM = Recency (días desde última compra), Frequency (# órdenes),
--       Monetary (gasto total). Estándar en e-commerce para campañas.
-- Segmentos:
--   VIP       → ≥5 órdenes Y gasto ≥$1000
--   Regular   → ≥3 órdenes
--   Occasional→ ≥2 órdenes
--   New       → 1 sola orden
--
-- Nota: payments.amount registra el valor de cada pago;
--       en Ecommify un pago puede ser fraccionado (installments),
--       por eso se suma amount por order para obtener el total pagado.

DROP MATERIALIZED VIEW IF EXISTS mv_customer_segments;

CREATE MATERIALIZED VIEW mv_customer_segments AS
WITH pagos_por_orden AS (
  -- Consolida pagos fraccionados en un total por orden
  SELECT order_id, SUM(amount) AS order_total
  FROM payments
  WHERE status = 'approved'
  GROUP BY order_id
),
resumen_cliente AS (
  SELECT
    c.id                                                        AS customer_id,
    c.name                                                      AS customer_name,
    c.email                                                     AS customer_email,
    COUNT(DISTINCT o.id)                                        AS total_orders,
    COALESCE(SUM(pp.order_total), 0)                            AS total_spent,
    COALESCE(AVG(pp.order_total), 0)                            AS avg_order_value,
    EXTRACT(DAY FROM NOW() - MAX(o.created_at))                 AS days_since_last_order,
    MAX(o.created_at)                                           AS last_order_date
  FROM customers c
  LEFT JOIN orders o         ON o.customer_id = c.id
                             AND o.status = 'delivered'
  LEFT JOIN pagos_por_orden pp ON pp.order_id = o.order_id
  GROUP BY c.id, c.name, c.email
)
SELECT
  customer_id,
  customer_name,
  customer_email,
  total_orders,
  total_spent,
  avg_order_value,
  days_since_last_order,
  last_order_date,
  CASE
    WHEN total_orders >= 5 AND total_spent >= 1000 THEN 'VIP'
    WHEN total_orders >= 3                         THEN 'Regular'
    WHEN total_orders >= 2                         THEN 'Occasional'
    ELSE                                                'New'
  END AS customer_segment
FROM resumen_cliente
WITH DATA;

CREATE UNIQUE INDEX ON mv_customer_segments (customer_id);
CREATE INDEX        ON mv_customer_segments (customer_segment);
CREATE INDEX        ON mv_customer_segments (total_spent DESC);
CREATE INDEX        ON mv_customer_segments (days_since_last_order);

COMMENT ON MATERIALIZED VIEW mv_customer_segments IS
  'Segmentación RFM de clientes (VIP/Regular/Occasional/New). '
  'Incluye solo clientes con órdenes entregadas y pagos aprobados. '
  'REFRESH: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_segments;';

-- ── MV 3: Ranking de productos por rendimiento ───────────────
--
-- Útil para la página de inicio (top products), reportes de vendedores
-- y algoritmo de recomendación simple por popularidad.

DROP MATERIALIZED VIEW IF EXISTS mv_product_performance;

CREATE MATERIALIZED VIEW mv_product_performance AS
SELECT
  p.id                                               AS product_id,
  p.name                                             AS product_name,
  p.category,
  p.price                                            AS current_price,
  p.stock                                            AS current_stock,
  COUNT(DISTINCT oi.id)                              AS units_sold,
  COUNT(DISTINCT o.id)                               AS orders_count,
  COALESCE(SUM(oi.subtotal), 0)                      AS total_revenue,
  COALESCE(AVG(oi.unit_price), p.price)              AS avg_sale_price,
  -- Tasa de conversión: órdenes / (stock + vendidas)
  ROUND(
    COUNT(DISTINCT o.id)::NUMERIC /
    NULLIF(COUNT(DISTINCT o.id) + p.stock, 0) * 100, 2
  )                                                  AS conversion_rate_pct,
  RANK() OVER (PARTITION BY p.category
               ORDER BY SUM(oi.subtotal) DESC NULLS LAST) AS rank_in_category
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o       ON o.order_id    = oi.order_id
                        AND o.status = 'delivered'
GROUP BY p.id, p.name, p.category, p.price, p.stock
WITH DATA;

CREATE UNIQUE INDEX ON mv_product_performance (product_id);
CREATE INDEX        ON mv_product_performance (category, rank_in_category);
CREATE INDEX        ON mv_product_performance (total_revenue DESC);

COMMENT ON MATERIALIZED VIEW mv_product_performance IS
  'Rendimiento de productos: unidades vendidas, ingresos, '
  'precio promedio de venta y ranking dentro de su categoría. '
  'REFRESH: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_performance;';

-- ── Procedimiento de refresh coordinado ──────────────────────
-- Refresca las tres MVs en orden correcto (algunas dependen de datos
-- de otras). Llamar desde pg_cron o manualmente.

CREATE OR REPLACE PROCEDURE sp_refresh_all_mvs()
LANGUAGE plpgsql AS $$
BEGIN
  RAISE NOTICE 'Iniciando refresh de vistas materializadas — %', NOW();

  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_by_category_monthly;
  RAISE NOTICE '✓ mv_sales_by_category_monthly';

  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_segments;
  RAISE NOTICE '✓ mv_customer_segments';

  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_performance;
  RAISE NOTICE '✓ mv_product_performance';

  RAISE NOTICE 'Refresh completo — %', NOW();
END;
$$;

COMMENT ON PROCEDURE sp_refresh_all_mvs IS
  'Refresca las 3 MVs en orden. Invocar: CALL sp_refresh_all_mvs(); '
  'Programar domingos 2am con pg_cron (ver 06_maintenance_jobs.sql).';

-- ── Consulta de verificación de frescura ─────────────────────
-- SELECT schemaname, matviewname,
--        pg_size_pretty(pg_total_relation_size(matviewname::regclass)) AS size,
--        ispopulated
-- FROM pg_matviews
-- WHERE schemaname = 'public'
-- ORDER BY matviewname;
