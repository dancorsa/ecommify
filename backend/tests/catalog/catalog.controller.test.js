'use strict';

const request = require('supertest');
const { createApp } = require('../../src/app');

jest.mock('../../src/db/mongo', () => ({ connectMongo: jest.fn() }));
jest.mock('../../src/db/postgres', () => ({ pool: { query: jest.fn() } }));

jest.mock('mongoose', () => {
  const mockModel = { find: jest.fn(), findOne: jest.fn() };
  const mSchema = jest.fn().mockReturnValue({});
  mSchema.Types = { ObjectId: String };
  return {
    Schema: mSchema,
    model: jest.fn().mockReturnValue(mockModel),
    models: {},
    connect: jest.fn(),
  };
});

const mongoose = require('mongoose');
const ProductModel = mongoose.model();

describe('CatalogController — Pruebas HTTP con mocks MongoDB', () => {

  let app;

  beforeAll(() => { app = createApp(); });
  beforeEach(() => { jest.clearAllMocks(); });

  describe('GET /api/catalog', () => {

    test('Given products exist, When GET /catalog, Then returns 200 with array', async () => {
      const mockProducts = [
        { id: '1', name: 'Laptop', price: 1000, category: 'electronics', stock: 5, rating: 4.5, images: [] },
      ];
      ProductModel.find.mockReturnValueOnce({ lean: jest.fn().mockResolvedValueOnce(mockProducts) });

      const res = await request(app).get('/api/catalog');
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });

    test('Given DB failure, When GET /catalog, Then returns 500', async () => {
      ProductModel.find.mockReturnValueOnce({
        lean: jest.fn().mockRejectedValueOnce(new Error('MongoDB down')),
      });

      const res = await request(app).get('/api/catalog');
      expect(res.status).toBe(500);
    });
  });

  describe('GET /api/catalog/:id', () => {

    test('Given valid product, When GET /catalog/:id, Then returns 200', async () => {
      const mockProduct = { id: 'p1', name: 'Laptop', price: 1000, stock: 5, rating: 4.5, images: [], description: 'desc' };
      ProductModel.findOne.mockReturnValueOnce({ lean: jest.fn().mockResolvedValueOnce(mockProduct) });

      const res = await request(app).get('/api/catalog/p1');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('available');
    });

    test('Given non-existent product, When GET /catalog/:id, Then returns 404', async () => {
      ProductModel.findOne.mockReturnValueOnce({ lean: jest.fn().mockResolvedValueOnce(null) });

      const res = await request(app).get('/api/catalog/noexiste');
      expect(res.status).toBe(404);
    });
  });
});
