'use strict';

const request = require('supertest');
const { createApp } = require('../../src/app');

jest.mock('../../src/db/postgres', () => ({ pool: { query: jest.fn() } }));
jest.mock('../../src/db/mongo', () => ({ connectMongo: jest.fn() }));

jest.mock('mongoose', () => {
  const mockModel = { find: jest.fn(), create: jest.fn() };
  const mSchema = jest.fn().mockReturnValue({});
  mSchema.Types = { ObjectId: String };
  return {
    Schema: mSchema,
    model: jest.fn().mockReturnValue(mockModel),
    models: {},
    connect: jest.fn(),
  };
});

// Obtener referencia al modelo mockeado (patrón correcto con Jest)
const mongoose = require('mongoose');
const ReviewModel = mongoose.model();

describe('ReviewsController — Pruebas HTTP con mocks', () => {

  let app;

  beforeAll(() => { app = createApp(); });
  beforeEach(() => { jest.clearAllMocks(); });

  describe('POST /api/reviews', () => {

    test('Given valid review, When POST /reviews, Then returns 201', async () => {
      ReviewModel.find.mockReturnValueOnce({ lean: jest.fn().mockResolvedValueOnce([]) });
      ReviewModel.create.mockResolvedValueOnce({ _id: 'r1', score: 4 });

      const res = await request(app).post('/api/reviews').send({
        userId: 'u1', productId: 'p1', score: 4, comment: 'Great!',
        purchaseHistory: [{ userId: 'u1', productId: 'p1', status: 'delivered' }],
      });
      expect(res.status).toBe(201);
    });

    test('Given invalid score, When POST /reviews, Then returns 400', async () => {
      const res = await request(app).post('/api/reviews').send({
        userId: 'u1', productId: 'p1', score: 6, comment: 'Bad',
        purchaseHistory: [{ userId: 'u1', productId: 'p1', status: 'delivered' }],
      });
      expect(res.status).toBe(400);
    });

    test('Given user without purchase, When POST /reviews, Then returns 403', async () => {
      const res = await request(app).post('/api/reviews').send({
        userId: 'u1', productId: 'p1', score: 4, comment: 'ok',
        purchaseHistory: [],
      });
      expect(res.status).toBe(403);
    });

    test('Given duplicate review, When POST /reviews, Then returns 409', async () => {
      ReviewModel.find.mockReturnValueOnce({
        lean: jest.fn().mockResolvedValueOnce([{ userId: 'u1', productId: 'p1' }]),
      });

      const res = await request(app).post('/api/reviews').send({
        userId: 'u1', productId: 'p1', score: 4, comment: 'Repeat',
        purchaseHistory: [{ userId: 'u1', productId: 'p1', status: 'delivered' }],
      });
      expect(res.status).toBe(409);
    });
  });

  describe('GET /api/reviews/product/:productId', () => {

    test('Given existing reviews, When GET /reviews/product/:id, Then returns reviews with average', async () => {
      ReviewModel.find.mockReturnValueOnce({
        lean: jest.fn().mockResolvedValueOnce([{ score: 4 }, { score: 5 }]),
      });

      const res = await request(app).get('/api/reviews/product/p1');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('average');
    });

    test('Given DB error, When GET /reviews/product/:id, Then returns 500', async () => {
      ReviewModel.find.mockReturnValueOnce({
        lean: jest.fn().mockRejectedValueOnce(new Error('DB error')),
      });

      const res = await request(app).get('/api/reviews/product/p1');
      expect(res.status).toBe(500);
    });
  });
});
