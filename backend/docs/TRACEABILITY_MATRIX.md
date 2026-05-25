# Matriz de Trazabilidad — Ecommify

**Proyecto:** Ecommify — Plataforma e-commerce multivendedor  
**Universidad:** Universidad de La Sabana · Fundamentos de Testing, Verificación y Validación  
**Equipo:** David Ricardo Grandas Cárdenas · Danilo Andrés Cortés Saavedra · Edisson Steven Bustos Galeano  
**Fecha:** Mayo 2026

---

## Módulo: Autenticación (`auth.service.test.js`) — HU-01 y HU-02

| Test ID | Given (Contexto) | When (Acción) | Then (Resultado esperado) | HU | Módulo | Estado |
|---|---|---|---|---|---|---|
| UT-001 | email con formato válido (`usuario@example.com`) | `validateEmail` es llamada | retorna `true` | HU-01 | auth | ✅ PASS |
| UT-002 | email sin `@` (`usuarioexample.com`) | `validateEmail` es llamada | retorna `false` | HU-01 | auth | ✅ PASS |
| UT-003 | contraseña fuerte (≥8 chars, mayúscula, número) | `validatePasswordStrength` es llamada | retorna `true` | HU-01 | auth | ✅ PASS |
| UT-004 | contraseña sin letras mayúsculas | `validatePasswordStrength` es llamada | retorna `false` | HU-01 | auth | ✅ PASS |
| UT-005 | contraseña de menos de 8 caracteres | `validatePasswordStrength` es llamada | retorna `false` | HU-01 | auth | ✅ PASS |
| UT-006 | contraseña sin dígitos (`PasswordOnly`) | `validatePasswordStrength` es llamada | retorna `false` | HU-01 | auth | ✅ PASS |
| UT-007 | contraseña en texto plano (`SecurePass1`) | `hashPassword` luego `verifyPassword` son llamadas | `verifyPassword` retorna `true` | HU-01 | auth | ✅ PASS |
| UT-008 | contraseña incorrecta comparada contra hash | `verifyPassword` es llamada | retorna `false` | HU-01 | auth | ✅ PASS |
| UT-009 | payload válido `{ userId, role }` | `generateJWT` es llamada | retorna string no vacío | HU-02 | auth | ✅ PASS |
| UT-010 | token JWT válido generado previamente | `verifyJWT` es llamada | retorna el payload original con `userId` y `role` | HU-02 | auth | ✅ PASS |
| UT-011 | token inválido (`invalid.token.string`) | `verifyJWT` es llamada | retorna `null` | HU-02 | auth | ✅ PASS |
| UT-012 | 2 intentos fallidos de login | `checkLoginAttempts` es llamada | `blocked: false` | HU-02 | auth | ✅ PASS |
| UT-013 | 3 intentos fallidos de login | `checkLoginAttempts` es llamada | `blocked: true`, `minutesLeft: 5` | HU-02 | auth | ✅ PASS |
| UT-014 | 5 intentos fallidos de login | `checkLoginAttempts` es llamada | `blocked: true`, `minutesLeft: 5` | HU-02 | auth | ✅ PASS |

---

## Módulo: Catálogo (`catalog.service.test.js`) — HU-03 y HU-04

| Test ID | Given (Contexto) | When (Acción) | Then (Resultado esperado) | HU | Módulo | Estado |
|---|---|---|---|---|---|---|
| UT-015 | lista de productos + rango de precio (500-1000) | `filterProductsByPrice` es llamada | retorna 2 productos dentro del rango | HU-03 | catalog | ✅ PASS |
| UT-016 | lista de productos + rango estrecho (1000-1600) | `filterProductsByPrice` es llamada | excluye productos fuera del rango; retorna 1 | HU-03 | catalog | ✅ PASS |
| UT-017 | lista de productos + categoría `laptops` | `filterProductsByCategory` es llamada | retorna solo los 2 laptops | HU-03 | catalog | ✅ PASS |
| UT-018 | lista de productos + rating mínimo 4.2 | `filterProductsByMinRating` es llamada | retorna 3 productos con rating ≥ 4.2 | HU-03 | catalog | ✅ PASS |
| UT-019 | productos + 3 filtros combinados (categoría, precio, rating) | `applyAllFilters` es llamada | aplica los 3 filtros; retorna 2 laptops | HU-03 | catalog | ✅ PASS |
| UT-020 | lista de productos + objeto de filtros vacío `{}` | `applyAllFilters` es llamada | retorna todos los productos sin filtrar | HU-03 | catalog | ✅ PASS |
| UT-021 | producto con `stock: 0` | `isProductAvailable` es llamada | retorna `false` | HU-04 | catalog | ✅ PASS |
| UT-022 | producto con `stock: 5` | `isProductAvailable` es llamada | retorna `true` | HU-04 | catalog | ✅ PASS |
| UT-023 | objeto producto completo con campo `description` extra | `formatProductSummary` es llamada | retorna solo `{id, name, price, stock, rating}`; sin `description` | HU-04 | catalog | ✅ PASS |

---

## Módulo: Carrito (`cart.service.test.js`) — HU-05

| Test ID | Given (Contexto) | When (Acción) | Then (Resultado esperado) | HU | Módulo | Estado |
|---|---|---|---|---|---|---|
| UT-024 | 2 ítems `[{price:100,qty:2},{price:50,qty:3}]` | `calculateSubtotal` es llamada | retorna `350` | HU-05 | cart | ✅ PASS |
| UT-025 | carrito vacío `[]` | `calculateSubtotal` es llamada | retorna `0` | HU-05 | cart | ✅ PASS |
| UT-026 | subtotal 100 y descuento del 10% | `calculateDiscount` es llamada | retorna `90` | HU-05 | cart | ✅ PASS |
| UT-027 | subtotal 100, descuento a 90, tasa de impuesto 19% | `calculateTotal` es llamada | retorna `≈107.1` | HU-05 | cart | ✅ PASS |
| UT-028 | `requestedQty: 5`, `availableStock: 2` | `validateStockLimit` es llamada | lanza `StockError` con mensaje "Stock máximo disponible: 2" | HU-05 | cart | ✅ PASS |
| UT-029 | `requestedQty: 1`, `availableStock: 5` | `validateStockLimit` es llamada | no lanza ninguna excepción | HU-05 | cart | ✅ PASS |
| UT-030 | carrito vacío + producto `{id:'p1', name:'Laptop', price:1500}` | `addItemToCart` es llamada con qty 1 | carrito tiene 1 ítem con los campos correctos | HU-05 | cart | ✅ PASS |
| UT-031 | carrito con 2 ítems (`p1` y `p2`) | `removeItemFromCart('p1')` es llamada | carrito queda con 1 ítem; solo `p2` permanece | HU-05 | cart | ✅ PASS |
| UT-032 | carrito con ítem `p1` qty 1 + nueva qty 3 | `updateItemQuantity` es llamada | `qty` se actualiza a 3; `calculateSubtotal` retorna `4500` | HU-05 | cart | ✅ PASS |
| UT-033 | carrito con ítem `p1` qty 1 + mismo producto qty 2 | `addItemToCart` es llamada de nuevo | `qty` acumula a 3; carrito sigue con 1 ítem | HU-05 | cart | ✅ PASS |
| UT-034 | `requestedQty > availableStock` | `validateStockLimit` es llamada | lanza instancia de `StockError` (verifica tipo exacto) | HU-05 | cart | ✅ PASS |

---

## Módulo: Checkout (`checkout.service.test.js`) — HU-06

| Test ID | Given (Contexto) | When (Acción) | Then (Resultado esperado) | HU | Módulo | Estado |
|---|---|---|---|---|---|---|
| UT-035 | dirección completa con todos los campos requeridos | `validateShippingAddress` es llamada | retorna `{ valid: true, errors: [] }` | HU-06 | checkout | ✅ PASS |
| UT-036 | dirección sin campo `city` | `validateShippingAddress` es llamada | retorna `{ valid: false, errors: ['city required'] }` | HU-06 | checkout | ✅ PASS |
| UT-037 | método de pago `"credit_card"` | `validatePaymentMethod` es llamada | retorna `true` | HU-06 | checkout | ✅ PASS |
| UT-038 | método de pago `"bitcoin"` | `validatePaymentMethod` es llamada | retorna `false` | HU-06 | checkout | ✅ PASS |
| UT-039 | sin argumentos | `generateOrderNumber` es llamada | retorna string que coincide con patrón `/^ORD-[A-Z0-9]{8}$/` | HU-06 | checkout | ✅ PASS |
| UT-040 | 2 ítems `[{price:1500,qty:1},{price:800,qty:2}]` + envío $50 | `calculateOrderTotal` es llamada | retorna `3150` | HU-06 | checkout | ✅ PASS |
| UT-041 | ítems con stock suficiente `{p1:10, p2:5}` | `processStockDecrement` es llamada | retorna inventario decrementado `{p1:8, p2:4}` | HU-06 | checkout | ✅ PASS |
| UT-042 | ítem con qty 20 y stock disponible 5 | `processStockDecrement` es llamada | lanza `InsufficientStockError`; inventario no se modifica | HU-06 | checkout | ✅ PASS |
| UT-043 | carrito + dirección + método de pago | `buildOrderSummary` es llamada | retorna objeto con `orderId`, `total`, `items`, `address` | HU-06 | checkout | ✅ PASS |
| UT-044 | todos los métodos válidos `['credit_card','boleto','debit_card']` | `validatePaymentMethod` es llamada para cada uno | retorna `true` para todos | HU-06 | checkout | ✅ PASS |

---

## Módulo: Reseñas (`reviews.service.test.js`) — HU-07

| Test ID | Given (Contexto) | When (Acción) | Then (Resultado esperado) | HU | Módulo | Estado |
|---|---|---|---|---|---|---|
| UT-045 | puntuación `4` (entero entre 1 y 5) | `validateReviewScore` es llamada | retorna `true` | HU-07 | reviews | ✅ PASS |
| UT-046 | puntuación `0` (fuera de rango mínimo) | `validateReviewScore` es llamada | retorna `false` | HU-07 | reviews | ✅ PASS |
| UT-047 | puntuación `6` (fuera de rango máximo) | `validateReviewScore` es llamada | retorna `false` | HU-07 | reviews | ✅ PASS |
| UT-048 | puntuación `3.5` (decimal, no entero) | `validateReviewScore` es llamada | retorna `false` | HU-07 | reviews | ✅ PASS |
| UT-049 | historial de compras vacío `[]` | `canUserReview` es llamada con userId y productId | retorna `false` | HU-07 | reviews | ✅ PASS |
| UT-050 | historial con compra entregada del producto (`status:'delivered'`) | `canUserReview` es llamada | retorna `true` | HU-07 | reviews | ✅ PASS |
| UT-051 | compra en estado `"pending"` (no entregada) | `canUserReview` es llamada | retorna `false` | HU-07 | reviews | ✅ PASS |
| UT-052 | reseña existente para la misma combinación usuario-producto | `hasExistingReview` es llamada | retorna `true` | HU-07 | reviews | ✅ PASS |
| UT-053 | sin reseña previa para ese usuario-producto | `hasExistingReview` es llamada | retorna `false` | HU-07 | reviews | ✅ PASS |
| UT-054 | array de reseñas con scores `[5, 4, 3]` | `calculateAverageRating` es llamada | retorna `4.00` | HU-07 | reviews | ✅ PASS |
| UT-055 | array de reseñas vacío `[]` | `calculateAverageRating` es llamada | retorna `0` | HU-07 | reviews | ✅ PASS |
| UT-056 | userId, productId, score 5 y comentario | `buildReviewDocument` es llamada | retorna documento con todos los campos + `createdAt` | HU-07 | reviews | ✅ PASS |

---

## Módulo: Inventario (`inventory.service.test.js`) — HU-08

| Test ID | Given (Contexto) | When (Acción) | Then (Resultado esperado) | HU | Módulo | Estado |
|---|---|---|---|---|---|---|
| UT-057 | valor de stock `10` (entero positivo) | `validateStockValue` es llamada | retorna `true` | HU-08 | inventory | ✅ PASS |
| UT-058 | valor de stock `-1` (negativo) | `validateStockValue` es llamada | retorna `false` | HU-08 | inventory | ✅ PASS |
| UT-059 | valor de stock `0` (cero es válido) | `validateStockValue` es llamada | retorna `true` | HU-08 | inventory | ✅ PASS |
| UT-060 | valor de stock `1.5` (decimal, no entero) | `validateStockValue` es llamada | retorna `false` | HU-08 | inventory | ✅ PASS |
| UT-061 | stock es `0` | `isOutOfStock` es llamada | retorna `true` | HU-08 | inventory | ✅ PASS |
| UT-062 | stock es `1` | `isOutOfStock` es llamada | retorna `false` | HU-08 | inventory | ✅ PASS |
| UT-063 | `currentStock: 10`, `newStock: 25` | `applyStockUpdate` es llamada | retorna `{ updated: 25, delta: 15, isOutOfStock: false }` | HU-08 | inventory | ✅ PASS |
| UT-064 | `currentStock: 5`, `newStock: 0` | `applyStockUpdate` es llamada | retorna `{ updated: 0, delta: -5, isOutOfStock: true }` | HU-08 | inventory | ✅ PASS |
| UT-065 | `productId`, `userId`, `oldStock: 10`, `newStock: 25` | `buildStockHistoryEntry` es llamada | retorna objeto con `timestamp`, `productId`, `userId`, `oldStock`, `newStock` | HU-08 | inventory | ✅ PASS |
| UT-066 | vendedor propietario del producto (`sellerId` coincide) | `validateSellerOwnership` es llamada | retorna `true` | HU-08 | inventory | ✅ PASS |
| UT-067 | vendedor que NO es propietario del producto | `validateSellerOwnership` es llamada | retorna `false` | HU-08 | inventory | ✅ PASS |

---

## Resumen

| Métrica | Valor |
|---|---|
| Total de tests | **67** |
| Tests PASS | **67** |
| Tests FAIL | **0** |
| Test Suites | **6 / 6** |
| Cobertura — Statements | **98.30%** |
| Cobertura — Branches | **89.28%** |
| Cobertura — Functions | **100.00%** |
| Cobertura — Lines | **100.00%** |
| HUs cubiertas | **8 de 8** (HU-01 al HU-08) |
| Umbral mínimo (75%) superado | **✅ Todas las métricas** |

> Evidencia completa: `tests/evidence/test-output.txt`
