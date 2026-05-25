-- ============================================================
-- Archivo   : 02_advanced_types.sql
-- Descripción: Tipos avanzados, columnas nuevas y tabla promotions
--              para Ecommify. Todo es idempotente (IF NOT EXISTS /
--              columnas verificadas antes de alterar). Ejecutar
--              DESPUÉS de 00_base_schema.sql y 01_extensions.sql.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- ── a) Tipo compuesto para direcciones ───────────────────────
-- Reutilizado en shipping_address y en la API de checkout para
-- validar la estructura de dirección de forma centralizada.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'address_type'
  ) THEN
    CREATE TYPE address_type AS (
      street   VARCHAR(200),
      city     VARCHAR(100),
      state    VARCHAR(100),
      zip_code VARCHAR(20),
      country  VARCHAR(60)
    );
  END IF;
END;
$$;

-- ── b) Columna updated_at en tablas principales ───────────────
-- Necesaria para que los triggers de 05_triggers.sql funcionen
-- y para auditoría de cambios en OLTP.

ALTER TABLE sellers     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE customers   ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE products    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE orders      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE payments    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- ── c) Columnas avanzadas en products ────────────────────────

-- Categoría: sincronizada con el campo category de MongoDB.
-- VARCHAR en lugar de ENUM para permitir categorías dinámicas.
ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100);
COMMENT ON COLUMN products.category IS
  'Categoría del producto (smartphones, laptops, audio…). '
  'Espeja el campo category del catálogo MongoDB para habilitar '
  'las vistas analíticas mv_sales_by_category_monthly.';

-- JSONB permite almacenar atributos heterogéneos sin ALTER TABLE:
-- RAM para laptops, resolución para monitores, batería para audio.
ALTER TABLE products ADD COLUMN IF NOT EXISTS specifications JSONB DEFAULT '{}';
COMMENT ON COLUMN products.specifications IS
  'Atributos técnicos variables según categoría. JSONB elegido sobre '
  'columnas separadas porque cada categoría tiene specs distintas '
  '(RAM en laptops, cámara en smartphones, DPI en periféricos). '
  'Consultable con operadores @>, ->>, #>> y funciones jsonb_*.';

-- TEXT[] es más eficiente que una tabla pivote para URLs homogéneas.
-- Los índices GIN permiten búsqueda "qué productos tienen esta URL".
ALTER TABLE products ADD COLUMN IF NOT EXISTS photos TEXT[] DEFAULT '{}';
COMMENT ON COLUMN products.photos IS
  'URLs de imágenes del producto. Array nativo elegido sobre tabla '
  'product_photos porque el orden es relevante (primera = imagen '
  'principal) y las operaciones siempre son bulk (cargar/reemplazar '
  'todas las fotos de un producto a la vez).';

-- TEXT[] con índice GIN permite ANY(tags), @> y && en O(log n).
ALTER TABLE products ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
COMMENT ON COLUMN products.tags IS
  'Etiquetas de búsqueda full-text: ["laptop","gaming","i7"]. '
  'Combinado con pg_trgm habilita búsqueda tolerante a errores. '
  'Índice GIN creado abajo para consultas rápidas con operadores '
  'de array (@>, &&, ANY).';

-- ── d) Columnas avanzadas en sellers ─────────────────────────

ALTER TABLE sellers ADD COLUMN IF NOT EXISTS notification_emails TEXT[] DEFAULT '{}';
COMMENT ON COLUMN sellers.notification_emails IS
  'Lista de correos donde el vendedor recibe alertas de nuevas '
  'órdenes, stock bajo o cambios de estado. TEXT[] elegido para '
  'permitir múltiples destinatarios sin tabla auxiliar. '
  'Ejemplo: ["ops@tienda.com","dueno@tienda.com"].';

ALTER TABLE sellers ADD COLUMN IF NOT EXISTS business_hours JSONB DEFAULT '{}';
COMMENT ON COLUMN sellers.business_hours IS
  'Horarios de atención por día de la semana. JSONB permite '
  'estructura flexible (algunos vendedores no abren todos los días) '
  'y es consultable directamente: business_hours->>''monday''. '
  'Ejemplo: {"monday":"9:00-18:00","saturday":"9:00-13:00"}.';

-- ── e) Índices para las columnas nuevas ──────────────────────

-- GIN sobre JSONB: acelera consultas con @> (containment).
-- Ejemplo: WHERE specifications @> '{"ram":"16GB"}'
CREATE INDEX IF NOT EXISTS idx_products_specifications
  ON products USING GIN (specifications);

-- GIN sobre TEXT[]: acelera ANY, @>, && sobre tags.
-- Ejemplo: WHERE 'gaming' = ANY(tags)
CREATE INDEX IF NOT EXISTS idx_products_tags
  ON products USING GIN (tags);

-- B-tree estándar para filtros de catálogo por categoría+precio.
CREATE INDEX IF NOT EXISTS idx_products_category_price
  ON products (category, price);

-- Trigram sobre name: habilita similarity() y operador %.
-- Requiere pg_trgm (01_extensions.sql).
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON products USING GIN (name gin_trgm_ops);

-- GIN sobre notification_emails para búsqueda de vendedor por email de notif.
CREATE INDEX IF NOT EXISTS idx_sellers_notification_emails
  ON sellers USING GIN (notification_emails);

-- ── f) Tabla promotions (nueva) ───────────────────────────────
-- TSTZRANGE permite preguntar "¿está activa ahora?" con NOW() <@ period.
-- La restricción EXCLUDE garantiza que un producto no tenga dos
-- promociones activas solapadas en el tiempo (integridad de negocio).
CREATE TABLE IF NOT EXISTS promotions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id       VARCHAR(100) REFERENCES products(id) ON DELETE CASCADE,
  discount_percent NUMERIC(5,2) NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100),
  promotion_period TSTZRANGE   NOT NULL,
  description      TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ,
  -- Impide dos promociones solapadas para el mismo producto.
  -- Requiere extensión btree_gist (01_extensions.sql) para poder
  -- usar el operador = sobre UUID dentro de un índice GiST.
  EXCLUDE USING GIST (
    product_id WITH =,
    promotion_period WITH &&
  )
);

COMMENT ON TABLE promotions IS
  'Promociones con rango de tiempo estricto. El operador TSTZRANGE '
  'permite: WHERE NOW() <@ promotion_period para filtrar activas. '
  'La restricción EXCLUDE reemplaza la lógica de "no solapamiento" '
  'que normalmente requeriría triggers o checks en la aplicación.';

COMMENT ON COLUMN promotions.promotion_period IS
  'Rango de tiempo [inicio, fin] con timezone. Ejemplos de consulta: '
  'NOW() <@ promotion_period  → activa ahora; '
  'tstzrange(''2026-06-01'',''2026-06-30'') && promotion_period → solapamiento.';

CREATE INDEX IF NOT EXISTS idx_promotions_product
  ON promotions (product_id);

CREATE INDEX IF NOT EXISTS idx_promotions_period
  ON promotions USING GIST (promotion_period);
