# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Yourfocus is a Pomodoro-based productivity app built with **Nuxt 4** (Vue 3, SSR), **Supabase** (Postgres + Auth + Realtime + Edge Functions), and **Pinia**. Features include a Pomodoro timer with cycles, tasks/kanban, voice bitacoras with AI transcription, an AI "Second Brain" chat agent, and push notifications. The app is a PWA with offline support via Workbox background sync.

## Commands

```bash
bun install          # Install dependencies (uses Bun)
bun dev              # Start dev server
bun run build        # Production build
bun test             # Run all tests (vitest)
npx vitest run test/unit/utils/pomodoro-domain.test.ts  # Run a single test file

# Supabase
supabase gen types typescript --local > ./app/types/database.types.ts  # Regen types from local DB
supabase gen types typescript --project-id meneprjtfpcppidpgava > ./app/types/database.types.ts  # From remote
supabase db dump --local > supabase/seed.sql  # Dump local data
```

No ESLint or Prettier is configured. TypeScript is the primary quality gate.

## Architecture

### Layered Architecture (composables)

Every business module lives in `app/composables/<entity>/` and follows this strict layering:

```
View (pages/ & components/)
  └── Controller (*-controller.ts — Pinia store or composable, UI state)
        └── Service (*-service.ts — business logic, use-cases, orchestration)
              └── Repository (*-repository.ts — Supabase queries only)
                    └── Domain (*-domain.ts in utils/ — pure functions, no deps)
```

- **Domain**: Pure functions with no side effects or framework imports. Lives in `app/utils/` (e.g., `pomodoro-domain.ts`). Easily unit-testable.
- **Repository**: All Supabase client calls. Uses `useSupabaseClient()` with typed `Database` generic.
- **Service**: Orchestrates repository calls, applies domain logic, manages side effects.
- **Controller**: Pinia stores (`defineStore`) or composables that expose reactive state to components. Global shared state uses Nuxt's `useState()`.
- **Components**: Must be page-agnostic (no `useRoute()` in components).

### Pomodoro State Machine

The Pomodoro system uses **XState v5** (`app/composables/pomodoro/pomodoro.machine.ts`). States: `idle → fetching → starting → running → pausing → paused → resuming → finishing → skipping → creatingNext`. The controller wraps the machine in a Pinia store.

### Multi-Tab Sync

`useBroadcastPomodoro` uses Supabase Realtime broadcast on a private channel `pomodoro_sync:{userId}`. It uses the Presence API to elect the oldest tab as "main handler" to prevent duplicate pomodoro creation across tabs.

### Task-Pomodoro Relationship

Many-to-many via `pomodoros_tasks` table. Tasks have a `keep` boolean column — when enabled, DB triggers automatically assign the task to the current pomodoro and carry it over to new pomodoros. Tasks marked done/archived have `keep` reset to `false`. This logic lives in the database, not the frontend.

### Server Side

Nitro server routes live in `server/api/`. Auth middleware (`server/middleware/auth.ts`) sets `event.context.auth`. Server-side Supabase access uses `serverSupabaseUser(event)` and `serverSupabaseClient<Database>(event)` from `#supabase/server`.

### AI Integration

Uses Vercel AI SDK with Google Gemini (`@ai-sdk/google`) for the chat agent and audio transcription. Chat routes: `server/api/chat.post.ts`, `server/api/chat.get.ts`.

### PWA & Offline

Workbox background sync queues all POST/PATCH/DELETE to `/rest/v1/pomodoros` and `/rest/v1/pomodoros_cycles` with 24h retry. `useOfflineSync.ts` reads the IndexedDB queue to show pending syncs in the UI.

## Database

All tables have RLS enabled. Policy pattern: `auth.uid() IS NOT NULL AND auth.uid() = user_id`. PAT access validated via `is_valid_personal_access_token()` DB function.

Key tables: `profiles`, `tasks`, `pomodoros`, `pomodoros_cycles`, `pomodoros_tags`, `pomodoros_tasks`, `tags`, `task_templates`, `scheduled_notifications`, `push_subscriptions`.

Schema DDL lives in `supabase/schemas/` (tables, functions/triggers, policies, storage). Migrations in `supabase/migrations/`.

## Conventions

- **Composables**: kebab-case with `use-` prefix (e.g., `use-pomodoro-controller.ts`)
- **Components**: PascalCase (e.g., `YourfocusTimer.vue`)
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, etc.)
- **i18n**: Default locale is `es` (Spanish), secondary `en`. Files in `i18n/locales/`
- **Tests**: Vitest with `@nuxt/test-utils`. Test env requires `.env.test` (see `.env.test.example`). Tests use Gherkin-like labels: `[[Domain Logic Level]]` for pure unit tests, `[[Supabase Integration Level]]` for DB integration tests

## Key Files

- `app/utils/pomodoro-domain.ts` — Pure Pomodoro domain logic (durations, cycle completion, timelapse calculation)
- `app/composables/pomodoro/pomodoro.machine.ts` — XState state machine definition
- `app/types/database.types.ts` — Auto-generated Supabase types (do not edit manually)
- `app/types/tables.ts` — Prettified type aliases for IDE navigation
- `shared/utils/jornada.ts` — Jornada (time block) definitions shared between client and server
- `docs/standards.md` — Architecture standards and naming conventions
- `docs/specification.md` — Full technical specification
- `PROJECT_CONTEXT.md` — Database schema reference with ER diagram

@AGENTS.md
