'use strict';

/**
 * Pruebas de integración para AuthController usando Jest mocks.
 *
 * Se simulan (mockean) las dependencias externas:
 *  - pool.query  → simula PostgreSQL sin conexión real
 *
 * Se prueba el comportamiento HTTP del controlador a través de supertest.
 * Equivalente a @SpringBootTest + @MockBean en el mundo Java/Mockito.
 */

const request = require('supertest');
const { createApp } = require('../../src/app');

// ── Mock de PostgreSQL ────────────────────────────────────────────────────────
// jest.mock reemplaza el módulo antes de que el controlador lo importe.
// Equivale a mock(RegistryRepositoryPort.class) en Mockito.
jest.mock('../../src/db/postgres', () => ({
  pool: {
    query: jest.fn(),
  },
}));

// Mock de MongoDB (no se usa en auth, pero evita errores de conexión en app.js)
jest.mock('../../src/db/mongo', () => ({
  connectMongo: jest.fn().mockResolvedValue(true),
}));

const { pool } = require('../../src/db/postgres');

describe('AuthController — Pruebas de integración HTTP con mocks', () => {

  let app;

  beforeAll(() => {
    app = createApp();
  });

  beforeEach(() => {
    // Limpia historial de llamadas entre pruebas
    // Equivale a @Before + reset del mock en JUnit/Mockito
    jest.clearAllMocks();
  });

  // ── POST /api/auth/register ─────────────────────────────────────────────────

  describe('POST /api/auth/register', () => {

    test('Given valid credentials, When POST /register, Then returns 201 with token', async () => {
      // Arrange — simular que INSERT retorna el usuario creado
      // Equivale a: when(repo.save(...)).thenReturn(user)
      pool.query.mockResolvedValueOnce({
        rows: [{ id: 1, email: 'ana@example.com', name: 'Ana' }],
      });

      // Act
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'ana@example.com', password: 'SecurePass1', name: 'Ana' });

      // Assert
      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('token');
      expect(res.body.user.email).toBe('ana@example.com');
      // Verify — pool.query fue llamado exactamente una vez
      expect(pool.query).toHaveBeenCalledTimes(1);
    });

    test('Given invalid email, When POST /register, Then returns 400', async () => {
      // Arrange — email sin @, no llega a consultar la BD
      // Equivale a: verifyNoInteractions(repo)

      // Act
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'invalido', password: 'SecurePass1', name: 'Ana' });

      // Assert
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/email/i);
      // Verify — no se llamó a la BD
      expect(pool.query).not.toHaveBeenCalled();
    });

    test('Given weak password, When POST /register, Then returns 400', async () => {
      // Arrange — contraseña sin mayúscula

      // Act
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'ana@example.com', password: 'weak', name: 'Ana' });

      // Assert
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/password/i);
      expect(pool.query).not.toHaveBeenCalled();
    });

    test('Given duplicate email, When POST /register, Then returns 409', async () => {
      // Arrange — simular error de clave duplicada de PostgreSQL
      // Equivale a: when(repo.save(...)).thenThrow(new SQLException("23505"))
      const dbError = new Error('duplicate key');
      dbError.code = '23505';
      pool.query.mockRejectedValueOnce(dbError);

      // Act
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'ana@example.com', password: 'SecurePass1', name: 'Ana' });

      // Assert
      expect(res.status).toBe(409);
      expect(res.body.error).toMatch(/already registered/i);
    });

    test('Given DB failure, When POST /register, Then returns 500', async () => {
      // Arrange — simular fallo inesperado de BD
      pool.query.mockRejectedValueOnce(new Error('Connection lost'));

      // Act
      const res = await request(app)
        .post('/api/auth/register')
        .send({ email: 'ana@example.com', password: 'SecurePass1', name: 'Ana' });

      // Assert
      expect(res.status).toBe(500);
    });
  });

  // ── POST /api/auth/login ────────────────────────────────────────────────────

  describe('POST /api/auth/login', () => {

    test('Given valid credentials, When POST /login, Then returns 200 with token', async () => {
      // Arrange — simular usuario encontrado en BD con contraseña correcta
      const bcrypt = require('bcryptjs');
      const hash = await bcrypt.hash('SecurePass1', 10);

      pool.query
        .mockResolvedValueOnce({
          rows: [{ id: 1, email: 'ana@example.com', name: 'Ana', password_hash: hash, login_attempts: 0 }],
        })
        .mockResolvedValueOnce({ rows: [] }); // UPDATE login_attempts = 0

      // Act
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'ana@example.com', password: 'SecurePass1' });

      // Assert
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
    });

    test('Given non-existent user, When POST /login, Then returns 401', async () => {
      // Arrange — BD no encuentra el usuario
      pool.query.mockResolvedValueOnce({ rows: [] });

      // Act
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'noexiste@example.com', password: 'SecurePass1' });

      // Assert
      expect(res.status).toBe(401);
      expect(res.body.error).toMatch(/credentials/i);
    });

    test('Given blocked account (3 attempts), When POST /login, Then returns 429', async () => {
      // Arrange — usuario con 3 intentos fallidos previos
      pool.query.mockResolvedValueOnce({
        rows: [{ id: 2, email: 'bloqueado@example.com', name: 'Test', password_hash: 'x', login_attempts: 3 }],
      });

      // Act
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'bloqueado@example.com', password: 'SecurePass1' });

      // Assert
      expect(res.status).toBe(429);
      expect(res.body.error).toMatch(/blocked/i);
    });
  });

  // ── GET /health ─────────────────────────────────────────────────────────────

  describe('GET /health', () => {
    test('When GET /health, Then returns 200 with status ok', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
    });
  });
});
