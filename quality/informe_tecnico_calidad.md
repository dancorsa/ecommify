# Informe Técnico de Calidad – Ecommify

**Proyecto:** Ecommify – Plataforma de e-commerce multi-vendor  
**Universidad:** Universidad de La Sabana – Maestría en Arquitectura de Software  
**Materia:** Fundamentos de Testing – Unidad 6: Gestión de defectos y validación final  
**Equipo:**
- Danilo Andrés Cortés Saavedra
- David Ricardo Grandas Cárdenas
- Edisson Steven Bustos Galeano

**Fecha de elaboración:** 2026-06-20  
**Período de pruebas:** 2026-06-11  
**Versión:** 1.0

---

## 1. Resumen Ejecutivo

El proyecto Ecommify implementó una estrategia integral de pruebas que combinó **pruebas unitarias con TDD** y **pruebas de rendimiento con Apache JMeter**, cubriendo los dos ejes fundamentales de calidad de software: corrección funcional y capacidad operacional.

| Dimensión | Resultado |
|-----------|-----------|
| **Pruebas unitarias** | 67/67 tests pasados · cobertura 98.3% statements · 100% functions y lines |
| **Pruebas de rendimiento** | 6 escenarios ejecutados · punto de quiebre identificado en 400 VUs · sin memory leaks |
| **Defectos registrados** | 5 defectos PERF-01 a PERF-05 · 3 cerrados · 2 abiertos (P1) |
| **SLOs baseline** | Cumplidos al 100% con 10 VUs (p95=62ms, p99=178ms, error=0%) |
| **Veredicto general** | El sistema es **apto para producción a escala normal** (<100 VUs simultáneos) con acciones de mejora requeridas antes de escalar a alta demanda |

---

## 2. Metodología de Pruebas

### 2.1 Pruebas Unitarias (Jest 29.7.0)

Se aplicó **Desarrollo Guiado por Pruebas (TDD)** con el ciclo clásico Rojo → Verde → Refactor. Cada módulo del backend fue desarrollado escribiendo primero la prueba que falla, luego el código mínimo para pasarla y finalmente refactorizando.

**Patrones aplicados:**
- **AAA (Arrange, Act, Assert):** estructura uniforme en los 67 tests
- **BDD Given/When/Then:** nomenclatura descriptiva que hace las pruebas legibles para stakeholders no técnicos
- **Mocking total:** PostgreSQL y MongoDB completamente mockeados — las pruebas corren en ~20 segundos sin infraestructura activa

**Herramientas:**
- Jest 29.7.0 — framework de testing
- Supertest — pruebas de controladores HTTP
- GitHub Actions — ejecución automática en cada push a `main`

### 2.2 Pruebas de Rendimiento (Apache JMeter 5.4.3)

Se definieron **SLOs** antes de ejecutar las pruebas para evitar sesgo en la interpretación:

| SLO | Umbral | Justificación |
|-----|--------|---------------|
| p95 latencia | < 300ms | Experiencia de usuario aceptable para catálogo |
| p99 latencia | < 800ms | Tolerancia máxima percibida |
| Tasa de errores | < 1% | Confiabilidad mínima e-commerce |
| Throughput | > 10 req/s | Mínimo operacional |

Se ejecutaron **6 escenarios progresivos** sobre el endpoint `GET /api/catalog/:id`, siguiendo una estrategia que va de la medición de referencia hasta la validación de ausencia de regresión.

---

## 3. Resultados de Pruebas Unitarias

### 3.1 Resumen de ejecución

```
Test Suites: 6 passed, 6 total
Tests:       67 passed, 67 total
Duration:    ~20 segundos
```

### 3.2 Cobertura por módulo

| Módulo | Tests | Statements | Branches | Functions | Lines | HU |
|--------|-------|------------|----------|-----------|-------|----|
| Auth | 14 | 93.33% | 87.5% | 100% | 100% | HU-01, HU-02 |
| Catalog | 9 | 100% | 90.9% | 100% | 100% | HU-03, HU-04 |
| Cart | 11 | 100% | 75.0% | 100% | 100% | HU-05 |
| Checkout | 10 | 100% | 88.9% | 100% | 100% | HU-06 |
| Reviews | 12 | 100% | 100% | 100% | 100% | HU-07 |
| Inventory | 11 | 100% | 100% | 100% | 100% | HU-08 |
| **GLOBAL** | **67** | **98.3%** | **89.28%** | **100%** | **100%** | HU-01 a HU-08 |

> Umbral mínimo configurado: 75% en todas las métricas. Todos los módulos superan el umbral.

### 3.3 Trazabilidad con historias de usuario

La **Matriz de Trazabilidad** (`backend/docs/TRACEABILITY_MATRIX.md`) mapea los 67 tests (UT-001 a UT-067) con las 8 historias de usuario (HU-01 a HU-08). Esto garantiza que cada requisito funcional tiene al menos un test automatizado que lo valida.

| Historia de Usuario | Descripción | Tests cubiertos |
|---------------------|-------------|-----------------|
| HU-01 | Registro de usuario | UT-001 a UT-014 |
| HU-02 | Login con JWT | UT-001 a UT-014 |
| HU-03 | Listado de catálogo con filtros | UT-015 a UT-023 |
| HU-04 | Detalle de producto | UT-015 a UT-023 |
| HU-05 | Gestión de carrito | UT-024 a UT-034 |
| HU-06 | Checkout y creación de pedido | UT-035 a UT-044 |
| HU-07 | Reseñas de productos | UT-045 a UT-056 |
| HU-08 | Gestión de inventario del vendedor | UT-057 a UT-067 |

---

## 4. Resultados de Pruebas de Rendimiento

### 4.1 Tabla comparativa de escenarios

| Escenario | VUs | p95 (ms) | p99 (ms) | Throughput (req/s) | Error% | Estado SLO |
|-----------|-----|----------|----------|--------------------|--------|-----------|
| 01 Baseline | 10 | 62 | 178 | 40.9 | 0.00% | ✅ PASS |
| 02 Load E1 (50 VUs) | 50 | 57 | 100 | 176.5 | 34.68%* | ❌ Entorno |
| 02 Load E2 (100 VUs) | 100 | 187 | 246 | 336.9 | 62.4%* | ❌ Entorno |
| 03 Stress E1 (200 VUs) | 200 | 651 | 754 | 401.7 | 0.00% | ⚠️ p95 alto |
| 03 Stress E2 (400 VUs) | 400 | 10.010 | 10.016 | 390.5 | 5.12% | ❌ Timeout |
| 03 Stress E3 (600 VUs) | 600 | 10.012 | 10.017 | 387.3 | 11.95% | ❌ Timeout |
| 04 Spike base | 10 | 31 | 38 | 421.5 | 0.00% | ✅ PASS |
| 04 Spike pico (300 VUs) | 300 | 621 | 10.003 | 434.9 | 0.96% | ⚠️ Límite |
| 04 Spike recuperación | 10 | 35 | 43 | 385.7 | 0.00% | ✅ PASS |
| 05 Soak 60 min | 100 | 26 | 39 | 63.0 | 0.004% | ✅ PASS |
| 06 Regresión | 10 | 25 | 42 | 43.4 | 0.008% | ✅ PASS |

*BindException TCP Windows (limitación del SO del host de pruebas, no de la aplicación)

### 4.2 Hallazgos principales

1. **Baseline sólido:** Con 10 VUs el sistema cumple todos los SLOs holgadamente (p95=62ms, p99=178ms, error=0%). Es la referencia de rendimiento óptimo.

2. **Punto de quiebre real: 200–400 VUs.** A 200 VUs sin think time el sistema opera sin errores HTTP (p95=651ms, excediendo el SLO de p95 pero sin timeouts). A 400+ VUs el pool de conexiones de PostgreSQL se satura generando timeouts sistemáticos de 10 s.

3. **Resiliencia ante picos:** Tras un spike de 300 VUs el sistema recuperó rendimiento normal (~35ms) en menos de 2 minutos, confirmando capacidad de recuperación ante tráfico repentino.

4. **Sin memory leaks:** La prueba de soak de 60 minutos con 100 VUs mostró p95=26ms constante y p99=39ms estable. El throughput no decreció. No se detectaron señales de degradación sostenida.

5. **Sin regresión:** La prueba de regresión (escenario 06) obtuvo mejor rendimiento que el baseline (p95=25ms vs 62ms), atribuible al "warm-up" de la caché de PostgreSQL durante las pruebas previas.

---

## 5. Ciclo de Vida de Defectos

El ciclo de vida completo de cada defecto está documentado en `perf/defectos_rendimiento.md`. A continuación se presenta el resumen de etapas cumplidas por defecto.

### 5.1 Defectos cerrados

**PERF-01 – Agotamiento de puertos TCP (Entorno · Alta · P2)**  
Detectado el 2026-06-11 por Danilo Andrés Cortés Saavedra. Clasificado como limitación del SO Windows (TIME_WAIT 240s, rango 49152-65535). Mitigación aplicada: ConstantTimer de pacing. Validado por David Ricardo Grandas Cárdenas el mismo día. **Cerrado** — no es un defecto de la aplicación.

**PERF-04 – Throughput limitado por Windows (Entorno · Media · P3)**  
Detectado el 2026-06-11. Misma causa raíz que PERF-01. El throughput real de la aplicación se puede inferir de los escenarios de bajo VU. **Cerrado** — no accionable sin cambio de entorno de pruebas.

**PERF-05 – Riesgo de degradación en soak (Rendimiento · Media · P3)**  
Registrado como defecto preventivo. La ejecución de 60 minutos demostró empíricamente que no existen memory leaks (p99 estable en 39ms). **Cerrado** — riesgo descartado por evidencia.

### 5.2 Defectos abiertos (requieren acción)

**PERF-02 – Pool de PostgreSQL saturado (Rendimiento · Crítica · P1)**  
Detectado el 2026-06-11. El pool de conexiones de PostgreSQL (parámetro `pg.Pool.max` con valor por defecto ~10) se satura a partir de 400 VUs simultáneos, generando timeouts de 10 s. **Abierto** — requiere aumento del pool, implementación de circuit breaker, y evaluación de PgBouncer.

**PERF-03 – Latencia elevada en spike sin rate limiting (Diseño · Alta · P1)**  
Detectado el 2026-06-11. La aplicación no cuenta con mecanismos de control de carga, absorbiendo el pico sin válvula de alivio. p95=621ms durante el pico de 300 VUs. **Abierto** — requiere implementar `express-rate-limit` y cola de solicitudes con respuestas 503 explícitas.

---

## 6. Análisis y Priorización de Defectos

### 6.1 Matriz de priorización

| ID | Tipo | Severidad | Prob. en producción | Prioridad | Estado |
|----|------|-----------|---------------------|-----------|--------|
| PERF-02 | Rendimiento | Crítica | Alta (cualquier tráfico >400 usuarios) | **P1 — Bloquea release a escala** | 🔴 Abierto |
| PERF-03 | Diseño | Alta | Alta (sin rate limiting en prod.) | **P1 — Bloquea release a escala** | 🔴 Abierto |
| PERF-01 | Entorno | Alta | Baja (solo aplica a Windows test) | P2 — Próximo ciclo | ✅ Cerrado |
| PERF-04 | Entorno | Media | Baja (solo aplica a Windows test) | P3 — Backlog | ✅ Cerrado |
| PERF-05 | Rendimiento | Media | Baja (descartado por soak) | P3 — Backlog | ✅ Cerrado |

### 6.2 Métricas de gestión de defectos

| Métrica | Valor |
|---------|-------|
| Total de defectos registrados | 5 |
| Defectos cerrados | 3 (60%) |
| Defectos abiertos | 2 (40%) |
| Defectos P1 abiertos | 2 |
| Densidad de defectos (por 100 tests unitarios) | 0.07 |
| Tiempo promedio de análisis | Mismo día (2026-06-11) |
| Trazabilidad cubierta | 100% (todos los defectos vinculados a escenario JMX y HU) |

---

## 7. Métricas de Calidad Consolidadas

| Categoría | Métrica | Valor | Umbral | Estado |
|-----------|---------|-------|--------|--------|
| **Unitarias** | Pass rate | 100% | 100% | ✅ |
| **Unitarias** | Cobertura statements | 98.3% | 75% | ✅ |
| **Unitarias** | Cobertura branches | 89.28% | 75% | ✅ |
| **Unitarias** | Cobertura functions | 100% | 75% | ✅ |
| **Unitarias** | Cobertura lines | 100% | 75% | ✅ |
| **Rendimiento** | Baseline p95 | 62ms | <300ms | ✅ |
| **Rendimiento** | Baseline error rate | 0.00% | <1% | ✅ |
| **Rendimiento** | Soak 60min p95 | 26ms | <300ms | ✅ |
| **Rendimiento** | Regresión p95 | 25ms | <300ms | ✅ |
| **Rendimiento** | Punto de quiebre | 400 VUs | Documentado | ℹ️ |
| **Defectos** | Tasa de cierre | 60% (3/5) | — | ℹ️ |
| **Defectos** | P1 sin resolver | 2 | 0 para release | ⚠️ |
| **CI/CD** | Pipeline automatizado | Sí (GitHub Actions) | Requerido | ✅ |
| **Trazabilidad** | Tests a HUs mapeados | 67/67 (100%) | 100% | ✅ |

---

## 8. Conclusiones y Reflexión Final

### 8.1 ¿Qué aprendió el equipo de aplicar pruebas unitarias con TDD?

**El TDD cambia la forma de diseñar, no solo de probar.** Al escribir la prueba primero, el desarrollador se ve obligado a pensar en la interfaz pública del módulo desde la perspectiva del consumidor, no del implementador. Esto resultó en módulos más cohesivos y con dependencias claramente inyectables.

El **mocking total** fue una decisión clave: permitió ejecutar 67 tests en ~20 segundos sin infraestructura activa, haciendo el ciclo de feedback inmediato y habilitando un CI/CD que corre en menos de 3 minutos. La contrapartida es que los tests unitarios no detectan problemas de integración entre la lógica de negocio y las bases de datos reales.

La **matriz de trazabilidad** demostró su valor al vincular cada test con una historia de usuario: cuando un test falla, se sabe inmediatamente qué funcionalidad de negocio está en riesgo.

### 8.2 ¿Qué aprendió el equipo de aplicar pruebas de rendimiento con JMeter?

**El baseline es la prueba más valiosa.** Sin establecer las métricas de referencia con carga mínima, ningún otro escenario tendría contexto para ser interpretado. La prueba de regresión al final del ciclo cerró el ciclo de calidad: confirmar que el sistema no se deterioró.

**Los SLOs deben definirse antes de las pruebas.** Si se definen después de ver los resultados, inevitablemente se ajustan a lo que el sistema ya logró, perdiendo su función como criterio objetivo de aceptación.

**La prueba de soak reveló lo que ninguna otra prueba podría.** La estabilidad en 60 minutos de carga sostenida fue la evidencia más sólida de que el sistema está listo para operación continua a escala media.

**Los cuellos de botella no siempre están en el código.** El límite del connection pool de PostgreSQL y las restricciones TCP del SO Windows fueron los principales impedimentos, no la lógica de la aplicación. Esto enseña que las pruebas de rendimiento exigen conocimiento del entorno completo, no solo del código.

### 8.3 Integración de ambos tipos de prueba

Ningún tipo de prueba es suficiente por sí solo:

- Las **pruebas unitarias** validan la **corrección** del código: que cada función hace lo que debe, bajo las condiciones esperadas y bajo condiciones de error.
- Las **pruebas de rendimiento** validan la **capacidad operacional**: que el sistema funciona bajo carga real, sin degradarse ni fallar ante variaciones de tráfico.

Juntas, cubren el espectro de confianza necesario para llevar un sistema a producción: sé que el código es correcto **y** sé que soportará la carga esperada.

---

## 9. Recomendaciones de Mejora

| # | Recomendación | Defecto relacionado | Prioridad | Esfuerzo |
|---|---------------|---------------------|-----------|----------|
| 1 | Aumentar `pg.Pool.max` a 50 conexiones en configuración de producción | PERF-02 | P1 | Bajo |
| 2 | Implementar `express-rate-limit` en endpoints públicos (catálogo) | PERF-03 | P1 | Bajo |
| 3 | Agregar respuesta 503 con Retry-After cuando el pool esté saturado | PERF-02, PERF-03 | P1 | Medio |
| 4 | Ejecutar pruebas de carga desde Linux o modo distribuido JMeter | PERF-01, PERF-04 | P2 | Medio |
| 5 | Implementar cache Redis L2 para resultados de catálogo (TTL 60s) | PERF-03 | P2 | Alto |
| 6 | Habilitar clustering Node.js o usar PM2 en producción | PERF-02 | P2 | Bajo |
| 7 | Agregar pruebas de integración (API + BD real) con base de datos de prueba | — | P2 | Alto |
| 8 | Implementar monitoreo de `process.memoryUsage()` en producción | PERF-05 | P3 | Bajo |

---

## 10. Evidencias y Artefactos del Proyecto

| Artefacto | Ubicación | Descripción |
|-----------|-----------|-------------|
| Pruebas unitarias | `backend/tests/` | 67 tests en 12 archivos (service + controller por módulo) |
| Reporte de cobertura HTML | `backend/coverage/index.html` | Cobertura interactiva por archivo |
| Log de ejecución | `backend/tests/evidence/test-output.txt` | Salida completa de Jest |
| Plan de pruebas | `backend/docs/TEST_PLAN.md` | Estrategia TDD, patrones, configuración |
| Matriz de trazabilidad | `backend/docs/TRACEABILITY_MATRIX.md` | 67 tests × 8 HUs |
| Scripts JMeter | `perf/scripts/*.jmx` | 6 escenarios de rendimiento |
| Resultados JTL | `perf/results/*.jtl` | Datos crudos de JMeter |
| Reportes HTML JMeter | `perf/results/*_report/` | 6 reportes interactivos |
| Screenshots de evidencia | `perf/results/screenshots/` | 6 capturas de estadísticas |
| Registro de defectos | `perf/defectos_rendimiento.md` | PERF-01 a PERF-05 con ciclo de vida completo |
| Informe de ejecución | `informe_ejecucion.md` | Resultados detallados de rendimiento |
| **Dashboard de calidad** | `quality/dashboard_calidad.html` | Métricas visualizadas e integradas |
| **Este informe** | `quality/informe_tecnico_calidad.md` | Informe técnico consolidado |
| Pipeline CI/CD | `.github/workflows/ci.yml` | GitHub Actions automatizado |
