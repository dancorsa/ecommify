-- ============================================================
-- Archivo   : 05_triggers.sql
-- Descripción: Triggers de auditoría y automatización para Ecommify.
--              Requiere que 02_advanced_types.sql haya agregado
--              la columna updated_at en sellers, customers, products,
--              orders, order_items y payments.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- ── 1. Función reutilizable updated_at ───────────────────────
-- Una sola función TRIGGER para todas las tablas que tengan
-- la columna updated_at. Evita duplicación de lógica.

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_set_updated_at IS
  'Función trigger genérica: establece updated_at = NOW() antes '
  'de cada UPDATE. Aplicada a todas las tablas con esa columna.';

-- ── 2. Aplicar trigger updated_at a tablas existentes ────────
-- El bloque DO verifica que la columna updated_at exista antes de
-- crear el trigger (idempotente: DROP IF EXISTS + CREATE).

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'sellers', 'customers', 'products',
    'orders', 'order_items', 'payments', 'promotions'
  ] LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name   = t
        AND column_name  = 'updated_at'
    ) THEN
      EXECUTE format('
        DROP TRIGGER IF EXISTS trg_updated_at ON %I;
        CREATE TRIGGER trg_updated_at
        BEFORE UPDATE ON %I
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
      ', t, t);
      RAISE NOTICE 'Trigger trg_updated_at creado en tabla: %', t;
    ELSE
      RAISE NOTICE 'Tabla % no tiene columna updated_at — trigger omitido.', t;
    END IF;
  END LOOP;
END;
$$;

-- ── 3. Auditoría de cambios en orders.status ─────────────────
-- Registra cada transición de estado de una orden (pending → approved
-- → shipped → delivered) para trazabilidad y SLA de entregas.

CREATE TABLE IF NOT EXISTS order_status_history (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    VARCHAR(20) NOT NULL,
  old_status  VARCHAR(50),
  new_status  VARCHAR(50) NOT NULL,
  changed_at  TIMESTAMPTZ DEFAULT NOW(),
  changed_by  TEXT        DEFAULT current_user,
  -- IP/sesión de quien hizo el cambio (útil en contexto API)
  client_info TEXT
);

CREATE INDEX IF NOT EXISTS idx_status_history_order
  ON order_status_history (order_id, changed_at DESC);

COMMENT ON TABLE order_status_history IS
  'Log inmutable de transiciones de estado de órdenes. '
  'Permite calcular SLA (tiempo entre estados), detectar '
  'regresiones de estado y auditar cambios manuales.';

CREATE OR REPLACE FUNCTION fn_audit_order_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Solo registra si realmente cambió el estado
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO order_status_history (order_id, old_status, new_status)
    VALUES (NEW.order_id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$;

-- Aplicar sobre la tabla particionada orders.
-- En PostgreSQL 13+ los triggers AFTER UPDATE se heredan a las particiones.
DROP TRIGGER IF EXISTS trg_audit_order_status ON orders;
CREATE TRIGGER trg_audit_order_status
AFTER UPDATE OF status ON orders
FOR EACH ROW EXECUTE FUNCTION fn_audit_order_status();

-- ── 4. Trigger de control de stock en order_items ────────────
-- Decrementa products.stock automáticamente cuando se inserta
-- un ítem de orden. Evita que la lógica de negocio quede solo
-- en la capa de aplicación (defense in depth).

CREATE OR REPLACE FUNCTION fn_decrement_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Verificar stock suficiente antes de decrementar
  IF (SELECT stock FROM products WHERE id = NEW.product_id) < NEW.qty THEN
    RAISE EXCEPTION
      'Stock insuficiente para producto %. Stock disponible: %, solicitado: %',
      NEW.product_id,
      (SELECT stock FROM products WHERE id = NEW.product_id),
      NEW.qty;
  END IF;

  -- Decrementar stock
  UPDATE products
  SET stock = stock - NEW.qty
  WHERE id = NEW.product_id;

  -- Registrar en historial de stock
  INSERT INTO stock_history (product_id, seller_id, old_stock, new_stock)
  SELECT
    NEW.product_id,
    seller_id,
    stock + NEW.qty,  -- stock antes del decremento
    stock             -- stock después del decremento
  FROM products
  WHERE id = NEW.product_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_decrement_stock ON order_items;
CREATE TRIGGER trg_decrement_stock
AFTER INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION fn_decrement_stock();

COMMENT ON FUNCTION fn_decrement_stock IS
  'Decrementa products.stock y registra en stock_history al insertar '
  'un order_item. Lanza excepción si el stock es insuficiente, '
  'garantizando consistencia sin depender solo de la aplicación.';

-- ── 5. Trigger de alerta de stock bajo ───────────────────────
-- Registra en una tabla de alertas cuando stock cae por debajo
-- del umbral (útil para notificaciones push a vendedores).

CREATE TABLE IF NOT EXISTS stock_alerts (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  VARCHAR(100) REFERENCES products(id),
  seller_id   UUID        REFERENCES sellers(id),
  stock_level INTEGER     NOT NULL,
  threshold   INTEGER     NOT NULL DEFAULT 5,
  alerted_at  TIMESTAMPTZ DEFAULT NOW(),
  resolved    BOOLEAN     DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_stock_alerts_seller
  ON stock_alerts (seller_id, resolved, alerted_at DESC);

COMMENT ON TABLE stock_alerts IS
  'Alertas de stock bajo. El trigger trg_stock_alert inserta una fila '
  'cuando stock < 5. La columna resolved permite marcar alertas '
  'atendidas sin borrarlas (auditoría).';

CREATE OR REPLACE FUNCTION fn_check_stock_alert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_threshold INTEGER := 5;
BEGIN
  -- Alerta cuando el stock nuevo es bajo y el anterior era normal
  IF NEW.stock < v_threshold AND OLD.stock >= v_threshold THEN
    INSERT INTO stock_alerts (product_id, seller_id, stock_level, threshold)
    SELECT NEW.id, NEW.seller_id, NEW.stock, v_threshold;

    RAISE NOTICE 'ALERTA: Stock bajo en producto % (stock: %)',
                 NEW.id, NEW.stock;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stock_alert ON products;
CREATE TRIGGER trg_stock_alert
AFTER UPDATE OF stock ON products
FOR EACH ROW EXECUTE FUNCTION fn_check_stock_alert();

-- ── Verificación de triggers activos ─────────────────────────
-- SELECT event_object_table AS tabla,
--        trigger_name, event_manipulation AS evento,
--        action_timing AS momento
-- FROM information_schema.triggers
-- WHERE trigger_schema = 'public'
-- ORDER BY event_object_table, trigger_name;
