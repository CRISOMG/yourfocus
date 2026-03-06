# Paradigma Integrado de Planificación y Diseño de Software

> Un marco de trabajo para abordar el rol dual de **Technical Product Manager (TPM)** y **Technical Product Engineer (TPE)**, integrando principios de Agile, Lean, Scrum, Six Sigma, Domain-Driven Design, BDD y metodologías formales.

---

## 1. Visión General

Este paradigma propone una estructura de capas progresivas que conecta la **visión de negocio** con la **ejecución técnica**, asegurando que la transición entre "qué construir" y "cómo construirlo" sea trazable, documentada y de alta calidad.

### Pilares Fundamentales

| Pilar                         | Rol en el paradigma           | Aporte clave                                                      |
| ----------------------------- | ----------------------------- | ----------------------------------------------------------------- |
| **Manifiesto Agile**          | Base filosófica               | Flexibilidad, adaptación al cambio, entrega iterativa de valor    |
| **Lean**                      | Filosofía de eficiencia       | Maximizar valor, eliminar desperdicio, optimización continua      |
| **Scrum**                     | Marco operativo               | Roles, eventos y artefactos concretos para gestionar complejidad  |
| **Six Sigma**                 | Calidad de proceso            | Reducir variabilidad, herramientas estadísticas, mejora continua  |
| **Domain-Driven Design**      | Lenguaje y arquitectura       | Contextos delimitados, lenguaje ubicuo, alineación negocio-código |
| **Behavior-Driven Dev (BDD)** | Puente requerimientos → tests | Criterios de aceptación ejecutables con Gherkin                   |

---

## 2. Arquitectura de Capas

El paradigma se estructura en capas secuenciales que van de lo abstracto a lo concreto. Cada capa tiene un propósito, un responsable implícito y artefactos de salida claros.

### Capa A: Descubrimiento — _Enfoque en el Problema_ (TPM)

**Objetivo:** Entender y articular el _dolor_ del usuario y el valor de negocio.

- **Historias de Usuario:** Formato estándar `Como [rol], quiero [acción], para [valor]`.
- **Lean Canvas / Entrevistas:** Extracción del problema real del usuario.
- **KPIs de Éxito:** Métricas que validen si la solución funciona.

**Artefacto de salida:** Lista de intenciones de alto nivel alineadas con el valor de negocio.

> [!TIP]
> Cada feature puede tratarse como un **"mini-producto"** con su propio Lean Canvas. Cuando hay múltiples Canvas, se crea un Canvas principal que actúa como vista general y vincula cada feature a su Canvas específico. Esto mantiene la coherencia estratégica (ver [Sección 9: Features como Mini-Productos](#9-features-como-mini-productos-lean-canvas-por-feature)).

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
- **Module-Based Structure:** Agrupación de múltiples features en módulos coherentes, definidos por los **Bounded Contexts** de DDD.
- **Decisiones de Arquitectura:** Selección de algoritmos, estructuras de datos y patrones.

**Artefacto de salida:** Especificaciones BDD + documentación de decisiones técnicas.

---

## 3. Metodologías de Especificación — BDD, VDM y Feature/Module Structure

### 3.1 Behavior-Driven Development (BDD)

BDD se ubica en un **punto transversal** entre las capas B y C. Define los comportamientos esperados del sistema con ejemplos concretos que conectan requerimientos con especificaciones.

**Formato Given / When / Then:**

```gherkin
Feature: [Título de la funcionalidad]

  Scenario: [Caso de éxito]
    Given [Contexto inicial — estado del sistema]
    When [Acción del usuario — evento disparador]
    Then [Resultado esperado — comportamiento verificable]
```

> [!NOTE]
> BDD facilita la **transición a Test-Driven Development (TDD)** al establecer criterios de aceptación claros y ejecutables desde el principio. Las pruebas se escriben basándose en el comportamiento definido, asegurando congruencia entre requerimientos e implementación.

**Pipeline BDD → TDD:**

```
Historias de Usuario (Capa A)
        ↓
Criterios de Aceptación (Capa B)
        ↓
Escenarios BDD / Gherkin (Capa B↔C)
        ↓
Tests automatizados / TDD (Implementación)
```

### 3.2 Vienna Development Method (VDM)

VDM es una **metodología formal** con alto nivel de abstracción, basada en matemáticas y especificaciones precisas. Se sitúa a un nivel más cercano a la especificación formal que BDD:

| Aspecto         | BDD                                     | VDM                                     |
| --------------- | --------------------------------------- | --------------------------------------- |
| **Enfoque**     | Comportamiento y colaboración           | Especificación formal y matemática      |
| **Lenguaje**    | Gherkin (lenguaje natural estructurado) | Notación formal (pre/post condiciones)  |
| **Para qué**    | Validar con stakeholders                | Partes críticas que requieren precisión |
| **Cuándo usar** | Mayoría de las features                 | Componentes de alta criticidad          |

**Integración recomendada:** Usar BDD para la mayoría de los comportamientos y reservar VDM para la especificación detallada de las partes más críticas del sistema.

### 3.3 Feature-Based vs. Module-Based Structure

| Nivel             | Granularidad      | Determinado por           | Ejemplo                              |
| ----------------- | ----------------- | ------------------------- | ------------------------------------ |
| **Feature-Based** | Una funcionalidad | Un criterio de aceptación | "Tag-Based OKRs", "AI Atomizer"      |
| **Module-Based**  | Grupo de features | Bounded Context (DDD)     | "Gestión de Tiempo", "IA Journaling" |

- Un **Feature** es la unidad de documentación: un archivo Markdown por feature.
- Un **Módulo** agrupa features que comparten el mismo dominio/bounded context.
- Lo que determina los límites de un módulo son los **bounded contexts** de DDD: áreas con lenguaje y objetivos distintos.

---

## 4. Criterio de Ingeniería de Software y Ciencias de la Computación

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

## 5. Gestión de Incertidumbre y Deuda Técnica

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

## 6. DDD como Paraguas Organizacional

**Domain-Driven Design** no se aplica solo al código, sino como lenguaje común para todo el paradigma:

- **Bounded Contexts (Contextos Delimitados):** Cada módulo responde a un subdominio específico del negocio. Se identifican observando los límites naturales del negocio: áreas con lenguaje y objetivos distintos.
- **Lenguaje Ubicuo:** Antes de escribir una historia de usuario, se define en qué "dominio" estamos (e.g., Gestión de Tiempo vs. IA Journaling).
- **Separación clara:** Evita que requerimientos se mezclen y generen dependencias caóticas.
- **Module Structure:** Los bounded contexts son los que determinan qué features se agrupan en un módulo.

---

## 7. Medición del Agotamiento y Bienestar

El paradigma no solo mide productividad, sino también el **costo cognitivo** del trabajo. Basándose en el **Maslach Burnout Inventory (MBI)**, se consideran tres dimensiones de agotamiento:

| Dimensión                         | Cualificación                                            | Cuantificación                                     |
| --------------------------------- | -------------------------------------------------------- | -------------------------------------------------- |
| **Agotamiento emocional**         | Sensación de estar exhausto, sin energía para el trabajo | Escala de frecuencia (nunca → siempre)             |
| **Despersonalización**            | Actitud distante o cínica hacia el trabajo o los demás   | Preguntas sobre percepción de distanciamiento      |
| **Falta de realización personal** | Sensación de ineficacia, que el trabajo no tiene sentido | Preguntas sobre logro y satisfacción con las metas |

> [!IMPORTANT]
> En sistemas basados en OKRs y Pomodoros, estas dimensiones se pueden medir con:
>
> - Encuestas periódicas integradas (check-ins post-pomodoro).
> - Monitoreo de cambios en rendimiento (pomodoros completados vs. interrumpidos).
> - Señales de alerta: retrasos constantes con metas clave, disminución de productividad.

### Pomodoro de 25 minutos como Unidad Atómica

Los 25 minutos son un periodo óptimo para mantener concentración intensa sin llegar al agotamiento. Estos "sprints" de trabajo, seguidos de descansos breves, ayudan a:

- Gestionar mejor el tiempo.
- Prevenir la procrastinación.
- Establecer una unidad medible de esfuerzo.

---

## 8. Relación entre Metodologías

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
│                    └───────────┬──────────┘                  │
│                                │                             │
│              ┌─────────────────┼─────────────────┐           │
│              │                 │                 │           │
│    ┌─────────▼───────┐ ┌──────▼────────┐ ┌──────▼─────────┐ │
│    │  BDD (Gherkin)  │ │ Feature-Based │ │ Module-Based   │ │
│    │  Given/When/    │ │ Structure     │ │ Structure      │ │
│    │  Then → TDD     │ │ (1 feature =  │ │ (Bounded       │ │
│    │                 │ │  1 doc)       │ │  Contexts)     │ │
│    └─────────────────┘ └──────────────┘  └────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 9. Features como Mini-Productos (Lean Canvas por Feature)

Cada feature puede abordarse como un **"mini-producto"** y gestionarse con principios de gerencia de productos:

- Se puede definir un **Lean Canvas por feature** que destile: propuesta de valor, segmentos, métricas, estructura de costos y fuentes de ingreso específicas de esa funcionalidad.
- Cuando existen múltiples Lean Canvas, se alinean con un **Canvas principal** que actúa como vista general del producto.

### Estructura de Integración

```
Canvas Principal (Producto)
├── Canvas Feature A (e.g., Tag-Based OKRs)
├── Canvas Feature B (e.g., AI Atomizer)
├── Canvas Feature C (e.g., Zettelkasten Notes)
└── ... cada uno con las 9 secciones del Lean Canvas
```

### Las 9 Secciones del Lean Canvas

1. **Problema** — Dolores top 3 del usuario
2. **Segmento de Clientes** — Early adopters y perfiles
3. **Propuesta de Valor Única** — Diferenciador clave
4. **Solución** — Features que resuelven el problema
5. **Canales** — Cómo llega al usuario
6. **Flujos de Ingresos** — Modelo de monetización
7. **Estructura de Costos** — COGS y costos fijos
8. **Métricas Clave** — North Star Metric + KPIs
9. **Ventaja Injusta** — Barrera de entrada

---

## 10. Diferencias Clave entre Lean y Scrum

Ambos coexisten bajo el paraguas Agile, pero tienen enfoques distintos:

| Aspecto              | Lean                                      | Scrum                                    |
| -------------------- | ----------------------------------------- | ---------------------------------------- |
| **Naturaleza**       | Filosofía / mentalidad                    | Marco de trabajo definido                |
| **Foco**             | Maximizar valor, eliminar desperdicio     | Gestión de proyectos complejos           |
| **Estructura**       | Flexible, principios guía                 | Roles, eventos y artefactos concretos    |
| **Iteraciones**      | Flujo continuo                            | Sprints con duración fija                |
| **Nivel de detalle** | Alto nivel, aplicable a cualquier proceso | Prescriptivo, con ceremonias específicas |

---

## 11. Resumen: El Paradigma Completo

```
Descubrimiento (TPM)     →  "¿Qué problema resolvemos?"
        ↓                      Lean Canvas, User Stories
Definición (Bridge)       →  "¿Qué reglas y restricciones tiene?"
        ↓                      RF, RNF, Criterios de Aceptación
Especificación (TPE)      →  "¿Cómo lo implementamos con calidad?"
        ↓                      BDD/Gherkin → TDD, Feature/Module Structure
Ingeniería y CS           →  "¿Qué algoritmos y trade-offs?"
        ↓                      Complejidad, Spikes, Decisiones técnicas
Gestión de Incertidumbre  →  "¿Qué no sabemos aún?"
        ↓                      Assumptions Log, Matriz de Riesgos
Bienestar y Sostenibilidad → "¿Cuál es el costo cognitivo?"
                               Maslach Burnout Inventory, Pomodoro 25min
```

Este flujo, soportado por **DDD** como lenguaje común y las metodologías **Agile + Lean + Scrum + Six Sigma** como motor operativo, permite construir software con trazabilidad completa desde la idea hasta el código, cuidando tanto la calidad técnica como el bienestar del profesional.

---

## Referencias del Paradigma

- [Manifiesto Agile](https://agilemanifesto.org/)
- [Domain-Driven Design — Eric Evans](https://www.domainlanguage.com/ddd/)
- [Lean Software Development — Mary & Tom Poppendieck](https://www.poppendieck.com/)
- [Six Sigma en Ingeniería de Software](https://www.isixsigma.com/)
- [Behavior Driven Development (BDD)](https://cucumber.io/docs/bdd/)
- [Vienna Development Method (VDM)](https://www.overturetool.org/)
- [Maslach Burnout Inventory (MBI)](https://www.mindgarden.com/117-maslach-burnout-inventory-mbi)
- [Lean Canvas — Ash Maurya](https://leanstack.com/lean-canvas)
