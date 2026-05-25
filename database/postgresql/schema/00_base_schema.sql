-- ============================================================
-- Archivo   : 00_base_schema.sql
-- Descripción: Esquema base de PostgreSQL — copia de referencia de
--              database/postgres/init.sql. NO modificar este archivo;
--              las extensiones y tipos avanzados van en 01_* y 02_*.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Vendedores ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sellers (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(255) NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Clientes ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           VARCHAR(255) NOT NULL,
    email          VARCHAR(255) UNIQUE NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    login_attempts INTEGER DEFAULT 0,
    last_login     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── Productos (referencia para gestión de inventario) ────────
CREATE TABLE IF NOT EXISTS products (
    id         VARCHAR(100) PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    seller_id  UUID REFERENCES sellers(id) ON DELETE SET NULL,
    stock      INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    price      NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Órdenes ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id         VARCHAR(20) UNIQUE NOT NULL,
    customer_id      UUID REFERENCES customers(id),
    total            NUMERIC(10,2) NOT NULL,
    status           VARCHAR(50) DEFAULT 'pending',
    shipping_address JSONB,
    payment_method   VARCHAR(50),
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── Ítems de orden ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     VARCHAR(20) REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id   VARCHAR(100),
    product_name VARCHAR(255),
    unit_price   NUMERIC(10,2),
    qty          INTEGER,
    subtotal     NUMERIC(10,2) GENERATED ALWAYS AS (unit_price * qty) STORED,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── Pagos ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     VARCHAR(20) REFERENCES orders(order_id),
    payment_type VARCHAR(50) NOT NULL,
    amount       NUMERIC(10,2) NOT NULL,
    installments INTEGER DEFAULT 1,
    status       VARCHAR(50) DEFAULT 'pending',
    processed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── Historial de stock ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_history (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id VARCHAR(100) REFERENCES products(id),
    seller_id  UUID REFERENCES sellers(id),
    old_stock  INTEGER NOT NULL,
    new_stock  INTEGER NOT NULL,
    delta      INTEGER GENERATED ALWAYS AS (new_stock - old_stock) STORED,
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Geolocalización (dataset Olist) ──────────────────────────
CREATE TABLE IF NOT EXISTS geolocation (
    zip_code_prefix VARCHAR(10),
    latitude        NUMERIC(10,7),
    longitude       NUMERIC(10,7),
    city            VARCHAR(100),
    state           VARCHAR(5),
    PRIMARY KEY (zip_code_prefix, latitude, longitude)
);

-- ── Índices ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_customers_email    ON customers(email);
CREATE INDEX IF NOT EXISTS idx_orders_customer    ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order  ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_products_seller    ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_payments_order     ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_stock_history_prod ON stock_history(product_id);
