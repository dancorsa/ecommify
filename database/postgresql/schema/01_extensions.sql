-- ============================================================
-- Archivo   : 01_extensions.sql
-- Descripción: Extensiones PostgreSQL para Ecommify.
--              pgcrypto ya está en 00_base_schema.sql; aquí solo
--              se agregan las extensiones complementarias.
--              Compatible con PostgreSQL 15+ / Supabase.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- pgcrypto ya existe (declarada en 00_base_schema.sql) — se incluye
-- con IF NOT EXISTS para garantizar idempotencia del script.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- → hash seguro de contraseñas (crypt/gen_salt) y tokens sensibles;
--   también provee gen_random_uuid() usado en todas las PKs.

-- Generación de UUIDs distribuidos compatibles con RFC 4122.
-- Necesaria en entornos donde múltiples nodos generan IDs de forma
-- independiente (replicación lógica, sharding futuro).
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Búsqueda aproximada/tolerante a errores tipográficos.
-- Caso de uso: un cliente escribe "Samsug Galxy" y el catálogo
-- retorna "Samsung Galaxy A54" gracias a similarity() y % operator.
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Índices GIN sobre tipos btree (TEXT, NUMERIC, TIMESTAMPTZ).
-- Necesaria para índices compuestos eficientes sobre columnas JSONB
-- y arrays TEXT[] en products.specifications y products.tags.
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Índices GiST sobre tipos btree (UUID, TEXT, etc.).
-- Requerida específicamente para la restricción EXCLUDE en la tabla
-- promotions: "EXCLUDE USING GIST (product_id WITH =, period WITH &&)"
-- que impide promociones solapadas en el tiempo para un mismo producto.
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Monitoreo de queries lentas en producción.
-- Permite consultar pg_stat_statements para identificar las N queries
-- más costosas y guiar la creación de índices o refactorización.
-- En Supabase: activar desde Dashboard → Database → Extensions.
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- PostGIS — cálculo geoespacial.
-- Caso de uso: calcular distancia vendedor-cliente para estimar costo
-- de envío. Ejemplo: ST_Distance(geom_vendedor, geom_cliente).
-- NOTA: requiere superuser en instalación vanilla. En Supabase
-- está disponible como extensión administrada sin permisos extra.
-- Descomentar cuando PostGIS esté habilitado en el entorno destino:
-- CREATE EXTENSION IF NOT EXISTS "postgis";

-- ── Verificación ─────────────────────────────────────────────
-- Consultar extensiones activas después de ejecutar este script:
-- SELECT name, default_version, installed_version
-- FROM pg_available_extensions
-- WHERE installed_version IS NOT NULL
-- ORDER BY name;
