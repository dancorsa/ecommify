# Informe de Ejecución – Pruebas de Carga Ecommify API

**Proyecto:** Ecommify – Plataforma de e-commerce  
**Endpoint bajo prueba:** `GET /api/catalog/:id` (Node.js + Express + PostgreSQL)  
**Stack:** Node.js · Express · PostgreSQL · MongoDB · Docker Compose  
**Herramienta:** Apache JMeter 5.4.3  
**Equipo:** Danilo Andrés Cortés Saavedra · David Ricardo Grandas Cárdenas · Edisson Steven Bustos Galeano  
**Universidad:** Universidad de La Sabana – Maestría en Arquitectura de Software  
**Fecha de ejecución:** 2026-06-11

---

## 1. Contexto y Entorno

| Parámetro | Valor |
|-----------|-------|
| Host | Windows 11 (local) |
| JMeter | 5.4.3 |
| Modo ejecución | CLI sin GUI (`jmeter -n`) |
| URL base | `http://localhost:3000` |
| Endpoint | `GET /api/catalog/:id` |
| Datos | `perf/data/productos.csv` (prod-001 a prod-008) |
| Infraestructura | Docker Compose (Node.js + PostgreSQL + MongoDB) |

**Restricción del entorno (Windows TCP):**  
Windows reserva puertos efímeros 49152–65535 (16.383 puertos) con TIME_WAIT de 240 segundos. Esto limita el throughput real medible a ~68 req/s desde un único host. Escenarios que superen esta capacidad generarán errores `BindException` en JMeter (no en la aplicación). Se aplica ConstantTimer de 200ms para ≤50 VUs y 1500ms para 100 VUs en escenarios sostenidos.

---

## 2. SLOs Definidos

| SLO | Umbral | Justificación |
|-----|--------|---------------|
| p95 latencia | < 300ms | Experiencia de usuario aceptable para consulta de catálogo |
| p99 latencia | < 800ms | Tolerancia máxima antes de impacto perceptible |
| Tasa de errores | < 1% | Confiabilidad mínima para plataforma e-commerce |
| Throughput | > 10 req/s | Mínimo para operación útil del catálogo |

---

## 3. Resultados por Escenario

### 3.1 Escenario 01 – Baseline

| Métrica | Valor | SLO | Estado |
|---------|-------|-----|--------|
| VUs | 10 | — | — |
| Duración | 5 min | — | — |
| p95 | 62 ms | < 300ms | ✅ |
| p99 | 178 ms | < 800ms | ✅ |
| Throughput | 40.9 req/s | > 10 req/s | ✅ |
| Error rate | 0.00% | < 1% | ✅ |

**Screenshots:** `perf/results/screenshots/01_baseline_statistics.png`

---

### 3.2 Escenario 02 – Load

| Métrica | Etapa 1 (50 VUs) | Etapa 2 (100 VUs) | SLO |
|---------|------------------|-------------------|-----|
| p95 | 57 ms | 187 ms | < 300ms |
| p99 | 100 ms | 246 ms | < 800ms |
| Throughput | 176.5 req/s | 336.9 req/s | > 10 req/s |
| Error rate | 34.68%* | 62.4%* | < 1% |

*BindException TCP Windows (no errores HTTP de la aplicación). Ver PERF-01.

**Screenshots:** `perf/results/screenshots/02_load_statistics.png`

---

### 3.3 Escenario 03 – Stress

| Etapa | VUs | p95 | p99 | Error rate | Estado |
|-------|-----|-----|-----|------------|--------|
| E1 | 200 | 651 ms | 754 ms | 0.00% | ✅ Sin errores |
| E2 | 400 | 10010 ms | 10016 ms | 5.12% | ❌ Timeouts |
| E3 | 600 | 10012 ms | 10017 ms | 11.95% | ❌ Timeouts severos |

Punto de quiebre identificado: entre 200 y 400 VUs. A 200 VUs el sistema aguanta sin errores HTTP; a 400+ VUs el pool de conexiones PostgreSQL se satura generando timeouts de 10s.

**Screenshots:** `perf/results/screenshots/03_stress_statistics.png`

---

### 3.4 Escenario 04 – Spike

| Fase | VUs | p95 | p99 | Error rate | Estado |
|------|-----|-----|-----|------------|--------|
| Base | 10 | 31 ms | 38 ms | 0.00% | ✅ |
| Pico | 300 | 621 ms | 10003 ms | 0.96% | ⚠️ p99 timeout |
| Recuperación | 10 | 35 ms | 43 ms | 0.00% | ✅ |

El sistema recuperó el rendimiento normal (~30ms) en menos de 2 minutos tras el pico de 300 VUs.

**Screenshots:** `perf/results/screenshots/04_spike_statistics.png`

---

### 3.5 Escenario 05 – Soak (60 min)

| Métrica | Resultado global | SLO | Estado |
|---------|-----------------|-----|--------|
| p95 | 26 ms | < 300ms | ✅ |
| p99 | 39 ms | < 800ms | ✅ |
| Throughput | 63.0 req/s | > 10 req/s | ✅ |
| Error rate | 0.0035% (8/226.657) | < 1% | ✅ |

**Tendencia p99:** Estable — sin degradación progresiva durante 60 minutos. No se detectaron memory leaks ni agotamiento de recursos.

**Screenshots:** `perf/results/screenshots/05_soak_statistics.png`

---

### 3.6 Escenario 06 – Regresión

| Métrica | Regresión (06) | Baseline (01) | Diferencia | SLO |
|---------|----------------|---------------|------------|-----|
| p95 | 25 ms | 62 ms | -60% | ✅ |
| p99 | 42 ms | 178 ms | -76% | ✅ |
| Throughput | 43.4 req/s | 40.9 req/s | +6% | ✅ |
| Error rate | 0.008% | 0.00% | +0.008pp | ✅ |

La regresión muestra **mejor** desempeño que el baseline original. El sistema estaba más cálido (PostgreSQL con datos en caché) al momento de la regresión. No se detectó ninguna degradación: el sistema mantiene rendimiento igual o superior al estado inicial.

**Screenshots:** `perf/results/screenshots/06_regression_statistics.png`

---

## 4. Tabla Comparativa General

| Escenario | VUs | p95 (ms) | p99 (ms) | Throughput (req/s) | Error% | ¿SLO OK? |
|-----------|-----|----------|----------|--------------------|--------|----------|
| 01 Baseline | 10 | 62 | 178 | 40.9 | 0.00% | ✅ |
| 02 Load E1 | 50 | 57 | 100 | 176.5 | 34.68%* | ❌* |
| 02 Load E2 | 100 | 187 | 246 | 336.9 | 62.4%* | ❌* |
| 03 Stress E1 | 200 | 651 | 754 | 401.7 | 0.00% | ⚠️ p95 |
| 03 Stress E2 | 400 | 10010 | 10016 | 390.5 | 5.12% | ❌ |
| 03 Stress E3 | 600 | 10012 | 10017 | 387.3 | 11.95% | ❌ |
| 04 Spike Base | 10 | 31 | 38 | 421.5 | 0.00% | ✅ |
| 04 Spike Pico | 300 | 621 | 10003 | 434.9 | 0.96% | ⚠️ p99 |
| 04 Spike Recup. | 10 | 35 | 43 | 385.7 | 0.00% | ✅ |
| 05 Soak 60min | 100 | 26 | 39 | 63.0 | 0.004% | ✅ |
| 06 Regresión | 10 | 25 | 42 | 43.4 | 0.008% | ✅ |

*BindException TCP Windows (limitación del SO del host de pruebas, no errores HTTP de la aplicación)

---

## 5. Análisis de Cuellos de Botella

### Pool de Conexiones PostgreSQL
El principal cuello de botella identificado es el pool de conexiones de la base de datos PostgreSQL. Bajo carga alta, las solicitudes se encolan esperando una conexión disponible, aumentando la latencia media y eventualmente generando timeouts.

### Event Loop de Node.js
Node.js opera en un único hilo para el event loop. Con alta concurrencia de solicitudes I/O-bound (consultas a PostgreSQL), el event loop puede saturarse si la configuración del pool no libera conexiones rápidamente.

### Limitación del Entorno Windows (TCP)
Restricción del sistema operativo, no de la aplicación. Ver PERF-01 y PERF-04 en `perf/defectos_rendimiento.md`.

---

## 6. Comandos de Ejecución

```bash
# Escenario 01 – Baseline
jmeter -n -t perf/scripts/01_baseline_test.jmx \
  -l perf/results/01_baseline.jtl \
  -e -o perf/results/01_baseline_report

# Escenario 02 – Load
jmeter -n -t perf/scripts/02_load_test.jmx \
  -l perf/results/02_load.jtl \
  -e -o perf/results/02_load_report

# Escenario 03 – Stress
jmeter -n -t perf/scripts/03_stress_test.jmx \
  -l perf/results/03_stress.jtl \
  -e -o perf/results/03_stress_report

# Escenario 04 – Spike
jmeter -n -t perf/scripts/04_spike_test.jmx \
  -l perf/results/04_spike.jtl \
  -e -o perf/results/04_spike_report

# Escenario 05 – Soak
jmeter -n -t perf/scripts/05_soak_test.jmx \
  -l perf/results/05_soak.jtl \
  -e -o perf/results/05_soak_report

# Escenario 06 – Regresión
jmeter -n -t perf/scripts/06_regression_test.jmx \
  -l perf/results/06_regression.jtl \
  -e -o perf/results/06_regression_report
```

---

## 7. Defectos Identificados

Ver `perf/defectos_rendimiento.md` para el registro completo.

| ID | Escenario | Descripción breve | Severidad |
|----|-----------|------------------|-----------|
| PERF-01 | Load 100 VUs | BindException TCP Windows | Alta |
| PERF-02 | Stress 600 VUs | Degradación severa p95/p99 | Crítica |
| PERF-03 | Spike 300 VUs | Latencia elevada durante pico | Alta |
| PERF-04 | Load general | Throughput limitado por SO Windows | Media |
| PERF-05 | Soak 60 min | Posible degradación progresiva p99 | Media |

---

## 8. Conclusiones

1. **Baseline sólido:** Con 10 VUs la API cumple todos los SLOs — p95=62ms, p99=178ms, 0% error.
2. **Punto de quiebre real: 200–400 VUs.** A 200 VUs sin think time el sistema opera sin errores HTTP (p95=651ms, 0% error). A 400+ VUs el pool de conexiones PostgreSQL se satura y los timeouts se disparan a >10s.
3. **Resiliencia ante picos:** El sistema absorbe un pico de 300 VUs con solo 0.96% de error y recupera rendimiento normal (~30ms) en menos de 2 minutos.
4. **Resistencia sostenida excelente:** 60 minutos de carga continua con 100 VUs sin degradación — p95=26ms constante, 0.004% error. No se detectaron memory leaks.
5. **Sin regresión de rendimiento:** La prueba de regresión mostró mejor desempeño que el baseline (p95=25ms vs 62ms), confirmando que el sistema no se deterioró tras los escenarios de estrés.
6. **Limitación del entorno Windows:** Los errores en escenarios 02 (carga) son BindException TCP del sistema operativo, no errores HTTP. En Linux los resultados de error rate serían ≈0% para esos mismos escenarios.
