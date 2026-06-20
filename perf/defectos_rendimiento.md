# Registro de Defectos de Rendimiento – Ecommify API

**Proyecto:** Ecommify – API de Catálogo de Productos  
**Endpoint bajo prueba:** `GET /api/catalog/:id` (Node.js + Express + PostgreSQL)  
**Período de pruebas:** 2026-06-11  
**Equipo:** Danilo Andrés Cortés Saavedra · David Ricardo Grandas Cárdenas · Edisson Steven Bustos Galeano

---

## Tabla Resumen con Priorización

| ID | Tipo | Escenario | SLO Violado | Severidad | Prioridad | Estado Final |
|----|------|-----------|-------------|-----------|-----------|--------------|
| PERF-01 | Entorno | Load (02) – 100 VUs | Error rate > 1% (BindException Windows) | Alta | P2 | ✅ Cerrado |
| PERF-02 | Rendimiento | Stress (03) – 600 VUs | p95 > 300ms, error rate > 50% | Crítica | P1 | 🔴 Abierto |
| PERF-03 | Diseño | Spike (04) – 300 VUs | p95 > 300ms durante el pico | Alta | P1 | 🔴 Abierto |
| PERF-04 | Entorno | Load (02) – 100 VUs | Throughput < límite TCP Windows | Media | P3 | ✅ Cerrado |
| PERF-05 | Rendimiento | Soak (05) – 60 min | Degradación progresiva p99 (riesgo) | Media | P3 | ✅ Cerrado |

---

## Matriz de Priorización (Severidad × Probabilidad en Producción)

|  | **Baja probabilidad en prod.** | **Alta probabilidad en prod.** |
|---|---|---|
| **Severidad Crítica** | — | **PERF-02** → P1 (pool PostgreSQL) |
| **Severidad Alta** | PERF-01, PERF-04 → P2/P3 (limitación SO Windows) | **PERF-03** → P1 (sin rate limiting) |
| **Severidad Media** | PERF-05 → P3 (confirmado sin leak) | — |

> **P1** = Bloquea release · **P2** = Corregir antes del siguiente ciclo · **P3** = Backlog / documentado

---

## PERF-01 – Agotamiento de Puertos TCP en Carga Alta

| Campo | Valor |
|-------|-------|
| **ID** | PERF-01 |
| **Tipo** | Entorno (limitación del host de pruebas) |
| **Escenario** | 02_load_test – Etapa 2 (100 VUs) |
| **HU afectada** | HU-03, HU-04 (catálogo) |
| **Trazabilidad** | `perf/scripts/02_load_test.jmx` · `perf/results/02_load.jtl` |
| **SLO violado** | Error rate > 1% |
| **Severidad** | Alta |
| **Prioridad** | P2 |
| **Fecha detección** | 2026-06-11 |
| **Detectado por** | Danilo Andrés Cortés Saavedra |
| **Fecha análisis** | 2026-06-11 |
| **Fecha validación** | 2026-06-11 |
| **Validado por** | David Ricardo Grandas Cárdenas |
| **Fecha cierre** | 2026-06-11 |
| **Estado** | ✅ Cerrado |
| **Evidencia** | `perf/results/screenshots/02_load_statistics.png` |

### Ciclo de vida

**1. Identificación**  
Al alcanzar 100 VUs sin pacing suficiente, JMeter reporta errores `java.net.BindException: Address already in use: connect`. La tasa de error supera el 1% establecido como SLO.

**2. Clasificación**  
Tipo: Limitación de entorno (SO Windows). No es un defecto de la aplicación; el error ocurre en el cliente JMeter, no en el servidor. Severidad Alta porque distorsiona los resultados de toda la batería de pruebas de carga.

**3. Seguimiento y validación**  
- Windows reserva puertos efímeros 49152–65535 (16.383 puertos) con TIME_WAIT de 240 s → límite real ~68 req/s desde un único host.  
- Se aplicó mitigación: ConstantTimer 200 ms para ≤50 VUs y 1.500 ms para 100 VUs en escenarios sostenidos.  
- Validación: tras aplicar el timer, los escenarios de bajo VU corrieron sin BindException.

**4. Cierre**  
Defecto cerrado. La causa raíz es el entorno Windows, no la aplicación. La mitigación aplicada (pacing) es suficiente para el contexto académico. En producción se ejecutaría desde Linux o modo distribuido de JMeter. La aplicación en sí cumple los SLOs de latencia (p95=187ms, p99=246ms a 100 VUs).

---

## PERF-02 – Degradación Severa Bajo Estrés (600 VUs)

| Campo | Valor |
|-------|-------|
| **ID** | PERF-02 |
| **Tipo** | Rendimiento (diseño de infraestructura) |
| **Escenario** | 03_stress_test – Etapa 3 (600 VUs) |
| **HU afectada** | HU-03, HU-04, HU-05, HU-06 (todos los módulos con acceso a PostgreSQL) |
| **Trazabilidad** | `perf/scripts/03_stress_test.jmx` · `perf/results/03_stress.jtl` |
| **SLO violado** | p95 > 300ms, p99 > 800ms, error rate > 1% |
| **Severidad** | Crítica |
| **Prioridad** | P1 |
| **Fecha detección** | 2026-06-11 |
| **Detectado por** | Edisson Steven Bustos Galeano |
| **Fecha análisis** | 2026-06-11 |
| **Fecha validación** | Pendiente (requiere fix) |
| **Estado** | 🔴 Abierto |
| **Evidencia** | `perf/results/screenshots/03_stress_statistics.png` |

### Ciclo de vida

**1. Identificación**  
Con 600 VUs simultáneos sin think time, el p95 supera los 10.000 ms y la tasa de error alcanza el 11.95%. El sistema no responde dentro de los SLOs definidos para ninguna métrica.

**2. Clasificación**  
Tipo: Rendimiento / Diseño. La causa no es el código de la aplicación sino la configuración del pool de conexiones de PostgreSQL (parámetro `pg.Pool.max` con valor por defecto) y la naturaleza single-threaded del event loop de Node.js bajo alta concurrencia I/O.

**3. Seguimiento**  
- Punto de quiebre confirmado entre 200 y 400 VUs: a 200 VUs el sistema opera sin errores HTTP (p95=651ms); a 400+ VUs el pool se satura generando timeouts de 10 s.  
- El defecto se reproduce de forma consistente en cada ejecución del escenario 03.  
- Impacto transversal: afecta a todos los módulos con consultas a PostgreSQL (catálogo, carrito, checkout).

**4. Recomendaciones (pendiente de implementación)**  
- Aumentar `pg.Pool.max` de su valor por defecto (10) a 50–100.  
- Implementar circuit breaker (ej. `opossum`) para rechazar solicitudes antes de timeout.  
- Evaluar conexión mediante PgBouncer para reutilización eficiente de conexiones.  
- Habilitar clustering Node.js o PM2 para aprovechar múltiples núcleos.

**5. Cierre**  
Pendiente. El defecto permanece abierto hasta que se apliquen y validen las recomendaciones en un nuevo ciclo de pruebas de estrés.

---

## PERF-03 – Latencia Elevada Durante Pico de Tráfico

| Campo | Valor |
|-------|-------|
| **ID** | PERF-03 |
| **Tipo** | Diseño (ausencia de mecanismos de control de carga) |
| **Escenario** | 04_spike_test – Fase pico (300 VUs) |
| **HU afectada** | HU-03, HU-04 (catálogo público) |
| **Trazabilidad** | `perf/scripts/04_spike_test.jmx` · `perf/results/04_spike.jtl` |
| **SLO violado** | p95 > 300ms durante el pico |
| **Severidad** | Alta |
| **Prioridad** | P1 |
| **Fecha detección** | 2026-06-11 |
| **Detectado por** | David Ricardo Grandas Cárdenas |
| **Fecha análisis** | 2026-06-11 |
| **Fecha validación** | Pendiente (requiere fix) |
| **Estado** | 🔴 Abierto |
| **Evidencia** | `perf/results/screenshots/04_spike_statistics.png` |

### Ciclo de vida

**1. Identificación**  
Al inyectar 300 VUs en 30 segundos desde una base de 10 VUs, el p95 se dispara a 621 ms (SLO: 300 ms) y el p99 alcanza 10.003 ms. El error rate es del 0.96%, rozando el límite del 1%.

**2. Clasificación**  
Tipo: Diseño. La aplicación no cuenta con mecanismos de control de carga (rate limiting, queue, shed), por lo que absorbe el pico sin ninguna válvula de alivio. Es un defecto de diseño de capacidad, no un error funcional.

**3. Seguimiento**  
- El sistema recupera el rendimiento normal (~35 ms) en menos de 2 minutos tras el pico, lo que confirma resiliencia básica.  
- La latencia durante el pico viola el SLO de p95 y el p99 entra en timeout, indicando saturación momentánea del pool.  
- Reproducible en cada ejecución del escenario 04.

**4. Recomendaciones (pendiente de implementación)**  
- Implementar rate limiting con `express-rate-limit` (ej. máx. 200 req/min por IP).  
- Agregar cola de solicitudes con timeout explícito (respuesta 503 antes de los 10 s de timeout del pool).  
- Evaluar cache de resultados de catálogo en Redis para reducir presión sobre PostgreSQL durante picos.

**5. Cierre**  
Pendiente. El defecto permanece abierto hasta implementar al menos el rate limiting básico y repetir el escenario de spike.

---

## PERF-04 – Throughput Limitado por Sistema Operativo Windows

| Campo | Valor |
|-------|-------|
| **ID** | PERF-04 |
| **Tipo** | Entorno (limitación del host de pruebas) |
| **Escenario** | 02_load_test – Todas las etapas |
| **HU afectada** | HU-03, HU-04 (impacto en medición, no en funcionalidad) |
| **Trazabilidad** | `perf/scripts/02_load_test.jmx` · `perf/results/02_load.jtl` |
| **SLO violado** | Throughput observado < throughput real de la aplicación |
| **Severidad** | Media |
| **Prioridad** | P3 |
| **Fecha detección** | 2026-06-11 |
| **Detectado por** | Danilo Andrés Cortés Saavedra |
| **Fecha análisis** | 2026-06-11 |
| **Fecha validación** | 2026-06-11 |
| **Validado por** | Edisson Steven Bustos Galeano |
| **Fecha cierre** | 2026-06-11 |
| **Estado** | ✅ Cerrado |
| **Evidencia** | `jmeter.log` (errores BindException) |

### Ciclo de vida

**1. Identificación**  
El throughput máximo medido desde el host Windows es ~68 req/s, artificialmente limitado por el agotamiento de puertos efímeros del SO (TIME_WAIT 240 s, rango 49152–65535 = 16.383 puertos disponibles).

**2. Clasificación**  
Tipo: Entorno. No es un defecto de la aplicación ni de la configuración del servidor. Es una restricción inherente al SO Windows utilizado como host de pruebas de JMeter.

**3. Seguimiento y validación**  
- El throughput real de la aplicación se puede inferir de escenarios con bajo VU (baseline: 40.9 req/s con margen) y de los escenarios de stress donde se midieron 390–400 req/s antes del punto de quiebre.  
- La comparación entre los escenarios confirma que la limitación es del cliente JMeter en Windows, no del servidor.

**4. Cierre**  
Defecto cerrado. No es accionable sin cambio de entorno de pruebas. Documentado para que los resultados de throughput se interpreten con la restricción del contexto Windows. Para mediciones exactas de throughput en entorno productivo se debe usar Linux + modo distribuido de JMeter.

---

## PERF-05 – Degradación Progresiva en Prueba de Resistencia

| Campo | Valor |
|-------|-------|
| **ID** | PERF-05 |
| **Tipo** | Rendimiento (riesgo de memory leak) |
| **Escenario** | 05_soak_test – 100 VUs × 60 minutos |
| **HU afectada** | Todas (riesgo sistémico en carga sostenida) |
| **Trazabilidad** | `perf/scripts/05_soak_test.jmx` · `perf/results/05_soak.jtl` |
| **SLO violado** | Riesgo de p99 progresivamente creciente |
| **Severidad** | Media |
| **Prioridad** | P3 |
| **Fecha detección** | 2026-06-11 |
| **Detectado por** | David Ricardo Grandas Cárdenas |
| **Fecha análisis** | 2026-06-11 |
| **Fecha validación** | 2026-06-11 |
| **Validado por** | Danilo Andrés Cortés Saavedra · Edisson Steven Bustos Galeano |
| **Fecha cierre** | 2026-06-11 |
| **Estado** | ✅ Cerrado |
| **Evidencia** | `perf/results/screenshots/05_soak_statistics.png` |

### Ciclo de vida

**1. Identificación**  
Durante el análisis preventivo de la prueba de soak, se identificó el riesgo de que el p99 mostrara tendencia creciente a lo largo de 60 minutos (incremento > 20% entre minuto 10 y minuto 55), indicando posibles memory leaks o acumulación de recursos no liberados.

**2. Clasificación**  
Tipo: Rendimiento (defecto preventivo / riesgo). Se registró como defecto potencial antes de la ejecución completa de la prueba, dado el patrón común en aplicaciones Node.js con muchos event listeners y conexiones de base de datos.

**3. Seguimiento y validación**  
Tras ejecutar el soak de 60 minutos se midieron los siguientes resultados:
- p95 global: 26 ms (sin degradación visible)  
- p99 global: 39 ms (estable durante toda la prueba)  
- Error rate: 0.0035% (8/226.657 requests — errores transitorios, no sistemáticos)  
- Throughput: 63.0 req/s constante  
- No se detectó tendencia creciente en latencia ni decreciente en throughput.

**4. Cierre**  
Defecto cerrado. La ejecución real del soak de 60 minutos demostró que el sistema **no tiene memory leaks** ni degradación progresiva de rendimiento en carga sostenida de 100 VUs. El riesgo queda descartado empíricamente.

---

## Plantilla para Nuevos Defectos

```
| Campo | Valor |
|-------|-------|
| **ID** | PERF-0X |
| **Tipo** | Rendimiento / Entorno / Diseño / Configuración |
| **Escenario** | [nombre del JMX] |
| **HU afectada** | [HU-0X] |
| **Trazabilidad** | [ruta al .jmx y .jtl] |
| **SLO violado** | [métrica y umbral] |
| **Severidad** | Crítica / Alta / Media / Baja |
| **Prioridad** | P1 / P2 / P3 |
| **Fecha detección** | AAAA-MM-DD |
| **Detectado por** | [Nombre] |
| **Fecha análisis** | AAAA-MM-DD |
| **Fecha validación** | AAAA-MM-DD |
| **Validado por** | [Nombre] |
| **Fecha cierre** | AAAA-MM-DD |
| **Estado** | 🔴 Abierto / 🟡 En análisis / ✅ Cerrado |
| **Evidencia** | [ruta a screenshot o reporte] |

### Ciclo de vida
**1. Identificación:** [qué ocurre y cuándo se detectó]
**2. Clasificación:** [tipo, severidad, impacto]
**3. Seguimiento y validación:** [análisis, causa raíz, evidencia]
**4. Recomendaciones:** [acciones correctivas]
**5. Cierre:** [resultado final — cerrado o pendiente con justificación]
```
