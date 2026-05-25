-- ============================================================
-- Archivo   : analytical_queries.sql
-- Descripción: Consultas analíticas avanzadas para Ecommify.
--              Demuestran uso de pg_trgm, JSONB, arrays TEXT[],
--              TSTZRANGE (promotions) y vistas materializadas.
--              Ejecutar DESPUÉS de 04_materialized_views.sql.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- CONSULTA 1: Búsqueda tolerante a errores tipográficos (pg_trgm)
-- ════════════════════════════════════════════════════════════
--
-- Caso de uso: el cliente escribe "Samsug Galxy A54" en el buscador.
-- La búsqueda exacta con LIKE retorna 0 resultados.
-- pg_trgm compara trigramas y retorna el producto más similar.
--
-- Requiere: CREATE EXTENSION pg_trgm; (01_extensions.sql)
--           CREATE INDEX idx_products_name_trgm (02_advanced_types.sql)

-- 1a. Búsqueda simple con operador % (similarity > threshold)
SELECT
  id,
  name,
  category,
  price,
  ROUND(similarity(name, 'Samsug Galxy A54')::NUMERIC, 3) AS score_similitud
FROM products
WHERE name % 'Samsug Galxy A54'
ORDER BY score_similitud DESC;

-- 1b. Búsqueda con umbral explícito (más flexible que %)
SELECT
  id,
  name,
  category,
  price,
  ROUND(similarity(name, 'Logitech MX')::NUMERIC, 3) AS score
FROM products
WHERE similarity(name, 'Logitech MX') > 0.2
ORDER BY score DESC
LIMIT 5;

-- 1c. Búsqueda combinada: trigrama + filtro de precio
-- Busca "keycrohn" (error tipográfico de Keychron) en periféricos < $600
SELECT
  id,
  name,
  price,
  ROUND(similarity(name, 'keycrohn')::NUMERIC, 3) AS score
FROM products
WHERE name % 'keycrohn'
  AND category = 'peripherals'
  AND price < 600
ORDER BY score DESC;

-- ════════════════════════════════════════════════════════════
-- CONSULTA 2: Consultas JSONB sobre specifications de productos
-- ════════════════════════════════════════════════════════════
--
-- Caso de uso: filtros avanzados del catálogo ("laptops con 16GB RAM",
-- "monitores 4K", "smartphones con batería > 5000mAh").
--
-- Requiere: columna specifications JSONB (02_advanced_types.sql)
--           CREATE INDEX idx_products_specifications (02_advanced_types.sql)

-- 2a. Containment @>: productos con exactamente 16GB de RAM
SELECT id, name, price, specifications->>'ram' AS ram
FROM products
WHERE specifications @> '{"ram": "16GB"}';

-- 2b. Extracción con ->>: listar RAM de todos los productos que la tienen
SELECT
  id,
  name,
  category,
  price,
  specifications->>'ram'       AS ram,
  specifications->>'storage'   AS almacenamiento,
  specifications->>'processor' AS procesador
FROM products
WHERE specifications ? 'ram'         -- tiene la clave 'ram'
ORDER BY category, price;

-- 2c. Filtro en campo JSONB anidado: monitores con resolución 4K
SELECT id, name, price,
       specifications->>'resolution' AS resolucion,
       specifications->>'panel'      AS panel
FROM products
WHERE category = 'monitors'
  AND specifications->>'resolution' LIKE '%3840%';

-- 2d. jsonb_each: explorar todas las especificaciones de un producto
SELECT
  p.name,
  spec.key   AS atributo,
  spec.value AS valor
FROM products p,
     jsonb_each_text(p.specifications) AS spec
WHERE p.id = 'prod-002'
ORDER BY spec.key;

-- 2e. Aggregation: contar cuántos productos tienen cada valor de RAM
SELECT
  specifications->>'ram' AS ram,
  COUNT(*)               AS cantidad_productos,
  ROUND(AVG(price), 2)   AS precio_promedio
FROM products
WHERE specifications ? 'ram'
GROUP BY 1
ORDER BY cantidad_productos DESC;

-- ════════════════════════════════════════════════════════════
-- CONSULTA 3: Operadores de array (ANY, @>, &&)
-- ════════════════════════════════════════════════════════════
--
-- Caso de uso: búsqueda por etiquetas, filtros multi-valor del catálogo,
-- notificaciones a vendedores por email.
--
-- Requiere: columnas tags TEXT[], notification_emails TEXT[] (02_advanced_types.sql)
--           CREATE INDEX idx_products_tags GIN (02_advanced_types.sql)

-- 3a. ANY: productos que tengan el tag 'gaming'
SELECT id, name, price, tags
FROM products
WHERE 'gaming' = ANY(tags);

-- 3b. @> (contiene): productos con TODOS los tags ['bluetooth', 'anc']
SELECT id, name, price, tags
FROM products
WHERE tags @> ARRAY['bluetooth', 'anc'];

-- 3c. && (intersecta): productos con AL MENOS UNO de estos tags
SELECT id, name, price, tags
FROM products
WHERE tags && ARRAY['apple', 'samsung']
ORDER BY price DESC;

-- 3d. Array de emails: vendedores que reciben notificaciones en un dominio
SELECT id, name, notification_emails
FROM sellers
WHERE notification_emails && ARRAY['ops@techstore.com'];

-- 3e. Contar tags únicos y productos por tag (exploración del catálogo)
SELECT
  tag,
  COUNT(*) AS productos
FROM products, UNNEST(tags) AS tag
GROUP BY tag
ORDER BY productos DESC
LIMIT 15;

-- 3f. Productos sin tags asignados (para auditoría de contenido)
SELECT id, name, category
FROM products
WHERE tags = '{}'::TEXT[] OR tags IS NULL
ORDER BY category;

-- ════════════════════════════════════════════════════════════
-- CONSULTA 4: Promociones activas con operadores TSTZRANGE
-- ════════════════════════════════════════════════════════════
--
-- Caso de uso: mostrar badge "En oferta" en el catálogo, calcular
-- precio con descuento, verificar solapamiento de promociones.
--
-- Requiere: tabla promotions con TSTZRANGE (02_advanced_types.sql)

-- 4a. Promociones activas AHORA (core del catálogo de ofertas)
SELECT
  p.id                    AS product_id,
  p.name                  AS producto,
  p.price                 AS precio_original,
  pr.discount_percent,
  ROUND(
    p.price * (1 - pr.discount_percent / 100), 2
  )                       AS precio_con_descuento,
  pr.promotion_period,
  pr.description
FROM promotions pr
JOIN products p ON p.id = pr.product_id
WHERE NOW() <@ pr.promotion_period
ORDER BY pr.discount_percent DESC;

-- 4b. Cuántos días quedan para que expire una promoción activa
SELECT
  p.name                                               AS producto,
  pr.discount_percent,
  UPPER(pr.promotion_period)                           AS fecha_fin,
  EXTRACT(DAY FROM UPPER(pr.promotion_period) - NOW()) AS dias_restantes
FROM promotions pr
JOIN products p ON p.id = pr.product_id
WHERE NOW() <@ pr.promotion_period
ORDER BY dias_restantes ASC;

-- 4c. Verificar solapamiento: ¿choca una nueva promoción con las existentes?
-- (Antes de insertar, comprobar manualmente si EXCLUDE no es suficiente)
SELECT pr.id, pr.promotion_period, pr.description
FROM promotions pr
WHERE pr.product_id = 'prod-001'
  AND pr.promotion_period &&
      tstzrange('2026-05-15 00:00:00+00', '2026-06-15 23:59:59+00');

-- 4d. Historial de promociones de un producto (activas, pasadas y futuras)
SELECT
  p.name,
  pr.discount_percent,
  CASE
    WHEN NOW() <@ pr.promotion_period           THEN 'activa'
    WHEN UPPER(pr.promotion_period) < NOW()     THEN 'vencida'
    ELSE                                             'futura'
  END                          AS estado,
  pr.promotion_period,
  pr.created_at
FROM promotions pr
JOIN products p ON p.id = pr.product_id
WHERE pr.product_id = 'prod-001'
ORDER BY pr.created_at DESC;

-- ════════════════════════════════════════════════════════════
-- CONSULTA 5: Dashboard de ventas con vistas materializadas
-- ════════════════════════════════════════════════════════════
--
-- Caso de uso: panel de control del administrador de Ecommify.
-- Las MVs devuelven resultados pre-calculados en < 5ms.
--
-- Requiere: vistas materializadas (04_materialized_views.sql)

-- 5a. Ventas del año actual por categoría (tabla de top revenue)
SELECT
  category,
  SUM(total_orders)   AS pedidos_total,
  SUM(total_revenue)  AS ingresos_total,
  SUM(total_items)    AS items_vendidos,
  ROUND(AVG(avg_order_value), 2) AS ticket_promedio
FROM mv_sales_by_category_monthly
WHERE year = DATE_PART('year', NOW())::INT
GROUP BY category
ORDER BY ingresos_total DESC;

-- 5b. Tendencia mensual de ingresos (gráfico de líneas)
SELECT
  year,
  month,
  TO_CHAR(
    MAKE_DATE(year, month, 1), 'Mon YYYY'
  )                   AS periodo,
  SUM(total_revenue)  AS ingresos_mes,
  SUM(total_orders)   AS pedidos_mes,
  ROUND(
    SUM(total_revenue) - LAG(SUM(total_revenue))
      OVER (ORDER BY year, month), 2
  )                   AS variacion_vs_mes_anterior
FROM mv_sales_by_category_monthly
GROUP BY year, month
ORDER BY year, month;

-- 5c. Segmentación de clientes (KPI de CRM)
SELECT
  customer_segment,
  COUNT(*)                        AS clientes,
  ROUND(AVG(total_spent), 2)      AS gasto_promedio,
  ROUND(AVG(total_orders), 1)     AS pedidos_promedio,
  ROUND(AVG(days_since_last_order), 0) AS dias_desde_ultima_compra
FROM mv_customer_segments
GROUP BY customer_segment
ORDER BY
  CASE customer_segment
    WHEN 'VIP'        THEN 1
    WHEN 'Regular'    THEN 2
    WHEN 'Occasional' THEN 3
    ELSE                   4
  END;

-- 5d. Top 5 productos por ingresos en cada categoría
SELECT
  category,
  product_name,
  total_revenue,
  units_sold,
  rank_in_category
FROM mv_product_performance
WHERE rank_in_category <= 5
ORDER BY category, rank_in_category;

-- 5e. Resumen ejecutivo completo (un solo SELECT para el dashboard)
SELECT
  (SELECT COUNT(*) FROM mv_customer_segments)                AS total_clientes,
  (SELECT COUNT(*) FROM mv_customer_segments
   WHERE customer_segment = 'VIP')                          AS clientes_vip,
  (SELECT SUM(total_revenue) FROM mv_sales_by_category_monthly
   WHERE year = DATE_PART('year', NOW())::INT)               AS ingresos_año_actual,
  (SELECT SUM(total_orders) FROM mv_sales_by_category_monthly
   WHERE year = DATE_PART('year', NOW())::INT)               AS pedidos_año_actual,
  (SELECT COUNT(*) FROM promotions
   WHERE NOW() <@ promotion_period)                          AS promociones_activas,
  (SELECT COUNT(*) FROM products WHERE stock = 0)            AS productos_sin_stock,
  (SELECT COUNT(*) FROM stock_alerts WHERE resolved = FALSE)  AS alertas_stock_pendientes;
