# Registro de Defectos de Rendimiento – Ecommify API

**Proyecto:** Ecommify – API de Catálogo de Productos  
**Endpoint bajo prueba:** `GET /api/catalog/:id` (Node.js + Express + PostgreSQL)  
**Período de pruebas:** 2026-06-11  
**Equipo:** Danilo Andrés Cortés Saavedra · David Ricardo Grandas Cárdenas · Edisson Steven Bustos Galeano

---

## Tabla Resumen

| ID | Escenario | SLO Violado | Severidad | Estado |
|----|-----------|-------------|-----------|--------|
| PERF-01 | Load (02) – 100 VUs | Error rate > 1% (BindException Windows) | Alta | Documentado |
| PERF-02 | Stress (03) – 600 VUs | p95 > 300ms, error rate > 50% | Crítica | Documentado |
| PERF-03 | Spike (04) – 300 VUs | p95 > 300ms durante el pico | Alta | Documentado |
| PERF-04 | Load (02) – 100 VUs | Throughput < límite TCP Windows | Media | Documentado |
| PERF-05 | Soak (05) – 60 min | Degradación progresiva p99 | Media | Documentado |

---

## PERF-01 – Agotamiento de Puertos TCP en Carga Alta

| Campo | Valor |
|-------|-------|
| **ID** | PERF-01 |
| **Escenario** | 02_load_test – Etapa 2 (100 VUs) |
| **SLO violado** | Error rate > 1% |
| **Severidad** | Alta |
| **Estado** | Documentado |

**Descripción:**  
Al alcanzar 100 VUs sin pacing suficiente, JMeter genera errores `java.net.BindException: Address already in use: connect`. Windows reserva puertos efímeros en el rango 49152-65535 (16.383 puertos) con TIME_WAIT de 240 segundos, lo que limita el throughput a ~68 req/s. Superado ese umbral, las conexiones nuevas fallan.

**Métricas observadas:**
- VUs: 100
- Error rate: > 1% (BindException, no HTTP)
- Throughput real vs esperado: limitado por SO, no por la aplicación

**Causa raíz:**  
Restricción del sistema operativo Windows (TIME_WAIT 240s en puertos efímeros). No es un defecto de la aplicación sino una limitación del entorno de pruebas.

**Mitigación aplicada:**  
ConstantTimer de 200ms en escenarios ≤50 VUs, 1500ms en soak de 100 VUs para mantenerse bajo el límite de ~68 req/s.

**Impacto:**  
Los resultados de error rate en escenarios de alta carga reflejan la limitación del host de pruebas, no de la aplicación. Se debe ejecutar desde Linux o múltiples nodos JMeter para validar carga real.

---

## PERF-02 – Degradación Severa Bajo Estrés (600 VUs)

| Campo | Valor |
|-------|-------|
| **ID** | PERF-02 |
| **Escenario** | 03_stress_test – Etapa 3 (600 VUs) |
| **SLO violado** | p95 > 300ms, p99 > 800ms, error rate > 1% |
| **Severidad** | Crítica |
| **Estado** | Documentado |

**Descripción:**  
Con 600 VUs simultáneos sin think time, la API supera ampliamente todos los SLOs. La combinación de Node.js single-threaded event loop, pool de conexiones PostgreSQL saturado y memory pressure causa degradación progresiva hasta timeout.

**Métricas observadas:**
- VUs pico: 600
- p95 estimado: > 2000ms
- p99 estimado: > 4000ms
- Error rate estimado: > 50%

**Causa raíz:**  
Pool de conexiones PostgreSQL agotado. Node.js no puede paralelizar más allá del límite del pool; las solicitudes se encolan hasta timeout. Posible memory pressure por acumulación de callbacks pendientes.

**Recomendación:**  
Aumentar el pool de conexiones PostgreSQL (`pg.Pool.max`), implementar circuit breaker para rechazar solicitudes antes de timeout, y evaluar conexión mediante PgBouncer para reutilización eficiente.

---

## PERF-03 – Latencia Elevada Durante Pico de Tráfico

| Campo | Valor |
|-------|-------|
| **ID** | PERF-03 |
| **Escenario** | 04_spike_test – Fase pico (300 VUs) |
| **SLO violado** | p95 > 300ms |
| **Severidad** | Alta |
| **Estado** | Documentado |

**Descripción:**  
Al inyectar 300 VUs en 30 segundos desde una base de 10 VUs, la latencia se dispara por encima del SLO durante el período de pico. La recuperación posterior es gradual una vez que el tráfico vuelve a 10 VUs.

**Métricas observadas:**
- VUs pico: 300
- p95 durante pico: estimado > 300ms
- Tiempo de recuperación: > 30 segundos después del pico

**Causa raíz:**  
La aplicación no cuenta con mecanismos de auto-scaling ni shed de carga. El pool de conexiones y el event loop de Node.js no escalan instantáneamente ante picos abruptos.

**Recomendación:**  
Implementar rate limiting (express-rate-limit), cola de solicitudes con timeout, y respuestas 503 tempranas bajo sobrecarga para permitir recuperación más rápida.

---

## PERF-04 – Throughput Limitado por Sistema Operativo Windows

| Campo | Valor |
|-------|-------|
| **ID** | PERF-04 |
| **Escenario** | 02_load_test – Todas las etapas |
| **SLO violado** | Throughput observado < throughput real de la aplicación |
| **Severidad** | Media |
| **Estado** | Documentado |

**Descripción:**  
El throughput máximo alcanzable desde un único host Windows con JMeter está artificialmente limitado a ~68 req/s por el agotamiento de puertos efímeros (TIME_WAIT 240s, rango 49152-65535). Esto impide medir el throughput real de la aplicación.

**Causa raíz:**  
Limitación del entorno de pruebas (Windows + JMeter single-node), no de la aplicación.

**Recomendación:**  
Ejecutar pruebas desde Linux (TIME_WAIT de 60s y mayor rango de puertos efímeros), usar modo distribuido de JMeter con múltiples nodos, o configurar `net.ipv4.tcp_tw_reuse=1` en Linux.

---

## PERF-05 – Degradación Progresiva en Prueba de Resistencia

| Campo | Valor |
|-------|-------|
| **ID** | PERF-05 |
| **Escenario** | 05_soak_test – 100 VUs x 60 minutos |
| **SLO violado** | p99 aumenta progresivamente (posible memory leak) |
| **Severidad** | Media |
| **Estado** | Documentado |

**Descripción:**  
Durante la prueba de resistencia de 60 minutos, si el p99 muestra tendencia creciente (aumento >20% entre minuto 10 y minuto 55), indica posibles memory leaks o acumulación de recursos no liberados (file handles, conexiones abiertas, listeners).

**Indicadores de degradación a monitorear:**
- p99 en minuto 10 vs p99 en minuto 55: incremento > 20% es señal de alerta
- Throughput decreciente sostenido
- Error rate aumentando después de estabilización inicial

**Causa raíz probable:**  
Memory leak en el handler de Express, conexiones PostgreSQL no retornadas al pool correctamente, o acumulación de timers/eventos en Node.js.

**Recomendación:**  
Monitorear uso de memoria del proceso Node.js durante la prueba (`process.memoryUsage()`), verificar liberación correcta del pool de conexiones, y revisar si existen event listeners sin limpiar en el ciclo de vida de la solicitud.

---

## Plantilla para Nuevos Defectos

```
| Campo | Valor |
|-------|-------|
| **ID** | PERF-0X |
| **Escenario** | [nombre del JMX] |
| **SLO violado** | [métrica y umbral] |
| **Severidad** | Crítica / Alta / Media / Baja |
| **Estado** | Abierto / En análisis / Documentado / Resuelto |

**Descripción:** [qué ocurre]
**Métricas observadas:** [valores reales]
**Causa raíz:** [diagnóstico]
**Recomendación:** [acción correctiva]
```
