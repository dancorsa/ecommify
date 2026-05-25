-- ============================================================
-- Archivo   : 03_partitioning.sql
-- Descripción: Particionamiento por rango de fecha (RANGE) sobre
--              la tabla orders de Ecommify. Estrategia: particiones
--              trimestrales históricas + partición DEFAULT para datos
--              futuros (órdenes nuevas de Ecommify 2025+).
--              Ejecutar DESPUÉS de 02_advanced_types.sql.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- ── Estrategia de particionamiento ───────────────────────────
--
-- Por qué RANGE sobre created_at:
--   • Las consultas analíticas siempre filtran por período (mes, trimestre).
--   • PostgreSQL puede hacer "partition pruning" y tocar solo las
--     particiones relevantes, ignorando el resto.
--   • Permite mover datos históricos fríos a tablespaces más lentos
--     (cold storage) sin afectar queries sobre datos recientes.
--
-- Consideración sobre FK:
--   order_items y payments referencian orders(order_id VARCHAR(20)).
--   En PostgreSQL 12+ las FK a tablas particionadas son válidas, pero
--   la columna referenciada debe estar cubierta por un UNIQUE que
--   incluya la clave de partición. Por eso:
--     • El UNIQUE de order_id en la tabla particionada incluye created_at.
--     • Las FKs existentes en order_items/payments se eliminan y
--       recrean como referencias débiles (sin FK de DB) documentadas
--       como "soft FK" — la integridad se garantiza en la capa de
--       aplicación y mediante triggers de auditoría.
--   Esta es la práctica estándar en sistemas OLAP con tablas particionadas.
--
-- Idempotencia: el script verifica si la tabla ya está particionada
-- antes de ejecutar el rename/recreate.

DO $$
BEGIN
  -- Solo ejecutar si orders aún NO es una tabla particionada
  IF NOT EXISTS (
    SELECT 1
    FROM pg_partitioned_table pt
    JOIN pg_class c ON c.oid = pt.partrelid
    WHERE c.relname = 'orders'
  ) THEN

    -- 1. Eliminar las FK que referencian orders(order_id) para poder renombrar
    ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_order_id_fkey;
    ALTER TABLE payments    DROP CONSTRAINT IF EXISTS payments_order_id_fkey;

    -- 2. Renombrar tabla original como respaldo
    ALTER TABLE orders RENAME TO orders_legacy;

    -- 3. Crear tabla particionada con las mismas columnas de 00_base_schema.sql
    --    más las columnas de updated_at agregadas en 02_advanced_types.sql.
    --    El PK incluye created_at (requisito de PostgreSQL para UNIQUE en
    --    tablas particionadas: la clave de partición debe estar en el PK).
    CREATE TABLE orders (
      id               UUID         NOT NULL DEFAULT gen_random_uuid(),
      order_id         VARCHAR(20)  NOT NULL,
      customer_id      UUID         REFERENCES customers(id),
      total            NUMERIC(10,2) NOT NULL,
      status           VARCHAR(50)  DEFAULT 'pending',
      shipping_address JSONB,
      payment_method   VARCHAR(50),
      created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
      updated_at       TIMESTAMPTZ,
      PRIMARY KEY (id, created_at),
      -- UNIQUE incluye created_at por requisito de particionamiento.
      -- Esto permite referencias desde order_items/payments si se
      -- quiere implementar FK compuesta en el futuro.
      UNIQUE (order_id, created_at)
    ) PARTITION BY RANGE (created_at);

    -- 4. Crear particiones

    -- Datos históricos previos a Ecommify (por compatibilidad con dataset Olist)
    CREATE TABLE IF NOT EXISTS orders_2016_2017 PARTITION OF orders
      FOR VALUES FROM ('2016-01-01') TO ('2018-01-01');

    CREATE TABLE IF NOT EXISTS orders_2018_q1 PARTITION OF orders
      FOR VALUES FROM ('2018-01-01') TO ('2018-04-01');

    CREATE TABLE IF NOT EXISTS orders_2018_q2 PARTITION OF orders
      FOR VALUES FROM ('2018-04-01') TO ('2018-07-01');

    CREATE TABLE IF NOT EXISTS orders_2018_q3 PARTITION OF orders
      FOR VALUES FROM ('2018-07-01') TO ('2018-10-01');

    CREATE TABLE IF NOT EXISTS orders_2018_q4 PARTITION OF orders
      FOR VALUES FROM ('2018-10-01') TO ('2019-01-01');

    -- Particiones para datos actuales de Ecommify (2025+)
    CREATE TABLE IF NOT EXISTS orders_2025_q1 PARTITION OF orders
      FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');

    CREATE TABLE IF NOT EXISTS orders_2025_q2 PARTITION OF orders
      FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');

    CREATE TABLE IF NOT EXISTS orders_2025_q3 PARTITION OF orders
      FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');

    CREATE TABLE IF NOT EXISTS orders_2025_q4 PARTITION OF orders
      FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');

    CREATE TABLE IF NOT EXISTS orders_2026_q1 PARTITION OF orders
      FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');

    CREATE TABLE IF NOT EXISTS orders_2026_q2 PARTITION OF orders
      FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');

    -- Captura todo lo que no encaje en particiones anteriores
    CREATE TABLE IF NOT EXISTS orders_future PARTITION OF orders DEFAULT;

    -- 5. Migrar datos de la tabla original
    INSERT INTO orders (id, order_id, customer_id, total, status,
                        shipping_address, payment_method, created_at)
    SELECT id, order_id, customer_id, total, status,
           shipping_address, payment_method, created_at
    FROM orders_legacy;

    RAISE NOTICE 'Migración completa: % filas migradas a orders particionada.',
                 (SELECT COUNT(*) FROM orders_legacy);

  ELSE
    RAISE NOTICE 'La tabla orders ya está particionada. No se realizaron cambios.';
  END IF;
END;
$$;

-- ── Índices locales en particiones más consultadas ────────────
-- Los índices en tablas particionadas son locales a cada partición.
-- Crear índices en las particiones con mayor volumen de consultas.

-- Particiones históricas 2018 (simulación dataset Olist)
CREATE INDEX IF NOT EXISTS idx_orders_2018_q3_customer
  ON orders_2018_q3 (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_2018_q3_status
  ON orders_2018_q3 (status);

CREATE INDEX IF NOT EXISTS idx_orders_2018_q4_customer
  ON orders_2018_q4 (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_2018_q4_status
  ON orders_2018_q4 (status);

-- Particiones activas 2025-2026
CREATE INDEX IF NOT EXISTS idx_orders_2025_q1_customer
  ON orders_2025_q1 (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_2025_q1_status
  ON orders_2025_q1 (status);

CREATE INDEX IF NOT EXISTS idx_orders_2026_q1_customer
  ON orders_2026_q1 (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_2026_q1_status
  ON orders_2026_q1 (status);

CREATE INDEX IF NOT EXISTS idx_orders_2026_q2_customer
  ON orders_2026_q2 (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_2026_q2_status
  ON orders_2026_q2 (status);

-- ── Función para crear la partición del trimestre siguiente ───
-- Ejecutar mensualmente (o configurar con pg_cron, ver 06_maintenance_jobs.sql)
CREATE OR REPLACE FUNCTION fn_create_next_orders_partition()
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_start      DATE;
  v_end        DATE;
  v_part_name  TEXT;
BEGIN
  -- Próximo trimestre desde la fecha actual
  v_start := DATE_TRUNC('quarter', NOW() + INTERVAL '3 months');
  v_end   := v_start + INTERVAL '3 months';
  v_part_name := 'orders_' || TO_CHAR(v_start, 'YYYY') || '_q' ||
                 TO_CHAR(v_start, 'Q');

  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = v_part_name
  ) THEN
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS %I PARTITION OF orders '
      'FOR VALUES FROM (%L) TO (%L)',
      v_part_name, v_start, v_end
    );
    RAISE NOTICE 'Partición % creada: % → %', v_part_name, v_start, v_end;
  ELSE
    RAISE NOTICE 'Partición % ya existe.', v_part_name;
  END IF;
END;
$$;

-- ── Verificación de tamaño por partición ─────────────────────
-- Ejecutar para monitorear el crecimiento de datos:
--
-- SELECT
--   c.relname                                   AS particion,
--   pg_size_pretty(pg_total_relation_size(c.oid)) AS tamaño_total,
--   pg_total_relation_size(c.oid)               AS bytes
-- FROM pg_class c
-- JOIN pg_inherits i ON i.inhrelid = c.oid
-- JOIN pg_class p    ON p.oid = i.inhparent
-- WHERE p.relname = 'orders'
-- ORDER BY bytes DESC;
