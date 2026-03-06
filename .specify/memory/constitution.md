# YourFocus Constitution

> Principios fundamentales que gobiernan toda decisión de diseño, implementación y evolución del producto.
> Basado en el [Paradigma Integrado de Planificación y Diseño](../../docs/convenions/planning_and_design/index.md).

## Core Principles

### I. TDAH-First Design (NON-NEGOTIABLE)

Cada decisión de UX debe evaluarse contra las necesidades de usuarios con TDAH:

- **Decisión única**: Nunca mostrar más de 1 acción prioritaria a la vez.
- **Atomización forzada**: Toda tarea > 25 min (1 Pomodoro) se desglosa con IA antes de ejecutarse.
- **Tags sobre jerarquías**: Sin clasificación previa; el usuario lanza y el sistema organiza.
- **Feedback inmediato**: Cada acción completada genera notificación visible de progreso.
- **Córtex prefrontal externo**: La IA actúa como filtro contra la hiperinformación.

### II. Spec-Driven Development (Paradigma de Capas)

Todo feature sigue el flujo de 5 capas documentado en el paradigma:

1. **Descubrimiento (TPM)** → Lean Canvas + User Stories → `feature_template.md`
2. **Definición (Bridge)** → RF/RNF + Criterios de Aceptación
3. **Especificación (TPE)** → BDD/Gherkin + VDM para operaciones críticas
4. **Ingeniería** → Algoritmos, trade-offs, Spikes acotados
5. **Gestión de Incertidumbre** → Assumptions Log + Matriz de Riesgos

### III. Domain-Driven Design como Lenguaje Común

- **Bounded Contexts** definen los límites de cada módulo.
- **Lenguaje Ubicuo**: Cada dominio usa terminología consistente en código, documentación y UI.
- **Feature-Based Structure**: Un archivo Markdown por feature.
- **Module-Based Structure**: Features agrupadas por Bounded Context.

### IV. Kaizen — El 1% Diario

- El Pomodoro de 25 minutos es la **unidad atómica** de esfuerzo.
- Todo progreso se mide automáticamente a través de tags con pesos.
- El sistema cuantifica cualidades abstractas (Enfoque, Agencia, Curiosidad) via la Ontología de Métricas.
- Se mide el bienestar del usuario (Maslach Burnout Inventory) junto con la productividad.

### V. BDD → TDD Pipeline (NON-NEGOTIABLE)

- Criterios de Aceptación (Capa 2) → Escenarios BDD/Gherkin (Capa 3) → Tests automatizados (TDD).
- Ninguna feature se implementa sin escenarios BDD definidos.
- Los tests se escriben antes del código de producción (Red-Green-Refactor).

### VI. Offline-First PWA

- El Inbox y el Pomodoro deben funcionar offline.
- Queuing de acciones con Workbox para sincronización posterior.
- Optimistic UI: feedback visual inmediato, sync en background.

## Technology Stack

| Capa         | Tecnología                    | Justificación                               |
| ------------ | ----------------------------- | ------------------------------------------- |
| **Frontend** | Nuxt 3 + Nuxt UI              | SSR, composables, componentes premium       |
| **Backend**  | Supabase (Postgres + Edge Fn) | RLS, Realtime, Auth integrada               |
| **IA**       | Gemini API                    | Atomización de tareas, asistencia narrativa |
| **Estado**   | XState (State Machines)       | Transiciones predecibles, optimistic UI     |
| **Offline**  | Workbox (Service Worker)      | PWA con sync diferida                       |
| **Tests**    | Vitest + Playwright           | Unit + E2E siguiendo pipeline BDD→TDD       |

## Security Requirements

- **Row Level Security (RLS)** en TODA tabla de Supabase. Sin excepciones.
- Cada usuario solo ve y modifica sus propios datos.
- Las Edge Functions validan auth antes de cualquier operación.
- Los tokens de IA (Gemini) nunca se exponen al cliente.

## Quality Gates

1. **Pre-implement**: Feature tiene `feature_template.md` con estado ≥ `In-Review`.
2. **Pre-merge**: Escenarios BDD cubiertos con tests automatizados.
3. **Pre-deploy**: Zero errores en `npm run build` + Lighthouse score ≥ 90.
4. **Post-deploy**: Métricas de KPI monitoreadas durante 48h.

## Governance

- Esta constitución **supersede** cualquier decisión ad-hoc.
- Amendments requieren: documentación del cambio, justificación, y actualización del `index.md`.
- Todo conflicto entre velocidad y calidad se resuelve a favor de la **experiencia del usuario con TDAH**.
- El [Paradigma Integrado](../../docs/convenions/planning_and_design/index.md) es la referencia canónica.

**Version**: 1.0.0 | **Ratified**: 2026-03-05 | **Last Amended**: 2026-03-05
