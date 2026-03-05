# Paradigma Integrado de Planificación y Diseño de Software

> Un marco de trabajo para abordar el rol dual de **Technical Product Manager (TPM)** y **Technical Product Engineer (TPE)**, integrando principios de Agile, Lean, Scrum, Six Sigma y Domain-Driven Design.

---

## 1. Visión General

Este paradigma propone una estructura de capas progresivas que conecta la **visión de negocio** con la **ejecución técnica**, asegurando que la transición entre "qué construir" y "cómo construirlo" sea trazable, documentada y de alta calidad.

### Pilares Fundamentales

| Pilar                    | Rol en el paradigma     | Aporte clave                                                      |
| ------------------------ | ----------------------- | ----------------------------------------------------------------- |
| **Manifiesto Agile**     | Base filosófica         | Flexibilidad, adaptación al cambio, entrega iterativa de valor    |
| **Lean**                 | Filosofía de eficiencia | Maximizar valor, eliminar desperdicio, optimización continua      |
| **Scrum**                | Marco operativo         | Roles, eventos y artefactos concretos para gestionar complejidad  |
| **Six Sigma**            | Calidad de proceso      | Reducir variabilidad, herramientas estadísticas, mejora continua  |
| **Domain-Driven Design** | Lenguaje y arquitectura | Contextos delimitados, lenguaje ubicuo, alineación negocio-código |

---

## 2. Arquitectura de Capas

El paradigma se estructura en capas secuenciales que van de lo abstracto a lo concreto. Cada capa tiene un propósito, un responsable implícito y artefactos de salida claros.

### Capa A: Descubrimiento — _Enfoque en el Problema_ (TPM)

**Objetivo:** Entender y articular el _dolor_ del usuario y el valor de negocio.

- **Historias de Usuario:** Formato estándar `Como [rol], quiero [acción], para [valor]`.
- **Lean Canvas / Entrevistas:** Extracción del problema real del usuario.
- **KPIs de Éxito:** Métricas que validen si la solución funciona.

**Artefacto de salida:** Lista de intenciones de alto nivel alineadas con el valor de negocio.

---

### Capa B: Definición — _Enfoque en la Solución_ (Bridge TPM ↔ TPE)

**Objetivo:** Traducir las historias de usuario en reglas de negocio y restricciones del sistema.

- **Requerimientos Funcionales (RF):** Qué debe hacer el sistema.
  - _Ejemplo:_ "El sistema debe calcular el IVA automáticamente."
- **Requerimientos No Funcionales (RNF):** Cómo debe comportarse el sistema.
  - _Ejemplo:_ "El cálculo debe realizarse en menos de 200ms."
- **Criterios de Aceptación:** Base para BDD y validación.

**Artefacto de salida:** Documento de requerimientos con criterios de aceptación verificables.

> [!IMPORTANT]
> Es en esta capa donde se analiza la **viabilidad técnica** y se define la **estrategia técnica**, considerando eficiencia y posible deuda técnica.

---

### Capa C: Especificación y Comportamiento — _Enfoque en la Implementación_ (TPE)

**Objetivo:** Convertir los requerimientos en especificaciones testeables y diseño técnico.

- **BDD con Gherkin:** Escenarios `Given / When / Then` que convierten el requerimiento en algo _testeable_.
- **Feature-Based Structure:** Documentación y código organizados por funcionalidad, no por capas técnicas.
- **Decisiones de Arquitectura:** Selección de algoritmos, estructuras de datos y patrones.

**Artefacto de salida:** Especificaciones BDD + documentación de decisiones técnicas.

---

## 3. Criterio de Ingeniería de Software y Ciencias de la Computación

La aplicación de criterios técnicos avanzados ocurre **de forma progresiva** a través de las capas:

| Situación               | Capa de Decisión   | Criterio de Ingeniería                  |
| ----------------------- | ------------------ | --------------------------------------- |
| Escalabilidad           | Especificación (C) | ¿Hash Map para O(1) o lista simple?     |
| Consistencia de datos   | Requerimientos (B) | ¿Consistencia fuerte (ACID) o eventual? |
| Complejidad algorítmica | Diseño (B→C)       | ¿Es O(n²)? ¿Afectará bajo carga?        |
| Incógnita técnica       | Pre-especificación | Se abre un **Spike** de investigación   |

> [!NOTE]
> El criterio de algoritmos, estructuras de datos y deuda técnica toma fuerza en la **Capa C (Especificación)**, pero siempre basándose en los requerimientos no funcionales definidos en la **Capa B**.

---

## 4. Gestión de Incertidumbre y Deuda Técnica

Durante la etapa de diseño y planificación existen preguntas que **solo se responden al tener detalles de implementación**. Para que esta información no se pierda:

### Technical Spikes (Tareas de Investigación)

Si un requerimiento tiene una incógnita técnica (e.g., "¿Soportará la API de terceros este volumen?"), **no se escribe la especificación aún**. Se crea un Spike acotado (1-2 días) para investigar.

### Registro de Supuestos (Assumptions Log)

Si es necesario avanzar sin una respuesta definitiva, se documenta el supuesto explícitamente:

> _"Estamos asumiendo que el procesamiento será sincrónico. Si debe ser asincrónico, esto se convertirá en deuda técnica de arquitectura."_

### Matriz de Riesgos

Para clasificar y priorizar contingencias:

1. **Identificar** los riesgos potenciales.
2. **Evaluar** su probabilidad e impacto.
3. **Clasificar** y priorizar por severidad.
4. **Definir** acciones de mitigación.

> [!WARNING]
> Las preguntas clave no resueltas en diseño deben documentarse como **supuestos** o **riesgos**. Si se ignoran, se convierten en deuda técnica invisible.

---

## 5. DDD como Paraguas Organizacional

**Domain-Driven Design** no se aplica solo al código, sino como lenguaje común para todo el paradigma:

- **Bounded Contexts (Contextos Delimitados):** Cada módulo responde a un subdominio específico del negocio.
- **Lenguaje Ubicuo:** Antes de escribir una historia de usuario, se define en qué "dominio" estamos (e.g., Gestión de Tiempo vs. IA Journaling).
- **Separación clara:** Evita que requerimientos se mezclen y generen dependencias caóticas.

---

## 6. Relación entre Metodologías

```
┌──────────────────────────────────────────────────────────────┐
│                    MANIFIESTO AGILE                          │
│              (Flexibilidad, Iteración, Valor)                │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐ │
│  │      LEAN       │  │     SCRUM       │  │  SIX SIGMA    │ │
│  │  Eliminar       │  │  Sprint, Roles, │  │  Calidad,     │ │
│  │  desperdicio,   │  │  Backlog,       │  │  Reducir      │ │
│  │  flujo continuo │  │  Retrospectivas │  │  variabilidad │ │
│  └────────┬────────┘  └────────┬────────┘  └───────┬───────┘ │
│           │                    │                   │         │
│           └────────────────────┼───────────────────┘         │
│                                │                             │
│                    ┌───────────▼──────────┐                  │
│                    │  DOMAIN-DRIVEN       │                  │
│                    │  DESIGN (DDD)        │                  │
│                    │  Lenguaje común,     │                  │
│                    │  Contextos           │                  │
│                    │  delimitados         │                  │
│                    └──────────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. Diferencias Clave entre Lean y Scrum

Ambos coexisten bajo el paraguas Agile, pero tienen enfoques distintos:

| Aspecto              | Lean                                      | Scrum                                    |
| -------------------- | ----------------------------------------- | ---------------------------------------- |
| **Naturaleza**       | Filosofía / mentalidad                    | Marco de trabajo definido                |
| **Foco**             | Maximizar valor, eliminar desperdicio     | Gestión de proyectos complejos           |
| **Estructura**       | Flexible, principios guía                 | Roles, eventos y artefactos concretos    |
| **Iteraciones**      | Flujo continuo                            | Sprints con duración fija                |
| **Nivel de detalle** | Alto nivel, aplicable a cualquier proceso | Prescriptivo, con ceremonias específicas |

---

## 8. Resumen: El Paradigma Completo

```
Descubrimiento (TPM)     →  "¿Qué problema resolvemos?"
        ↓
Definición (Bridge)       →  "¿Qué reglas y restricciones tiene?"
        ↓
Especificación (TPE)      →  "¿Cómo lo implementamos con calidad?"
        ↓
Gestión de Incertidumbre  →  "¿Qué no sabemos aún?"
```

Este flujo, soportado por **DDD** como lenguaje común y las metodologías **Agile + Lean + Scrum + Six Sigma** como motor operativo, permite construir software con trazabilidad completa desde la idea hasta el código.

---

## Referencias del Paradigma

- [Manifiesto Agile](https://agilemanifesto.org/)
- [Domain-Driven Design — Eric Evans](https://www.domainlanguage.com/ddd/)
- [Lean Software Development — Mary & Tom Poppendieck](https://www.poppendieck.com/)
- [Six Sigma en Ingeniería de Software](https://www.isixsigma.com/)
- [Behavior Driven Development (BDD)](https://cucumber.io/docs/bdd/)
