-- ============================================================
-- Archivo   : 01_seed.sql
-- Descripción: Datos semilla para PostgreSQL — copia de referencia de
--              database/postgres/seed.sql. Ejecutar DESPUÉS de todos
--              los scripts 00_* al 06_*.
-- Autores   : David Ricardo Grandas Cárdenas
--             Danilo Andrés Cortés Saavedra
--             Edisson Steven Bustos Galeano
-- Fecha     : 2026-05-21
-- Contraseña para todos los usuarios de prueba: Test1234!
-- Hash generado con bcrypt rounds=10
-- ============================================================

INSERT INTO sellers (id, name, email, password_hash) VALUES
  ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
   'TechStore BR',
   'techstore@ecommify.com',
   '$2b$10$vgU8eYk6ZWnkHUL9fRhBGuGREscx21ap8mzb9QDkMupqBvtwSU9Eq'),
  ('b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22',
   'Gadget World',
   'gadget@ecommify.com',
   '$2b$10$vgU8eYk6ZWnkHUL9fRhBGuGREscx21ap8mzb9QDkMupqBvtwSU9Eq')
ON CONFLICT (id) DO NOTHING;

INSERT INTO customers (id, name, email, password_hash) VALUES
  ('c2aafe11-be2d-6a1a-dd8f-8dd1cf502c33',
   'Ana García',
   'ana@example.com',
   '$2b$10$vgU8eYk6ZWnkHUL9fRhBGuGREscx21ap8mzb9QDkMupqBvtwSU9Eq'),
  ('d3bbff22-cf3e-7b2b-ee90-9ee2d0613d44',
   'Carlos López',
   'carlos@example.com',
   '$2b$10$vgU8eYk6ZWnkHUL9fRhBGuGREscx21ap8mzb9QDkMupqBvtwSU9Eq')
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (id, name, seller_id, stock, price, category) VALUES
  ('prod-001', 'Smartphone Samsung Galaxy A54',   'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 25, 1299.90, 'smartphones'),
  ('prod-002', 'Laptop Dell Inspiron 15',          'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',  8, 3499.90, 'laptops'),
  ('prod-003', 'Tablet Apple iPad 10',             'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 12, 2199.90, 'tablets'),
  ('prod-004', 'Fone Bluetooth Sony WH-1000XM5',  'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22', 50,  899.90, 'audio'),
  ('prod-005', 'Smartwatch Apple Watch SE',        'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22', 15, 1599.90, 'wearables'),
  ('prod-006', 'Mouse Logitech MX Master 3',       'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22', 30,  349.90, 'peripherals'),
  ('prod-007', 'Teclado Mecánico Keychron K2',     'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',  0,  499.90, 'peripherals'),
  ('prod-008', 'Monitor LG 27" 4K UltraFine',      'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',  5, 1899.90, 'monitors')
ON CONFLICT (id) DO NOTHING;

-- Actualizar specifications y tags de productos (columnas agregadas en 02_advanced_types.sql)
UPDATE products SET
  specifications = '{"storage":"256GB","ram":"8GB","camera":"50MP","battery":"5000mAh","display":"6.4 Super AMOLED"}',
  tags           = ARRAY['smartphone','samsung','android','5g','camara'],
  photos         = ARRAY['https://picsum.photos/seed/galaxy-a54/400/300']
WHERE id = 'prod-001';

UPDATE products SET
  specifications = '{"processor":"Intel Core i5-1235U","ram":"16GB","storage":"512GB SSD","display":"15.6 FHD","os":"Windows 11"}',
  tags           = ARRAY['laptop','dell','windows','i5','ssd'],
  photos         = ARRAY['https://picsum.photos/seed/dell-inspiron/400/300']
WHERE id = 'prod-002';

UPDATE products SET
  specifications = '{"chip":"A14 Bionic","storage":"64GB","display":"10.9 Liquid Retina","connectivity":"Wi-Fi 6"}',
  tags           = ARRAY['tablet','apple','ipad','ios'],
  photos         = ARRAY['https://picsum.photos/seed/ipad-10/400/300']
WHERE id = 'prod-003';

UPDATE products SET
  specifications = '{"type":"Over-ear","battery":"30h","anc":"Yes","connectivity":"Bluetooth 5.2"}',
  tags           = ARRAY['audio','sony','bluetooth','anc','headphones'],
  photos         = ARRAY['https://picsum.photos/seed/sony-xm5/400/300']
WHERE id = 'prod-004';

UPDATE products SET
  specifications = '{"chip":"S8","display":"Retina LTPO","gps":"Yes","waterResistance":"50m"}',
  tags           = ARRAY['smartwatch','apple','wearable','salud','gps'],
  photos         = ARRAY['https://picsum.photos/seed/watch-se/400/300']
WHERE id = 'prod-005';

UPDATE products SET
  specifications = '{"dpi":"200-8000","battery":"70 days","connectivity":"Bluetooth + USB","buttons":7}',
  tags           = ARRAY['mouse','logitech','inalambrico','ergonomico','productividad'],
  photos         = ARRAY['https://picsum.photos/seed/mx-master/400/300']
WHERE id = 'prod-006';

UPDATE products SET
  specifications = '{"layout":"75%","switches":"Cherry MX Red","backlight":"RGB","os":"Mac/Windows"}',
  tags           = ARRAY['teclado','mecanico','keychron','rgb','gaming'],
  photos         = ARRAY['https://picsum.photos/seed/keychron-k2/400/300']
WHERE id = 'prod-007';

UPDATE products SET
  specifications = '{"resolution":"3840x2160","panel":"IPS","hdr":"HDR400","usbC":"90W","size":"27"}',
  tags           = ARRAY['monitor','lg','4k','ips','uhd','diseno'],
  photos         = ARRAY['https://picsum.photos/seed/lg-4k/400/300']
WHERE id = 'prod-008';

-- Notificaciones y horarios de vendedores
UPDATE sellers SET
  notification_emails = ARRAY['techstore@ecommify.com', 'ops@techstore.com'],
  business_hours      = '{"monday":"9:00-18:00","tuesday":"9:00-18:00","wednesday":"9:00-18:00","thursday":"9:00-18:00","friday":"9:00-17:00","saturday":"10:00-14:00"}'
WHERE id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

UPDATE sellers SET
  notification_emails = ARRAY['gadget@ecommify.com'],
  business_hours      = '{"monday":"8:00-20:00","tuesday":"8:00-20:00","wednesday":"8:00-20:00","thursday":"8:00-20:00","friday":"8:00-19:00","saturday":"9:00-15:00","sunday":"10:00-14:00"}'
WHERE id = 'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22';

-- Promoción de muestra (requiere tabla promotions de 02_advanced_types.sql)
INSERT INTO promotions (product_id, discount_percent, promotion_period, description) VALUES
  ('prod-001', 10.00,
   '[2026-05-01 00:00:00+00, 2026-05-31 23:59:59+00]',
   'Promoción Día de las Madres — 10% off Galaxy A54'),
  ('prod-004', 15.00,
   '[2026-06-01 00:00:00+00, 2026-06-30 23:59:59+00]',
   'Promo Mitad de Año — 15% off Sony WH-1000XM5')
ON CONFLICT DO NOTHING;
