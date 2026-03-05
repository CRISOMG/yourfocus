# Feature Template: Single Source of Truth

> Plantilla estratégica basada en el [Paradigma Integrado de Planificación y Diseño](./index.md).
> Cada archivo generado con esta plantilla actúa como **contrato vivo** entre el rol de Product Manager (el "qué" y "por qué") y el rol de Engineer (el "cómo" y "cuánto cuesta").

---

## Instrucciones de Uso

1. **Copiar** esta plantilla para cada nueva feature o módulo.
2. **Nombrar** el archivo: `feature_[nombre-en-kebab-case].md`
3. **Completar** progresivamente: no es necesario llenar todo de una vez. Las secciones pueden estar en estado `Pendiente`.
4. **Iterar**: el documento evoluciona con el feature, desde Draft hasta Approved.

---

## Metadata

| Campo                    | Valor                                                           |
| ------------------------ | --------------------------------------------------------------- |
| **Feature / Módulo**     | `[Nombre descriptivo]`                                          |
| **Estado**               | `Draft` / `In-Review` / `Approved` / `Tech-Debt`                |
| **Owner**                | `[Nombre]` (TPM / TPE)                                          |
| **Dominio (DDD)**        | `[Contexto Delimitado, e.g.: Gestión de Tiempo, IA Journaling]` |
| **Fecha de creación**    | `YYYY-MM-DD`                                                    |
| **Última actualización** | `YYYY-MM-DD`                                                    |
| **Sprint / Ciclo**       | `[Referencia al sprint o ciclo de trabajo]`                     |

---

## 1. Capa de Descubrimiento (Contexto de Negocio) — TPM

> **Propósito:** Alineación con el Lean Canvas y el valor para el usuario.

### User Story

```
Como [rol del usuario],
quiero [acción que desea realizar],
para [beneficio o valor que obtiene].
```

### Problema a Resolver

<!-- Breve descripción del dolor o necesidad que esta feature elimina o satisface -->

### KPI / Métricas de Éxito

<!-- ¿Cómo sabemos que esto funcionó? -->

| Métrica                               | Valor objetivo | Método de medición        |
| ------------------------------------- | -------------- | ------------------------- |
| `[e.g. Reducción de procrastinación]` | `[e.g. -10%]`  | `[e.g. Analytics de uso]` |

### Contexto Adicional

<!-- Insights de entrevistas, datos de uso, Lean Canvas, etc. -->

---

## 2. Capa de Definición (Requerimientos) — Bridge TPM ↔ TPE

> **Propósito:** Reglas de negocio claras y límites del sistema.

### Requerimientos Funcionales (RF)

| ID    | Descripción                     | Prioridad           |
| ----- | ------------------------------- | ------------------- |
| RF-01 | El sistema debe...              | Alta / Media / Baja |
| RF-02 | Si el usuario hace X, sucede Y. |                     |
| RF-03 |                                 |                     |

### Requerimientos No Funcionales (RNF)

| Categoría          | Descripción                               | Criterio |
| ------------------ | ----------------------------------------- | -------- |
| **Disponibilidad** | `[e.g. Debe funcionar offline]`           |          |
| **Performance**    | `[e.g. Tiempo de respuesta < 100ms]`      |          |
| **Seguridad**      | `[e.g. Encriptación E2E para Journaling]` |          |
| **Escalabilidad**  | `[e.g. Soportar N usuarios concurrentes]` |          |
| **Accesibilidad**  | `[e.g. WCAG 2.1 AA]`                      |          |

### Criterios de Aceptación

<!-- Lista de condiciones que deben cumplirse para considerar esta feature como "completa" -->

- [ ] `[Criterio 1]`
- [ ] `[Criterio 2]`
- [ ] `[Criterio 3]`

---

## 3. Capa de Especificación (BDD & Comportamiento) — TPE

> **Propósito:** Convertir los requerimientos en escenarios testeables.

### Escenarios BDD (Gherkin)

```gherkin
Feature: [Título de la funcionalidad]

  Scenario: [Caso de éxito / Happy Path]
    Given [Contexto inicial]
    When [Acción del usuario]
    Then [Resultado esperado]

  Scenario: [Caso de error / Edge Case]
    Given [Contexto inicial]
    When [Acción errónea o inesperada]
    Then [Comportamiento del sistema ante el error]

  Scenario: [Caso borde / Boundary]
    Given [Condición límite]
    When [Acción en el límite]
    Then [Resultado esperado en el borde]
```

### Flujo de Interacción

<!-- Diagrama o descripción del flujo principal del usuario -->

```
[Paso 1] → [Paso 2] → [Decisión?]
                           ├── Sí → [Paso 3a]
                           └── No → [Paso 3b]
```

---

## 4. Capa de Ingeniería y Ciencias de la Computación — TPE

> **Propósito:** Criterio técnico senior para evitar deuda técnica.

### Arquitectura de Datos

<!-- ¿Qué estructuras de datos son las más adecuadas? -->

| Estructura        | Justificación             | Alternativa descartada      |
| ----------------- | ------------------------- | --------------------------- |
| `[e.g. Hash Map]` | `[Acceso O(1) necesario]` | `[Lista: O(n) inaceptable]` |

### Análisis de Complejidad

| Aspecto                  | Valor                          |
| ------------------------ | ------------------------------ |
| **Algoritmo propuesto**  | `[Nombre / Descripción breve]` |
| **Complejidad Temporal** | `O(?)`                         |
| **Complejidad Espacial** | `O(?)`                         |
| **Justificación**        | `[Por qué este y no otro]`     |

### Trade-offs y Decisiones Técnicas

<!-- Documentar decisiones de diseño con su justificación -->

| Decisión    | Alternativa | Razón de elección                       |
| ----------- | ----------- | --------------------------------------- |
| `[Elegí X]` | `[Sobre Y]` | `[Priorizamos lectura sobre escritura]` |

### R&D / Spikes

<!-- Tareas de investigación necesarias antes de especificar -->

- [ ] `[Spike 1: e.g. ¿Soporta la API de terceros este volumen?]` — Duración estimada: `[1-2 días]`
- [ ] `[Spike 2: e.g. ¿Qué librería es más adecuada para X?]` — Duración estimada: `[N días]`

---

## 5. Gestión de Deuda e Incertidumbre

> **Propósito:** Documentar lo que no sabemos hoy para que no se convierta en deuda técnica mañana.

### Preguntas Abiertas (Incertidumbre)

<!-- Preguntas que solo se pueden responder con detalles de implementación -->

| #   | Pregunta                                                | Estado                   | Respuesta |
| --- | ------------------------------------------------------- | ------------------------ | --------- |
| 1   | `[e.g. ¿Cómo escalará este endpoint con 10k usuarios?]` | `Pendiente` / `Resuelto` |           |
| 2   |                                                         |                          |           |

### Supuestos (Assumptions Log)

<!-- Si avanzamos sin respuesta, documentar el supuesto explícitamente -->

| #   | Supuesto                                  | Impacto si es incorrecto                  | Fecha        |
| --- | ----------------------------------------- | ----------------------------------------- | ------------ |
| 1   | `[e.g. El procesamiento será sincrónico]` | `[Deuda de arquitectura: migrar a async]` | `YYYY-MM-DD` |
| 2   |                                           |                                           |              |

### Deuda Técnica Identificada

<!-- Deuda conocida y aceptada conscientemente -->

- [ ] `[e.g. Refactorizar módulo de notificaciones — actualmente es un workaround]`
- [ ] `[e.g. Test coverage insuficiente en módulo X]`

### Matriz de Riesgos

| Riesgo          | Probabilidad        | Impacto             | Severidad        | Plan de Mitigación |
| --------------- | ------------------- | ------------------- | ---------------- | ------------------ |
| `[Descripción]` | Alta / Media / Baja | Alto / Medio / Bajo | `Prob × Impacto` | `[Acción]`         |

---

## 6. Notas y Evolución

<!-- Espacio libre para notas de progreso, decisiones tomadas en revisiones, links a PRs, etc. -->

| Fecha        | Nota                            |
| ------------ | ------------------------------- |
| `YYYY-MM-DD` | `[Nota de progreso o decisión]` |

---

> **Recuerda:** Este documento es un **contrato vivo**. Debe actualizarse cada vez que cambie el entendimiento del feature, se resuelva una pregunta abierta, o se identifique nueva deuda técnica.
