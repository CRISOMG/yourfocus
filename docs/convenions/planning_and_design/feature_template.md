# Feature Template: Single Source of Truth

> Plantilla estratégica basada en el [Paradigma Integrado de Planificación y Diseño](./index.md).
> Cada archivo generado con esta plantilla actúa como **contrato vivo** entre el rol de Product Manager (el "qué" y "por qué") y el rol de Engineer (el "cómo" y "cuánto cuesta").

---

## Instrucciones de Uso

1. **Copiar** esta plantilla para cada nueva feature o módulo.
2. **Nombrar** el archivo: `feature_[nombre-en-kebab-case].md`
3. **Completar** progresivamente: no es necesario llenar todo de una vez. Las secciones pueden estar en estado `Pendiente`.
4. **Iterar**: el documento evoluciona con el feature, desde Draft hasta Approved.
5. **Vincular Lean Canvas**: si esta feature tiene impacto en el negocio, referenciar su conexión con el [Lean Canvas](../../business_model_canvas/lean_canvas.md) principal en la Capa 1.

---

## Metadata

| Campo                    | Valor                                                           |
| ------------------------ | --------------------------------------------------------------- |
| **Feature / Módulo**     | `[Nombre descriptivo]`                                          |
| **Estado**               | `Draft` / `In-Review` / `Approved` / `Tech-Debt`                |
| **Owner**                | `[Nombre]` (TPM / TPE)                                          |
| **Dominio (DDD)**        | `[Contexto Delimitado, e.g.: Gestión de Tiempo, IA Journaling]` |
| **Módulo (Bounded Ctx)** | `[Módulo al que pertenece esta feature, según DDD]`             |
| **Fecha de creación**    | `YYYY-MM-DD`                                                    |
| **Última actualización** | `YYYY-MM-DD`                                                    |
| **Sprint / Ciclo**       | `[Referencia al sprint o ciclo de trabajo]`                     |

---

## 1. Capa de Descubrimiento (Contexto de Negocio) — TPM

> **Propósito:** Alineación con el Lean Canvas y el valor para el usuario.
> _Ref: [Paradigma §2 Capa A](./index.md#capa-a-descubrimiento--enfoque-en-el-problema-tpm) + [§9 Features como Mini-Productos](./index.md#9-features-como-mini-productos-lean-canvas-por-feature)_

### User Story

```
Como [rol del usuario],
quiero [acción que desea realizar],
para [beneficio o valor que obtiene].
```

### Problema a Resolver

<!-- Breve descripción del dolor o necesidad que esta feature elimina o satisface -->

### KPI / Métricas de Éxito

<!-- ¿Cómo sabemos que esto funcionó? Incluir métricas de bienestar si aplica (ver §7 del paradigma) -->

| Métrica                               | Valor objetivo | Método de medición        |
| ------------------------------------- | -------------- | ------------------------- |
| `[e.g. Reducción de procrastinación]` | `[e.g. -10%]`  | `[e.g. Analytics de uso]` |

### Contexto Adicional

<!-- Insights de entrevistas, datos de uso, Lean Canvas, etc. -->

### Mini Lean Canvas (Opcional)

<!-- Si esta feature tiene suficiente complejidad de negocio, completar un mini Lean Canvas -->

| Sección               | Descripción                                         |
| --------------------- | --------------------------------------------------- |
| **Problema**          | `[Top 3 dolores que esta feature resuelve]`         |
| **Segmento**          | `[¿Quién se beneficia más de esta feature?]`        |
| **UVP**               | `[Propuesta de valor única de esta feature]`        |
| **Solución**          | `[Componentes clave]`                               |
| **Métricas Clave**    | `[North Star Metric de esta feature]`               |
| **Ventaja Injusta**   | `[¿Por qué es difícil de copiar?]`                  |
| **Vínculo al Canvas** | `[Qué secciones del Lean Canvas principal impacta]` |

---

## 2. Capa de Definición (Requerimientos) — Bridge TPM ↔ TPE

> **Propósito:** Reglas de negocio claras y límites del sistema.
> _Ref: [Paradigma §2 Capa B](./index.md#capa-b-definición--enfoque-en-la-solución-bridge-tpm--tpe)_

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

<!-- Lista de condiciones que deben cumplirse para considerar esta feature como "completa".
     Estos criterios serán la base directa de los escenarios BDD en la Capa 3. -->

- [ ] `[Criterio 1]`
- [ ] `[Criterio 2]`
- [ ] `[Criterio 3]`

---

## 3. Capa de Especificación (BDD & Comportamiento) — TPE

> **Propósito:** Convertir los requerimientos en escenarios testeables. Los escenarios BDD facilitan la transición directa a TDD.
> _Ref: [Paradigma §3 Metodologías de Especificación](./index.md#3-metodologías-de-especificación--bdd-vdm-y-featuremodule-structure)_

### Escenarios BDD (Gherkin)

<!-- Pipeline: Criterios de Aceptación (Capa 2) → Escenarios BDD (Capa 3) → Tests automatizados (TDD)
     Cubrir al menos: Happy Path, Error Case y Boundary Case -->

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

### Especificación Formal (Opcional — VDM)

<!-- Para componentes de alta criticidad, documentar pre/post condiciones formales.
     Ver: Paradigma §3.2 Vienna Development Method -->

| Operación       | Pre-condición              | Post-condición                 | Invariante         |
| --------------- | -------------------------- | ------------------------------ | ------------------ |
| `[Operación 1]` | `[Estado requerido antes]` | `[Estado garantizado después]` | `[Siempre verdad]` |

---

## 4. Capa de Ingeniería y Ciencias de la Computación — TPE

> **Propósito:** Criterio técnico senior para evitar deuda técnica.
> _Ref: [Paradigma §4 Criterio de Ingeniería](./index.md#4-criterio-de-ingeniería-de-software-y-ciencias-de-la-computación)_

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

<!-- Tareas de investigación necesarias antes de especificar.
     Si hay incógnitas técnicas, NO escribir la especificación aún. Crear un Spike acotado (1-2 días). -->

- [ ] `[Spike 1: e.g. ¿Soporta la API de terceros este volumen?]` — Duración estimada: `[1-2 días]`
- [ ] `[Spike 2: e.g. ¿Qué librería es más adecuada para X?]` — Duración estimada: `[N días]`

---

## 5. Gestión de Deuda e Incertidumbre

> **Propósito:** Documentar lo que no sabemos hoy para que no se convierta en deuda técnica mañana.
> _Ref: [Paradigma §5 Gestión de Incertidumbre](./index.md#5-gestión-de-incertidumbre-y-deuda-técnica)_

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

## 6. Impacto en Bienestar y Sostenibilidad

> **Propósito:** Evaluar el costo cognitivo de esta feature para el usuario y para el desarrollador.
> _Ref: [Paradigma §7 Medición del Agotamiento](./index.md#7-medición-del-agotamiento-y-bienestar)_

### Evaluación Cognitiva del Usuario

<!-- ¿Esta feature reduce o aumenta la carga cognitiva del usuario? Basado en las 3 dimensiones del Maslach Burnout Inventory -->

| Dimensión                         | Impacto esperado              | Mitigación                      |
| --------------------------------- | ----------------------------- | ------------------------------- |
| **Agotamiento emocional**         | `[Reduce / Neutro / Aumenta]` | `[e.g. UI simplificada]`        |
| **Despersonalización**            | `[Reduce / Neutro / Aumenta]` | `[e.g. Feedback personalizado]` |
| **Falta de realización personal** | `[Reduce / Neutro / Aumenta]` | `[e.g. Progreso visible]`       |

### Atomicidad (Pomodoro 25 min)

<!-- ¿Las interacciones del usuario con esta feature pueden completarse dentro de un intervalo atómico de 25 min? -->

- [ ] Las acciones principales son completables en ≤ 25 min
- [ ] No requiere sesiones de configuración largas
- [ ] El feedback de progreso es inmediato

---

## 7. Notas y Evolución

<!-- Espacio libre para notas de progreso, decisiones tomadas en revisiones, links a PRs, etc. -->

| Fecha        | Nota                            |
| ------------ | ------------------------------- |
| `YYYY-MM-DD` | `[Nota de progreso o decisión]` |

---

> **Recuerda:** Este documento es un **contrato vivo**. Debe actualizarse cada vez que cambie el entendimiento del feature, se resuelva una pregunta abierta, o se identifique nueva deuda técnica.
