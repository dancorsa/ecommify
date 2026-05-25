# Ecommify — Database Design & E-commerce Multivendedor

**Universidad de La Sabana — Maestría en Arquitectura de Software**

| | |
|---|---|
| **Proyecto** | Ecommify — Plataforma e-commerce multivendedor de productos tecnológicos |
| **Asignatura** | Fundamentos de Testing, Verificación y Validación / Arquitectura de Bases de Datos |
| **Integrantes** | David Ricardo Grandas Cárdenas · Danilo Andrés Cortés Saavedra · Edisson Steven Bustos Galeano |
| **Dataset** | [Brazilian E-Commerce (Olist) — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) |

---

## Arquitectura políglota de datos

Ecommify implementa una arquitectura de persistencia políglota donde cada motor resuelve el problema para el que está optimizado:

```
┌─────────────────────────────────────────────────────────────┐
│                     ECOMMIFY BACKEND                        │
│                    (Node.js + Express)                      │
└──────────────┬──────────────────────────┬───────────────────┘
               │                          │
       ┌───────▼────────┐        ┌────────▼────────┐
       │  PostgreSQL 16  │        │   MongoDB 7     │
       │  (transaccional)│        │  (documental)   │
       ├────────────────┤        ├─────────────────┤
       │ • sellers       │        │ • products      │
       │ • customers     │        │   (catálogo     │
       │ • products      │        │    rico + specs)│
       │   (inventario)  │        │ • reviews       │
       │ • orders        │        │ • user_behavior │
       │   (particionada)│        │   (TTL 30 días) │
       │ • order_items   │        │ • analytics_    │
       │ • payments      │        │   snapshots     │
       │ • promotions    │        │   (TTL 90 días) │
       │ • stock_history │        └─────────────────┘
       └────────────────┘
```

**PostgreSQL** maneja datos transaccionales (ACID): órdenes, pagos, inventario, autenticación.  
**MongoDB** maneja datos documentales: catálogo rico (specs variables por categoría), reseñas, eventos de comportamiento.

---

## Estructura del repositorio

```
ecommify/
├── database/
│   ├── postgres/                    ← Archivos originales del proyecto
│   │   ├── init.sql                 ← Schema base (fuente de verdad)
│   │   └── seed.sql                 ← Datos semilla básicos
│   ├── mongo/
│   │   └── seed.js                  ← Seed MongoDB original
│   │
│   ├── postgresql/                  ← Scripts avanzados PostgreSQL
│   │   ├── schema/
│   │   │   ├── 00_base_schema.sql   ← Copia de referencia de init.sql
│   │   │   ├── 01_extensions.sql    ← pg_trgm, btree_gin, btree_gist...
│   │   │   ├── 02_advanced_types.sql← JSONB, TEXT[], TSTZRANGE, promotions
│   │   │   ├── 03_partitioning.sql  ← orders particionada por RANGE(created_at)
│   │   │   ├── 04_materialized_views.sql ← MVs OLAP (ventas, segmentos, ranking)
│   │   │   ├── 05_triggers.sql      ← updated_at, auditoría status, stock
│   │   │   └── 06_maintenance_jobs.sql   ← pg_cron, monitoreo OLTP/OLAP
│   │   ├── seed_data/
│   │   │   └── 01_seed.sql          ← Seed enriquecido (tags, specs, promociones)
│   │   └── queries/
│   │       └── analytical_queries.sql ← 5 consultas avanzadas demostrativas
│   │
│   └── mongodb/
│       ├── schema/
│       │   ├── seed.js              ← Seed MongoDB enriquecido (4 colecciones)
│       │   └── collections_schema.json ← Schema formal + justificación técnica
│       └── notebooks/               ← Análisis exploratorios (Jupyter/Mongo Compass)
│
├── docs/
│   └── Extensiones_PostgreSQL_Ecommify.md ← Análisis detallado de extensiones
│
├── backend/                         ← API REST Node.js + Express
├── frontend/                        ← React + Vite servido por nginx
├── docker-compose.yml
└── .env.example
```

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Node.js 20 + Express 5 |
| Testing | Jest 29 (TDD patrón AAA + Given-When-Then) |
| BD relacional | PostgreSQL 16 con particionamiento, MVs y triggers |
| BD documental | MongoDB 7 con TTL indexes y schema validation |
| Frontend | React 18 + Vite 5 (servido por nginx) |
| Auth | JWT + bcryptjs (bcrypt rounds=10) |
| Contenedores | Docker + Docker Compose |

---

## Características de diseño de base de datos

### PostgreSQL — Características avanzadas

| Característica | Implementación | Archivo |
|---|---|---|
| **Extensiones** | pg_trgm, btree_gin, btree_gist, pgcrypto, uuid-ossp, pg_stat_statements | `01_extensions.sql` |
| **Tipos avanzados** | JSONB (specs), TEXT[] (tags/photos), TSTZRANGE (promotions) | `02_advanced_types.sql` |
| **Tipo compuesto** | `address_type` para direcciones estructuradas | `02_advanced_types.sql` |
| **Restricción EXCLUDE** | No solapamiento de promociones por producto | `02_advanced_types.sql` |
| **Particionamiento** | `orders` particionada por RANGE(created_at), trimestral | `03_partitioning.sql` |
| **Vistas materializadas** | `mv_sales_by_category_monthly`, `mv_customer_segments`, `mv_product_performance` | `04_materialized_views.sql` |
| **Triggers** | updated_at automático, auditoría de order_status, control de stock | `05_triggers.sql` |
| **Mantenimiento** | pg_cron jobs, vistas de monitoreo OLTP/OLAP | `06_maintenance_jobs.sql` |

### MongoDB — Características avanzadas

| Característica | Implementación |
|---|---|
| **TTL Index** | `user_behavior` (30 días) y `analytics_snapshots` (90 días) |
| **Schema Validation** | `$jsonSchema` en las 4 colecciones |
| **Índice de texto** | Búsqueda full-text en `products` (name + description) |
| **Índice compuesto** | `{category, price, rating}` para queries del catálogo |
| **4 colecciones** | `products`, `reviews`, `user_behavior`, `analytics_snapshots` |

---

## Setup con Docker (recomendado)

> Requiere [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y corriendo.

```bash
# 1. Clonar variables de entorno
cp .env.example .env

# 2. Levantar el stack completo
docker compose up -d
```

| Servicio | Puerto | Descripción |
|---|---|---|
| `ecommify-postgres` | `5432` | PostgreSQL 16 — carga schema y seed automáticamente |
| `ecommify-mongo` | `27017` | MongoDB 7 — 4 colecciones con datos de prueba |
| `ecommify-backend` | `3000` | API REST Node.js + Express |
| `ecommify-frontend` | `5173` | React servido por nginx |

Abrir **http://localhost:5173** en el navegador.

---

## Ejecutar los scripts PostgreSQL avanzados en orden

Los scripts son idempotentes (se pueden ejecutar múltiples veces sin error):

```bash
# Conectar a PostgreSQL del contenedor
docker exec -it ecommify-postgres psql -U postgres -d ecommify

# O con psql local
psql postgresql://postgres:password@localhost:5432/ecommify
```

```sql
-- Ejecutar en orden (cada script es prerequisito del siguiente)
\i database/postgresql/schema/00_base_schema.sql
\i database/postgresql/schema/01_extensions.sql
\i database/postgresql/schema/02_advanced_types.sql
\i database/postgresql/schema/03_partitioning.sql
\i database/postgresql/schema/04_materialized_views.sql
\i database/postgresql/schema/05_triggers.sql
\i database/postgresql/schema/06_maintenance_jobs.sql

-- Cargar datos enriquecidos
\i database/postgresql/seed_data/01_seed.sql

-- Ejecutar consultas analíticas demostrativas
\i database/postgresql/queries/analytical_queries.sql
```

---

## Ejecutar seed MongoDB enriquecido

```bash
# Seed original (4 colecciones: products, reviews, user_behavior, analytics_snapshots)
docker exec -it ecommify-mongo mongosh ecommify \
  /docker-entrypoint-initdb.d/seed.js

# O con el seed enriquecido del módulo de BD avanzada:
docker cp database/mongodb/schema/seed.js ecommify-mongo:/tmp/seed.js
docker exec -it ecommify-mongo mongosh ecommify /tmp/seed.js
```

---

## Credenciales de prueba

| Rol | Email | Contraseña |
|---|---|---|
| Vendedor | `techstore@ecommify.com` | `Test1234!` |
| Vendedor | `gadget@ecommify.com` | `Test1234!` |
| Cliente | `ana@example.com` | `Test1234!` |
| Cliente | `carlos@example.com` | `Test1234!` |

---

## Pruebas unitarias

### Resultados

- **67 tests** organizados en 6 módulos — 67/67 PASS
- **Cobertura:** Statements 98.3% · Branches 89.28% · Functions 100% · Lines 100%
- **Framework:** Jest 29 · **Patrones:** TDD + AAA + Given-When-Then

### Ejecutar tests

```bash
cd backend
npm test                 # Todos los tests
npm run test:coverage    # Con reporte de cobertura HTML
npm run test:ci          # Modo CI/CD
```

### Resultado de ejecución

```
-----------------------|---------|----------|---------|---------|
File                   | % Stmts | % Branch | % Funcs | % Lines |
-----------------------|---------|----------|---------|---------|
All files              |    98.3 |    89.28 |     100 |     100 |
 auth.service.js       |   93.33 |     87.5 |     100 |     100 |
 cart.service.js       |     100 |       75 |     100 |     100 |
 catalog.service.js    |     100 |     90.9 |     100 |     100 |
 checkout.service.js   |     100 |    88.88 |     100 |     100 |
 inventory.service.js  |     100 |      100 |     100 |     100 |
 reviews.service.js    |     100 |      100 |     100 |     100 |
-----------------------|---------|----------|---------|---------|
Test Suites: 6 passed, 6 total
Tests:       67 passed, 67 total
```

### Estructura de tests

```
backend/tests/
├── auth/auth.service.test.js           (14 tests — HU-01, HU-02)
├── catalog/catalog.service.test.js     ( 9 tests — HU-03, HU-04)
├── cart/cart.service.test.js           (11 tests — HU-05)
├── checkout/checkout.service.test.js   (10 tests — HU-06)
├── reviews/reviews.service.test.js     (12 tests — HU-07)
├── inventory/inventory.service.test.js (11 tests — HU-08)
└── evidence/test-output.txt           (log de ejecución completo)
```

### Documentación de testing

| Documento | Ubicación |
|---|---|
| Plan de pruebas | `backend/docs/TEST_PLAN.md` |
| Matriz de trazabilidad (67 filas) | `backend/docs/TRACEABILITY_MATRIX.md` |
| Reporte HTML de cobertura | `backend/coverage/index.html` |
| Log de ejecución | `backend/tests/evidence/test-output.txt` |

---

## API Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/register` | Registro de usuario |
| POST | `/api/auth/login` | Login y JWT |
| GET | `/api/catalog` | Listado con filtros (category, minPrice, maxPrice, minRating) |
| GET | `/api/catalog/:id` | Detalle de producto |
| GET | `/api/cart/:userId` | Ver carrito |
| POST | `/api/cart/:userId/items` | Agregar ítem |
| DELETE | `/api/cart/:userId/items/:productId` | Eliminar ítem |
| PATCH | `/api/cart/:userId/items/:productId` | Actualizar cantidad |
| POST | `/api/checkout/orders` | Crear orden |
| POST | `/api/reviews` | Publicar reseña |
| GET | `/api/reviews/product/:productId` | Reseñas de un producto |
| GET | `/api/inventory/seller/:sellerId` | Inventario del vendedor |
| PATCH | `/api/inventory/:productId` | Actualizar stock |

---

## Otros comandos Docker

```bash
# Ver logs en tiempo real
docker compose logs -f backend

# Reconstruir imágenes tras cambios en el código
docker compose up -d --build

# Detener todos los contenedores
docker compose down

# Detener y eliminar volúmenes (borra datos de BD)
docker compose down -v
```

---

## Documentación adicional

- [Extensiones PostgreSQL — análisis detallado](docs/Extensiones_PostgreSQL_Ecommify.md)
- [Schema formal MongoDB (colecciones + validación)](database/mongodb/schema/collections_schema.json)
- [Consultas analíticas avanzadas](database/postgresql/queries/analytical_queries.sql)
- [Dataset Olist en Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
