# Sesión: Arquitectura TIME/FLOW

**Fecha:** 2026-03-04
**Duración aprox:** ~3h
**Objetivo:** Implementar la capa de abstracción TIME que soporta Pomodoro (temporizador regresivo) y Flow (cronómetro progresivo con límites de jornada).

---

## Contexto

Yourfocus ya tenía un sistema de Pomodoro funcional. Se necesitaba abstraer la medición del tiempo para soportar un nuevo modo **Flow**: un cronómetro progresivo que se limita automáticamente según los bloques de jornada definidos en `shared/utils/v2/jornada.ts`.

## Decisiones de diseño

| Decisión           | Opción elegida                                                     | Razón                                           |
| ------------------ | ------------------------------------------------------------------ | ----------------------------------------------- |
| Estructura DB      | Opción B: tablas separadas (`time_sessions` → `flows`/`pomodoros`) | Mejor separación de dominio                     |
| Límites de Flow    | Basados en bloques de jornada                                      | La jornada ya define períodos naturales del día |
| Módulo Flow        | `app/composables/time/flow/` separado de Pomodoro                  | Independencia total entre modos                 |
| Migración Pomodoro | FK opcional `time_session_id` en `pomodoros`                       | No rompe código existente                       |

## Cambios realizados

### Base de datos (Supabase)

- **Enum** `time_measurement_mode`: `'pomodoro'` | `'flow'`
- **Tabla `time_sessions`**: entidad padre con `mode`, `state`, `toggle_timeline`, `timelapse`
- **Tabla `flows`**: entidad hija con `jornada_bloque`, `jornada_limit_at`
- **FK** `pomodoros.time_session_id` → `time_sessions.id` (nullable)
- **Unique index**: máximo 1 sesión activa por usuario+modo
- **RLS policies** para ambas tablas
- **Migración local**: `supabase/migrations/20260304213000_create_time_sessions_and_flows.sql`

### Archivos nuevos

| Archivo                                            | Propósito                                                                     |
| -------------------------------------------------- | ----------------------------------------------------------------------------- |
| `app/utils/time-domain.ts`                         | Detección de bloque de jornada actual, cálculo de límites, formateo de tiempo |
| `app/composables/use-stopwatch.ts`                 | Composable de cronómetro progresivo con soporte de límites                    |
| `app/composables/time/flow/use-flow-repository.ts` | CRUD para `time_sessions` + `flows`                                           |
| `app/composables/time/flow/use-flow-service.ts`    | Lógica de negocio: start/pause/resume/finish con detección de jornada         |
| `app/composables/time/flow/use-flow-controller.ts` | Estado UI, ciclo de vida del cronómetro, auto-stop en límites                 |

### Archivos modificados

| Archivo                             | Cambios                                                                                              |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `app/types/database.types.ts`       | Tipos para `flows`, `time_sessions`, enum `time_measurement_mode`, FK `time_session_id` en pomodoros |
| `app/components/YourfocusTimer.vue` | Toggle Pomodoro\|Flow, UI de Flow con indicador de jornada, cronómetro y controles                   |

## Arquitectura del módulo Flow

```
app/composables/time/flow/
├── use-flow-repository.ts   → Capa de datos (Supabase queries)
├── use-flow-service.ts      → Lógica de negocio (jornada detection, state transitions)
└── use-flow-controller.ts   → Estado UI (stopwatch lifecycle, reactive state)
```

**Flujo:**

1. Controller llama a Service para operaciones de dominio
2. Service llama a Repository para persistencia
3. Controller maneja el composable `useStopwatch` para la UI
4. `time-domain.ts` provee utilidades compartidas (jornada blocks, formatting)

## Pendientes

- [ ] Reorganizar composables de Pomodoro en `app/composables/time/pomodoro/`
- [ ] Selección de límite de jornada configurable por usuario
- [ ] Tests unitarios para `time-domain.ts` y `use-stopwatch.ts`
- [ ] Backfill de pomodoros existentes con `time_session_id`

## Notas técnicas

- La tabla `time_sessions` reutiliza el enum `pomodoro_state` para el campo `state` (compartido entre ambos modos)
- El unique index filtra `WHERE state NOT IN ('finished', 'skipped')` para permitir múltiples sesiones históricas
- El cronómetro acepta un `limitAt` (timestamp ISO) para auto-detenerse al final del bloque de jornada
- Los bloques de jornada se actualizan cada 60 segundos en el controller
