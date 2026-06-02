'use strict';

const request = require('supertest');
const { createApp } = require('../../src/app');

jest.mock('../../src/db/mongo', () => ({ connectMongo: jest.fn() }));
jest.mock('mongoose', () => {
  const m = { find: jest.fn(), findById: jest.fn(), create: jest.fn() };
  const s = jest.fn().mockReturnValue({});
  s.Types = { ObjectId: String };
  return { Schema: s, model: jest.fn().mockReturnValue(m), models: {}, connect: jest.fn() };
});

const mockClient = {
  query: jest.fn(),
  release: jest.fn(),
};
jest.mock('../../src/db/postgres', () => ({
  pool: {
    query: jest.fn(),
    connect: jest.fn(),
  },
}));

const { pool } = require('../../src/db/postgres');

describe('InventoryController — Pruebas HTTP con mocks', () => {

  let app;

  beforeAll(() => { app = createApp(); });
  beforeEach(() => {
    jest.clearAllMocks();
    pool.connect.mockResolvedValue(mockClient);
    mockClient.query.mockResolvedValue({ rows: [] });
  });

  describe('PATCH /api/inventory/:productId', () => {

    test('Given valid update, When PATCH /inventory/:id, Then returns 200 with update info', async () => {
      // Arrange — producto encontrado, mismo seller
      mockClient.query
        .mockResolvedValueOnce({ rows: [] })                                    // BEGIN
        .mockResolvedValueOnce({ rows: [{ stock: 10, seller_id: 'seller1' }] }) // SELECT
        .mockResolvedValueOnce({ rows: [] })                                    // UPDATE
        .mockResolvedValueOnce({ rows: [] })                                    // INSERT history
        .mockResolvedValueOnce({ rows: [] });                                   // COMMIT

      const res = await request(app)
        .patch('/api/inventory/prod1')
        .send({ newStock: 25, sellerId: 'seller1' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('history');
    });

    test('Given negative stock, When PATCH /inventory/:id, Then returns 400', async () => {
      const res = await request(app)
        .patch('/api/inventory/prod1')
        .send({ newStock: -5, sellerId: 'seller1' });
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/stock/i);
    });

    test('Given product not found, When PATCH /inventory/:id, Then returns 404', async () => {
      mockClient.query
        .mockResolvedValueOnce({ rows: [] })  // BEGIN
        .mockResolvedValueOnce({ rows: [] }); // SELECT — vacío

      const res = await request(app)
        .patch('/api/inventory/noexiste')
        .send({ newStock: 10, sellerId: 'seller1' });
      expect(res.status).toBe(404);
    });

    test('Given wrong seller, When PATCH /inventory/:id, Then returns 403', async () => {
      mockClient.query
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [{ stock: 5, seller_id: 'otroSeller' }] })
        .mockResolvedValueOnce({ rows: [] }); // ROLLBACK

      const res = await request(app)
        .patch('/api/inventory/prod1')
        .send({ newStock: 10, sellerId: 'seller1' });
      expect(res.status).toBe(403);
    });
  });

  describe('GET /api/inventory/seller/:sellerId', () => {

    test('Given seller with products, When GET /inventory/seller/:id, Then returns product list', async () => {
      pool.query.mockResolvedValueOnce({
        rows: [{ id: 'p1', name: 'Laptop', stock: 10 }],
      });

      const res = await request(app).get('/api/inventory/seller/seller1');
      expect(res.status).toBe(200);
      expect(res.body[0]).toHaveProperty('isOutOfStock');
    });

    test('Given DB error, When GET /inventory/seller/:id, Then returns 500', async () => {
      pool.query.mockRejectedValueOnce(new Error('DB error'));

      const res = await request(app).get('/api/inventory/seller/seller1');
      expect(res.status).toBe(500);
    });
  });
});
