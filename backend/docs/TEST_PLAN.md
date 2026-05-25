# Plan de Pruebas Unitarias — Ecommify

**Proyecto:** Ecommify — Plataforma e-commerce multivendedor de productos tecnológicos  
**Universidad:** Universidad de La Sabana  
**Asignatura:** Fundamentos de Testing, Verificación y Validación  
**Equipo:** David Ricardo Grandas Cárdenas · Danilo Andrés Cortés Saavedra · Edisson Steven Bustos Galeano  
**Docente:** César Augusto Vega Fernández  
**Fecha:** Mayo 2026

---

## 1. Objetivo

Documentar la estrategia de pruebas unitarias automatizadas implementadas para el módulo backend de Ecommify, evidenciando la aplicación de TDD, el patrón AAA (Arrange-Act-Assert) y el framework Given-When-Then.

Los tests verifican el comportamiento de la **capa de servicios** (lógica de negocio) de forma aislada, sin dependencias externas de base de datos ni servicios de terceros.

---

## 2. Stack de Testing

| Herramienta | Versión | Propósito |
|---|---|---|
| Jest | 29.7.0 | Framework principal — ejecución, aserciones, cobertura |
| jest.mock() | nativo | Mocks de conexiones a PostgreSQL y MongoDB |
| Node.js | 20.x | Entorno de ejecución |
| Docker | node:20-alpine | Entorno de ejecución en CI/CD |

---

## 3. Módulos Bajo Prueba

| Módulo | Archivo de Test | # Tests | HU Asociada | Stmts | Branch | Funcs | Lines |
|---|---|---|---|---|---|---|---|
| Autenticación | `auth/auth.service.test.js` | 14 | HU-01, HU-02 | 93.33% | 87.5% | 100% | 100% |
| Catálogo | `catalog/catalog.service.test.js` | 9 | HU-03, HU-04 | 100% | 90.9% | 100% | 100% |
| Carrito | `cart/cart.service.test.js` | 11 | HU-05 | 100% | 75% | 100% | 100% |
| Checkout | `checkout/checkout.service.test.js` | 10 | HU-06 | 100% | 88.88% | 100% | 100% |
| Reseñas | `reviews/reviews.service.test.js` | 12 | HU-07 | 100% | 100% | 100% | 100% |
| Inventario | `inventory/inventory.service.test.js` | 11 | HU-08 | 100% | 100% | 100% | 100% |
| **TOTAL** | **6 archivos** | **67** | **8 HUs** | **98.3%** | **89.28%** | **100%** | **100%** |

> Fuente: `tests/evidence/test-output.txt` — ejecución real con `npm run test:coverage`.

---

## 4. Patrones Aplicados

### 4.1. TDD (Test-Driven Development)

Cada módulo fue desarrollado siguiendo el ciclo Red-Green-Refactor:

1. **Red** — escribir el test que falla (función aún no implementada)
2. **Green** — implementar el mínimo código para que el test pase
3. **Refactor** — mejorar la implementación sin romper el test

Ejemplo del ciclo en `auth.service.js`:
```javascript
// 1. RED: test escrito primero
test('Given a valid email, When validateEmail is called, Then it returns true', () => {
  expect(validateEmail('usuario@example.com')).toBe(true); // falla: función no existe
});

// 2. GREEN: implementación mínima
function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// 3. REFACTOR: agregar casos borde sin romper el test
```

### 4.2. Patrón AAA (Arrange-Act-Assert)

Todos los tests estructuran su cuerpo en tres secciones claramente delimitadas:

```javascript
test('Given a subtotal of 100 and 10% discount, When calculateDiscount is called, Then it returns 90', () => {
  // Arrange — preparar el estado inicial
  const subtotal = 100;
  const discountPercent = 10;

  // Act — ejecutar la acción bajo prueba
  const result = calculateDiscount(subtotal, discountPercent);

  // Assert — verificar el resultado esperado
  expect(result).toBe(90);
});
```

### 4.3. Given-When-Then

Los nombres de los tests y la estructura de los `describe` siguen el formato BDD:

```javascript
describe('CartService', () => {           // sistema bajo prueba
  describe('HU-05: Gestión del carrito', () => { // contexto / historia de usuario
    test('Given an empty cart,            // estado inicial
         When calculateSubtotal is called,// acción
         Then it returns 0', () => { ... }); // resultado esperado
  });
});
```

---

## 5. Estrategia de Mocks

Los tests **no requieren Docker ni conexión a base de datos real**. Se mockean con `jest.mock()`:

- Conexión a PostgreSQL (`src/db/postgres.js`)
- Conexión a MongoDB (`src/db/mongo.js`)
- Módulos de bcrypt (en tests síncronos donde aplica)

Esto garantiza que los tests:
- Se ejecuten en < 30 segundos
- Sean deterministas (mismo resultado en cualquier entorno)
- No tengan dependencias de infraestructura

---

## 6. Alcance de Cobertura

La cobertura se mide **únicamente sobre la capa de servicios** (`src/modules/**/*.service.js`). Los controllers y routes se excluyen porque:

- Son wiring de Express, no lógica de negocio
- Se probarían con pruebas de integración (fuera del alcance de este módulo)
- Su inclusión distorsionaría las métricas al reportar 0% en archivos no testeados

Configuración en `jest.config.js`:
```javascript
collectCoverageFrom: [
  'src/**/*.js',
  '!src/app.js',
  '!src/db/**',
  '!src/**/*.controller.js',
  '!src/**/*.routes.js',
]
```

---

## 7. Cómo Ejecutar las Pruebas

```bash
cd backend

# Todos los tests (sin reporte de cobertura)
npm test

# Con reporte de cobertura (genera coverage/)
npm run test:coverage

# Modo CI/CD
npm run test:ci

# Un módulo específico
npm test -- tests/auth/auth.service.test.js
```

**Ver reporte HTML:**
```
Abrir: backend/coverage/index.html
```

---

## 8. Interpretación del Reporte de Cobertura

| Métrica | Descripción | Resultado | Umbral |
|---|---|---|---|
| **Statements** | % de sentencias ejecutadas | 98.30% | ≥ 75% ✓ |
| **Branches** | % de ramas condicionales cubiertas | 89.28% | ≥ 75% ✓ |
| **Functions** | % de funciones llamadas | 100.00% | ≥ 75% ✓ |
| **Lines** | % de líneas ejecutadas | 100.00% | ≥ 75% ✓ |

**Ramas no cubiertas identificadas:**
- `auth.service.js` líneas 17-28: branches de validación de formato de email con expresión regular (casos extremos no críticos)
- `cart.service.js` líneas 61-86: branches en manejo de carrito vacío con descuento 0%
- `catalog.service.js` línea 36: rama de filtro vacío en `applyAllFilters`
- `checkout.service.js` línea 67: rama de validación de dirección con campo vacío vs. undefined

---

## 9. Criterios de Calidad

| Criterio | Estado |
|---|---|
| Cobertura global > 75% en todas las métricas | ✅ Cumplido |
| Cero falsos positivos (tests que pasan sin verificar nada) | ✅ Cumplido |
| Un test = una responsabilidad | ✅ Cumplido |
| Tests reproducibles sin dependencias externas | ✅ Cumplido |
| Nombres descriptivos (legibles como documentación) | ✅ Cumplido |
| Cero tests fallidos | ✅ 67/67 PASS |

---

## 10. Evidencia

| Artefacto | Ubicación |
|---|---|
| Log de ejecución completo | `tests/evidence/test-output.txt` |
| Reporte HTML interactivo | `coverage/index.html` |
| Resumen JSON de cobertura | `coverage/coverage-summary.json` |
| Matriz de trazabilidad | `docs/TRACEABILITY_MATRIX.md` |
