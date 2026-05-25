# Extensiones PostgreSQL — Ecommify

**Proyecto:** Ecommify — Plataforma E-commerce Multivendedor de Productos Tecnológicos  
**Universidad:** Universidad de La Sabana — Maestría en Arquitectura de Software  
**Autores:** David Ricardo Grandas Cárdenas · Danilo Andrés Cortés Saavedra · Edisson Steven Bustos Galeano  
**Fecha:** 2026-05-21

---

## Resumen ejecutivo

| Extensión | Versión mín. | Estado | Caso de uso principal en Ecommify |
|---|---|---|---|
| pgcrypto | 1.3 | **Usar** | Hash de contraseñas (crypt/gen_salt) y gen_random_uuid() para PKs |
| uuid-ossp | 1.1 | **Usar** | Generación de UUIDs RFC 4122 en entornos distribuidos |
| pg_trgm | 1.6 | **Usar** | Búsqueda de productos tolerante a errores tipográficos |
| btree_gin | 1.3 | **Usar** | Índices GIN sobre TEXT[] (tags) y JSONB (specifications) |
| btree_gist | 1.7 | **Usar** | Restricción EXCLUDE en promotions (no solapamiento temporal) |
| pg_stat_statements | 1.10 | **Usar** | Identificar queries lentas en producción |
| PostGIS | 3.x | **Evaluar** | Distancia vendedor-cliente para costo de envío |
| hstore | 1.8 | **Descartar** | Reemplazado por JSONB con mayor funcionalidad |

---

## pg_trgm — Búsqueda aproximada por trigramas

### Descripción técnica

Divide cada cadena en grupos de 3 caracteres consecutivos (trigramas) y calcula similitud entre strings usando el coeficiente de Dice. El operador `%` retorna `true` si la similitud supera el umbral `pg_trgm.similarity_threshold` (por defecto 0.3). La función `similarity()` retorna un valor flotante de 0 a 1.

### Caso de uso en Ecommify

Un cliente escribe "Samsug Galxy" en el buscador. Sin pg_trgm, la query `LIKE '%Samsug Galxy%'` retorna 0 resultados. Con pg_trgm:

```sql
-- Habilitar índice trigram sobre el nombre del producto
CREATE INDEX idx_products_name_trgm
  ON products USING GIN (name gin_trgm_ops);

-- Búsqueda tolerante a errores tipográficos
SELECT id, name, price,
       similarity(name, 'Samsug Galxy') AS score
FROM products
WHERE name % 'Samsug Galxy'
ORDER BY score DESC
LIMIT 10;

-- Resultado: "Smartphone Samsung Galaxy A54" (score ≈ 0.42)
```

### Decisión final

**Usar.** El catálogo de Ecommify tiene nombres de productos con marcas en inglés, portugués y español. Los usuarios hispanohablantes cometen errores tipográficos frecuentes en marcas inglesas (Samsung, Logitech, Keychron). pg_trgm es la solución estándar en PostgreSQL para este caso. Alternativa considerada: búsqueda full-text `tsvector/tsquery`, pero no tolera errores de escritura en palabras completas.

### Instalación

```sql
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
```

---

## PostGIS — Cálculo geoespacial

### Descripción técnica

Agrega tipos geométricos (`GEOMETRY`, `GEOGRAPHY`) y funciones espaciales (`ST_Distance`, `ST_DWithin`, `ST_Contains`) a PostgreSQL. Permite calcular distancias reales sobre la esfera terrestre y construir índices GiST espaciales.

### Caso de uso en Ecommify

La tabla `geolocation` (dataset Olist) contiene latitud/longitud de vendedores y clientes. PostGIS permite estimar el costo de envío según la distancia real:

```sql
-- Agregar columna de geometría a geolocation
ALTER TABLE geolocation
  ADD COLUMN IF NOT EXISTS geom GEOGRAPHY(POINT, 4326);

UPDATE geolocation
  SET geom = ST_MakePoint(longitude, latitude)::GEOGRAPHY;

-- Distancia vendedor → cliente (en km)
SELECT
  v.city                               AS ciudad_vendedor,
  c.city                               AS ciudad_cliente,
  ROUND(
    ST_Distance(v.geom, c.geom) / 1000, 1
  )                                    AS distancia_km,
  -- Tarifa estimada: $2 USD por cada 100 km
  ROUND(ST_Distance(v.geom, c.geom) / 1000 * 0.02, 2) AS costo_envio_usd
FROM geolocation v, geolocation c
WHERE v.zip_code_prefix = '01310'   -- São Paulo (vendedor)
  AND c.zip_code_prefix = '20040';  -- Río de Janeiro (cliente)
```

### Decisión final

**Evaluar.** PostGIS es la herramienta correcta para el cálculo de envíos georreferenciados, pero en Supabase requiere habilitar la extensión desde el dashboard (no es superuser). Para el MVP actual, el costo de envío se calcula con una tarifa fija por estado (campo `geolocation.state`). PostGIS se habilita en la fase de escalamiento cuando se implemente envío dinámico.

### Instalación

```sql
-- En Supabase: Dashboard → Database → Extensions → postgis
-- En PostgreSQL vanilla (requiere superuser):
CREATE EXTENSION IF NOT EXISTS "postgis";
```

---

## pgcrypto — Criptografía y hash de contraseñas

### Descripción técnica

Provee funciones de hash (SHA-256, SHA-512, bcrypt), cifrado simétrico (AES) y asimétrico (PGP), y generación de números aleatorios criptográficamente seguros. La función `gen_random_uuid()` genera UUIDs v4 seguros.

### Caso de uso en Ecommify

```sql
-- Hash de contraseña al registrar usuario (rounds=10 ≈ 100ms)
INSERT INTO customers (name, email, password_hash)
VALUES (
  'Ana García',
  'ana@example.com',
  crypt('MiContrasena123!', gen_salt('bf', 10))
);

-- Verificación al hacer login
SELECT id, name
FROM customers
WHERE email = 'ana@example.com'
  AND password_hash = crypt('MiContrasena123!', password_hash);

-- Generar UUID para una nueva orden
SELECT gen_random_uuid();
-- → 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
```

### Decisión final

**Usar.** pgcrypto está activa desde `00_base_schema.sql`. Es la extensión más crítica del sistema: toda autenticación y generación de PKs depende de ella. El backend Node.js usa `bcryptjs` para el hash en la capa de aplicación, pero pgcrypto permite operaciones de seguridad directamente en la BD (stored procedures, scripts de migración).

### Instalación

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

---

## uuid-ossp — UUIDs distribuidos RFC 4122

### Descripción técnica

Provee `uuid_generate_v4()` (aleatorio) y `uuid_generate_v1()` (basado en timestamp + MAC). En PostgreSQL 13+, `gen_random_uuid()` de pgcrypto es equivalente a `uuid_generate_v4()` sin necesidad de uuid-ossp.

### Caso de uso en Ecommify

```sql
-- En entornos con múltiples nodos generando IDs de forma independiente
-- (replicación lógica, microservicios):
SELECT uuid_generate_v4();   -- UUID v4 (aleatorio)
SELECT uuid_generate_v1mc(); -- UUID v1 monotónico (ordenable por tiempo)

-- uuid_generate_v1mc() es útil si se necesita que los UUIDs de orders
-- sean ordenables cronológicamente sin almacenar created_at en el índice.
```

### Decisión final

**Usar** (con matiz). En PostgreSQL 13+ (Supabase usa PG 15), `gen_random_uuid()` cubre el caso de uso principal. uuid-ossp se activa para acceder a variantes como `uuid_generate_v1mc()` si en el futuro se decide migrar las PKs a UUIDs ordenables (mejor rendimiento en B-tree con inserciones secuenciales).

### Instalación

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

---

## btree_gin — Índices GIN sobre tipos btree

### Descripción técnica

Permite crear índices GIN (Generalized Inverted Index) sobre tipos de datos que normalmente usan B-tree (TEXT, INTEGER, TIMESTAMPTZ, UUID). Los índices GIN son más eficientes que B-tree para consultas de membresía en arrays y operadores `@>` (containment) en JSONB.

### Caso de uso en Ecommify

```sql
-- Sin btree_gin, un índice GIN en TEXT[] funciona pero no puede
-- combinarse con otros predicados en un index scan.
-- Con btree_gin, se pueden crear índices compuestos GIN+BTree:

-- Índice GIN sobre el array de tags:
CREATE INDEX idx_products_tags ON products USING GIN (tags);

-- Consulta: productos con tag 'gaming' a precio < 500
SELECT name, price FROM products
WHERE tags @> ARRAY['gaming']
  AND price < 500;
-- → PostgreSQL usa idx_products_tags para el filtro de array
--   y luego filtra por precio sobre el resultado reducido.
```

### Decisión final

**Usar.** Ecommify almacena `tags TEXT[]` y `specifications JSONB` en `products`. Los índices GIN sobre estas columnas (creados en `02_advanced_types.sql`) son el mecanismo correcto para las búsquedas del catálogo. Sin btree_gin, los índices GIN no pueden combinarse con predicados B-tree en index scans compuestos.

### Instalación

```sql
CREATE EXTENSION IF NOT EXISTS "btree_gin";
```

---

## btree_gist — GiST sobre tipos btree (para EXCLUDE)

### Descripción técnica

Habilita índices GiST sobre tipos ordinales (UUID, TEXT, INTEGER). Es el prerrequisito para usar la cláusula `EXCLUDE USING GIST` con operadores de igualdad (`=`) sobre tipos no geométricos, combinados con operadores de rango (`&&`).

### Caso de uso en Ecommify

```sql
-- Sin btree_gist, esta restricción falla con:
-- "data type uuid has no default operator class for access method gist"
CREATE TABLE promotions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id       VARCHAR(100),
  promotion_period TSTZRANGE NOT NULL,
  -- Impide dos promociones solapadas en el tiempo para el mismo producto:
  EXCLUDE USING GIST (
    product_id WITH =,          -- btree_gist habilita = sobre VARCHAR en GiST
    promotion_period WITH &&    -- operador nativo de TSTZRANGE
  )
);

-- Consultar promociones activas ahora:
SELECT p.name, pr.discount_percent
FROM promotions pr
JOIN products p ON p.id = pr.product_id
WHERE NOW() <@ pr.promotion_period;
```

### Decisión final

**Usar.** La tabla `promotions` tiene un requisito de negocio crítico: ningún producto puede tener dos promociones activas simultáneas. La restricción `EXCLUDE USING GIST` garantiza esto a nivel de base de datos, sin necesidad de lógica en la aplicación. btree_gist es el único mecanismo que permite combinar `=` sobre UUID/VARCHAR con `&&` sobre TSTZRANGE en un índice GiST.

### Instalación

```sql
CREATE EXTENSION IF NOT EXISTS "btree_gist";
```

---

## pg_stat_statements — Monitoreo de queries lentas

### Descripción técnica

Registra estadísticas de ejecución de todas las queries: tiempo total, tiempo promedio, desviación estándar, número de llamadas, filas retornadas, bloques leídos desde caché vs disco. Accesible vía la vista `pg_stat_statements`.

### Caso de uso en Ecommify

```sql
-- Top 10 queries más lentas en promedio:
SELECT
  LEFT(query, 100)                           AS query,
  calls,
  ROUND(mean_exec_time::NUMERIC, 2)          AS avg_ms,
  ROUND(total_exec_time::NUMERIC / 1000, 2)  AS total_sec,
  shared_blks_read                           AS disco_reads
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Resetear estadísticas después de un deploy:
SELECT pg_stat_statements_reset();
```

### Decisión final

**Usar.** En Supabase está disponible sin configuración adicional. Es indispensable para identificar qué queries del catálogo (`/api/catalog`) o checkout necesitan índices nuevos. Se consulta vía la vista `v_slow_queries` definida en `06_maintenance_jobs.sql`.

### Instalación

```sql
-- En Supabase: ya activa por defecto.
-- En PostgreSQL vanilla: agregar en postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'
-- Luego:
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
```

---

## hstore — Almacenamiento clave-valor (descartada)

### Descripción técnica

Tipo de dato que almacena pares clave-valor planos como `'key1=>val1, key2=>val2'`. Precursor de JSONB, con menor funcionalidad.

### Caso de uso considerado

Almacenar las especificaciones técnicas de productos (`ram=16GB, storage=512GB`).

### Decisión final

**Descartar.** JSONB es estrictamente superior a hstore:
- JSONB soporta anidamiento (hstore solo un nivel)
- JSONB soporta arrays dentro de valores
- JSONB tiene operadores más ricos (`@>`, `#>>`, `jsonb_each`)
- JSONB tiene mejor soporte de índices GIN
- JSONB es el estándar de la industria para datos semi-estructurados en PostgreSQL 9.4+

hstore tiene utilidad solo en migraciones de sistemas legados. Ecommify usa JSONB en `products.specifications`, `sellers.business_hours` y `orders.shipping_address`.

---

## Orden de instalación recomendado

```sql
-- Ejecutar una sola vez por ambiente (dev/staging/prod):
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
-- Opcional (requiere habilitación en Supabase Dashboard):
-- CREATE EXTENSION IF NOT EXISTS "postgis";
```

Ver script completo: [`database/postgresql/schema/01_extensions.sql`](../database/postgresql/schema/01_extensions.sql)
