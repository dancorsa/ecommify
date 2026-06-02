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

// Mock de pool con soporte para client.connect()
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

const validBody = {
  cart: [{ id: 'p1', name: 'Laptop', price: 1000, qty: 1 }],
  address: { street: '123 Main St', city: 'Bogotá', state: 'DC', zipCode: '110111', country: 'CO' },
  payment: 'credit_card',
  inventory: { p1: 10 },
  userId: 'u1',
};

describe('CheckoutController — Pruebas HTTP con mocks', () => {

  let app;

  beforeAll(() => { app = createApp(); });
  beforeEach(() => {
    jest.clearAllMocks();
    pool.connect.mockResolvedValue(mockClient);
    mockClient.query.mockResolvedValue({ rows: [] });
  });

  test('Given valid order, When POST /checkout/orders, Then returns 201 with summary', async () => {
    mockClient.query.mockResolvedValue({ rows: [] });
    const res = await request(app).post('/api/checkout/orders').send(validBody);
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('orderId');
    expect(res.body).toHaveProperty('total');
  });

  test('Given invalid address (missing city), When POST /checkout/orders, Then returns 400', async () => {
    const body = { ...validBody, address: { street: '123', state: 'DC', zip: '111', country: 'CO' } };
    const res = await request(app).post('/api/checkout/orders').send(body);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/address/i);
  });

  test('Given invalid payment method, When POST /checkout/orders, Then returns 400', async () => {
    const body = { ...validBody, payment: 'bitcoin' };
    const res = await request(app).post('/api/checkout/orders').send(body);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/payment/i);
  });

  test('Given insufficient stock, When POST /checkout/orders, Then returns 409', async () => {
    const body = {
      ...validBody,
      cart: [{ id: 'p1', name: 'Laptop', price: 1000, qty: 20 }],
      inventory: { p1: 5 },
    };
    const res = await request(app).post('/api/checkout/orders').send(body);
    expect(res.status).toBe(409);
  });

  test('Given DB failure, When POST /checkout/orders, Then returns 500', async () => {
    mockClient.query.mockRejectedValueOnce(new Error('DB down'));
    const res = await request(app).post('/api/checkout/orders').send(validBody);
    expect(res.status).toBe(500);
  });
});
