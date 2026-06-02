'use strict';

/**
 * Pruebas de integración HTTP para CartController.
 * El carrito usa sesiones en memoria (Map), por lo que no necesita
 * mocks de BD — se prueba directamente el comportamiento HTTP.
 */

const request = require('supertest');
const { createApp } = require('../../src/app');

jest.mock('../../src/db/postgres', () => ({ pool: { query: jest.fn() } }));
jest.mock('../../src/db/mongo', () => ({ connectMongo: jest.fn() }));
jest.mock('mongoose', () => {
  const mModel = { find: jest.fn(), findById: jest.fn(), create: jest.fn() };
  const mSchema = jest.fn().mockReturnValue({});
  mSchema.Types = { ObjectId: String };
  return { Schema: mSchema, model: jest.fn().mockReturnValue(mModel), models: {}, connect: jest.fn() };
});

describe('CartController — Pruebas HTTP', () => {

  let app;

  beforeAll(() => { app = createApp(); });

  test('Given empty cart, When GET /cart/:userId, Then returns empty array and subtotal 0', async () => {
    const res = await request(app).get('/api/cart/user-new');
    expect(res.status).toBe(200);
    expect(res.body.cart).toEqual([]);
    expect(res.body.subtotal).toBe(0);
  });

  test('Given valid item, When POST /cart/:userId/items, Then item is added', async () => {
    const res = await request(app)
      .post('/api/cart/user1/items')
      .send({ product: { id: 'p1', name: 'Laptop', price: 1000 }, qty: 1, availableStock: 5 });
    expect(res.status).toBe(200);
    expect(res.body.cart.length).toBe(1);
    expect(res.body.subtotal).toBe(1000);
  });

  test('Given qty exceeds stock, When POST /cart/:userId/items, Then returns 400', async () => {
    const res = await request(app)
      .post('/api/cart/user2/items')
      .send({ product: { id: 'p1', name: 'Phone', price: 500 }, qty: 10, availableStock: 3 });
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  test('Given item in cart, When DELETE /cart/:userId/items/:productId, Then item is removed', async () => {
    // Arrange — agregar ítem primero
    await request(app)
      .post('/api/cart/user3/items')
      .send({ product: { id: 'p2', name: 'Tablet', price: 300 }, qty: 1, availableStock: 10 });

    // Act
    const res = await request(app).delete('/api/cart/user3/items/p2');

    // Assert
    expect(res.status).toBe(200);
    expect(res.body.cart).toEqual([]);
  });

  test('Given item in cart, When PATCH /cart/:userId/items/:productId, Then quantity is updated', async () => {
    // Arrange
    await request(app)
      .post('/api/cart/user4/items')
      .send({ product: { id: 'p3', name: 'Monitor', price: 200 }, qty: 1, availableStock: 10 });

    // Act
    const res = await request(app)
      .patch('/api/cart/user4/items/p3')
      .send({ qty: 3, availableStock: 10 });

    // Assert
    expect(res.status).toBe(200);
    expect(res.body.subtotal).toBe(600);
  });
});
