// ============================================================
// Archivo   : seed.js
// Descripción: Datos semilla MongoDB — copia de referencia de
//              database/mongo/seed.js. Para nuevas colecciones
//              (user_behavior, analytics_snapshots) ver
//              collections_schema.json en este mismo directorio.
// Autores   : David Ricardo Grandas Cárdenas
//             Danilo Andrés Cortés Saavedra
//             Edisson Steven Bustos Galeano
// Fecha     : 2026-05-21
// ============================================================

db = db.getSiblingDB('ecommify');

// ── Productos ────────────────────────────────────────────────
db.products.drop();
db.products.createIndex({ id: 1 }, { unique: true });
db.products.createIndex({ category: 1 });
db.products.createIndex({ price: 1 });
db.products.createIndex({ rating: -1 });
// Índice texto para búsqueda full-text (complementa pg_trgm en PG)
db.products.createIndex({ name: 'text', description: 'text', 'specs.*': 'text' });
// Índice compuesto para filtros frecuentes del catálogo
db.products.createIndex({ category: 1, price: 1, rating: -1 });

db.products.insertMany([
  {
    id: 'prod-001',
    name: 'Smartphone Samsung Galaxy A54',
    price: 1299.90,
    category: 'smartphones',
    rating: 4.5,
    stock: 25,
    sellerId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description: 'Smartphone Samsung Galaxy A54 com 256GB, câmera tripla de 50MP, tela Super AMOLED de 6.4" e bateria de 5000mAh.',
    images: ['https://picsum.photos/seed/galaxy-a54/400/300'],
    specs: { storage: '256GB', ram: '8GB', camera: '50MP', battery: '5000mAh' },
    tags: ['smartphone', 'samsung', 'android', '5g', 'camara']
  },
  {
    id: 'prod-002',
    name: 'Laptop Dell Inspiron 15',
    price: 3499.90,
    category: 'laptops',
    rating: 4.3,
    stock: 8,
    sellerId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description: 'Laptop Dell Inspiron 15 con Intel Core i5 de 12ª generación, 16GB RAM, SSD 512GB y pantalla Full HD de 15.6".',
    images: ['https://picsum.photos/seed/dell-inspiron/400/300'],
    specs: { processor: 'Intel Core i5-1235U', ram: '16GB', storage: '512GB SSD', display: '15.6" FHD' },
    tags: ['laptop', 'dell', 'windows', 'i5', 'ssd']
  },
  {
    id: 'prod-003',
    name: 'Tablet Apple iPad 10',
    price: 2199.90,
    category: 'tablets',
    rating: 4.7,
    stock: 12,
    sellerId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description: 'Apple iPad 10ª generación con chip A14 Bionic, pantalla Liquid Retina de 10.9", Wi-Fi 6 y USB-C.',
    images: ['https://picsum.photos/seed/ipad-10/400/300'],
    specs: { chip: 'A14 Bionic', storage: '64GB', display: '10.9" Liquid Retina', connectivity: 'Wi-Fi 6' },
    tags: ['tablet', 'apple', 'ipad', 'ios']
  },
  {
    id: 'prod-004',
    name: 'Fone Bluetooth Sony WH-1000XM5',
    price: 899.90,
    category: 'audio',
    rating: 4.8,
    stock: 50,
    sellerId: 'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22',
    description: 'Audífonos inalámbricos Sony WH-1000XM5 con cancelación de ruido líder de la industria, 30h de batería y micrófono de alta calidad.',
    images: ['https://picsum.photos/seed/sony-xm5/400/300'],
    specs: { type: 'Over-ear', battery: '30h', anc: 'Yes', connectivity: 'Bluetooth 5.2' },
    tags: ['audio', 'sony', 'bluetooth', 'anc', 'headphones']
  },
  {
    id: 'prod-005',
    name: 'Smartwatch Apple Watch SE',
    price: 1599.90,
    category: 'wearables',
    rating: 4.6,
    stock: 15,
    sellerId: 'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22',
    description: 'Apple Watch SE con chip S8, pantalla Retina siempre activa, GPS, monitoreo de salud y resistencia al agua.',
    images: ['https://picsum.photos/seed/watch-se/400/300'],
    specs: { chip: 'S8', display: 'Retina LTPO', gps: 'Yes', waterResistance: '50m' },
    tags: ['smartwatch', 'apple', 'wearable', 'salud', 'gps']
  },
  {
    id: 'prod-006',
    name: 'Mouse Logitech MX Master 3',
    price: 349.90,
    category: 'peripherals',
    rating: 4.9,
    stock: 30,
    sellerId: 'b1ffcd00-ad1c-5f09-cc7e-7cc0ce491b22',
    description: 'Mouse inalámbrico Logitech MX Master 3 con scroll magnético, 7 botones programables, recarga USB-C y 70 días de batería.',
    images: ['https://picsum.photos/seed/mx-master/400/300'],
    specs: { dpi: '200-8000', battery: '70 days', connectivity: 'Bluetooth + USB', buttons: 7 },
    tags: ['mouse', 'logitech', 'inalambrico', 'ergonomico', 'productividad']
  },
  {
    id: 'prod-007',
    name: 'Teclado Mecánico Keychron K2',
    price: 499.90,
    category: 'peripherals',
    rating: 4.4,
    stock: 0,
    sellerId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description: 'Teclado mecánico compacto 75% Keychron K2 con switches Cherry MX, retroiluminación RGB y compatible con Mac/Windows.',
    images: ['https://picsum.photos/seed/keychron-k2/400/300'],
    specs: { layout: '75%', switches: 'Cherry MX Red', backlight: 'RGB', os: 'Mac/Windows' },
    tags: ['teclado', 'mecanico', 'keychron', 'rgb', 'gaming']
  },
  {
    id: 'prod-008',
    name: 'Monitor LG 27" 4K UltraFine',
    price: 1899.90,
    category: 'monitors',
    rating: 4.6,
    stock: 5,
    sellerId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    description: 'Monitor LG UltraFine 27" 4K IPS con USB-C 90W, HDR400, 99% sRGB y altavoces integrados. Ideal para profesionales.',
    images: ['https://picsum.photos/seed/lg-4k/400/300'],
    specs: { resolution: '3840x2160', panel: 'IPS', hdr: 'HDR400', usbC: '90W' },
    tags: ['monitor', 'lg', '4k', 'ips', 'uhd', 'diseno']
  }
]);

// ── Reseñas ──────────────────────────────────────────────────
db.reviews.drop();
db.reviews.createIndex({ productId: 1 });
db.reviews.createIndex({ userId: 1, productId: 1 }, { unique: true });
db.reviews.createIndex({ score: -1 });
db.reviews.createIndex({ createdAt: -1 });

db.reviews.insertMany([
  {
    userId: 'c2aafe11-be2d-6a1a-dd8f-8dd1cf502c33',
    productId: 'prod-001',
    score: 5,
    comment: 'Excelente smartphone, cámara increíble y batería dura todo el día.',
    verified: true,
    helpfulVotes: 12,
    createdAt: new Date('2025-01-10').toISOString()
  },
  {
    userId: 'd3bbff22-cf3e-7b2b-ee90-9ee2d0613d44',
    productId: 'prod-001',
    score: 4,
    comment: 'Muy buen equipo, solo le falta carga rápida más potente.',
    verified: true,
    helpfulVotes: 5,
    createdAt: new Date('2025-01-15').toISOString()
  },
  {
    userId: 'c2aafe11-be2d-6a1a-dd8f-8dd1cf502c33',
    productId: 'prod-004',
    score: 5,
    comment: 'La cancelación de ruido es espectacular. Vale cada centavo.',
    verified: true,
    helpfulVotes: 23,
    createdAt: new Date('2025-02-01').toISOString()
  },
  {
    userId: 'd3bbff22-cf3e-7b2b-ee90-9ee2d0613d44',
    productId: 'prod-006',
    score: 5,
    comment: 'El mejor mouse que he tenido. El scroll magnético es una maravilla.',
    verified: true,
    helpfulVotes: 18,
    createdAt: new Date('2025-02-20').toISOString()
  }
]);

// ── Comportamiento de usuario (nueva colección) ───────────────
db.user_behavior.drop();
// TTL de 30 días: MongoDB elimina documentos automáticamente
db.user_behavior.createIndex({ created_at: 1 }, { expireAfterSeconds: 2592000 });
db.user_behavior.createIndex({ user_id: 1, event_type: 1 });
db.user_behavior.createIndex({ product_id: 1 });
db.user_behavior.createIndex({ session_id: 1 });

db.user_behavior.insertMany([
  {
    session_id:  'sess-abc123',
    user_id:     'c2aafe11-be2d-6a1a-dd8f-8dd1cf502c33',
    event_type:  'product_view',
    product_id:  'prod-001',
    metadata:    { source: 'catalog', position: 1, search_query: null },
    device:      { type: 'desktop', browser: 'Chrome', os: 'Windows' },
    created_at:  new Date()
  },
  {
    session_id:  'sess-abc123',
    user_id:     'c2aafe11-be2d-6a1a-dd8f-8dd1cf502c33',
    event_type:  'add_to_cart',
    product_id:  'prod-001',
    metadata:    { quantity: 1, price_at_action: 1299.90 },
    device:      { type: 'desktop', browser: 'Chrome', os: 'Windows' },
    created_at:  new Date()
  },
  {
    session_id:  'sess-def456',
    user_id:     'd3bbff22-cf3e-7b2b-ee90-9ee2d0613d44',
    event_type:  'search',
    product_id:  null,
    metadata:    { query: 'mouse inalambrico', results_count: 3, clicked_position: 1 },
    device:      { type: 'mobile', browser: 'Safari', os: 'iOS' },
    created_at:  new Date()
  }
]);

// ── Snapshots analíticos (nueva colección) ────────────────────
db.analytics_snapshots.drop();
db.analytics_snapshots.createIndex({ snapshot_date: -1 });
db.analytics_snapshots.createIndex({ snapshot_type: 1, snapshot_date: -1 });
db.analytics_snapshots.createIndex(
  { snapshot_date: 1 },
  { expireAfterSeconds: 7776000 }  // TTL 90 días para snapshots diarios
);

db.analytics_snapshots.insertOne({
  snapshot_type: 'daily_sales',
  snapshot_date: new Date('2025-02-20'),
  data: {
    total_orders:   2,
    total_revenue:  2199.80,
    avg_order_value: 1099.90,
    top_categories: [
      { category: 'smartphones', orders: 1, revenue: 1299.90 },
      { category: 'peripherals', orders: 1, revenue:  899.90 }
    ],
    new_customers: 0,
    conversion_rate: 0.45
  },
  generated_at: new Date()
});

print('✅ Ecommify seed data loaded:');
print('   products:           ' + db.products.countDocuments());
print('   reviews:            ' + db.reviews.countDocuments());
print('   user_behavior:      ' + db.user_behavior.countDocuments());
print('   analytics_snapshots:' + db.analytics_snapshots.countDocuments());
