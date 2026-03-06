# Spec-Driven Development (SDD) Stack

> Ecosistema de herramientas para desarrollo asistido por IA con especificaciones como fuente de verdad.
>
> **Fecha:** 2026-03-05
> **Proyecto:** YourFocus
> **Ref:** [Paradigma Integrado](../convenions/planning_and_design/index.md)

---

## 1. Visión General

El SDD Stack integra 3 herramientas que, combinadas con el [Paradigma Integrado de Planificación y Diseño](../convenions/planning_and_design/index.md), crean un pipeline completo:

```
IDEA → Especificación → Plan → Tasks → Issues → Implementación → PR
         (Spec Kit)                      (GitHub MCP)    (Tessl da contexto)
```

### Arquitectura de 3 capas

```
┌──────────────────────────────────────────────────────┐
│              PARADIGMA INTEGRADO (index.md)           │
│           Agile + Lean + Scrum + Six Sigma + DDD     │
└──────────────┬───────────────────┬───────────────────┘
               │                   │
    ┌──────────▼──────────┐ ┌──────▼──────────────────┐
    │    SPEC KIT         │ │       TESSL             │
    │    (Proceso)        │ │    (Contexto de IA)     │
    │                     │ │                         │
    │ /speckit.specify    │ │ 18 docs tiles           │
    │ /speckit.plan       │ │  3 skills               │
    │ /speckit.tasks      │ │ MCP server integrado    │
    │ /speckit.implement  │ │                         │
    └──────────┬──────────┘ └──────┬──────────────────┘
               │                   │
    ┌──────────▼───────────────────▼──────────────────┐
    │              GITHUB MCP                          │
    │        Issues ← tasks.md                        │
    │        PRs ← branches                           │
    │        Projects ← Kanban                        │
    └─────────────────────────────────────────────────┘
```

| Capa               | Herramienta | Resuelve                         | Sin ella...                                 |
| ------------------ | ----------- | -------------------------------- | ------------------------------------------- |
| **Proceso**        | Spec Kit    | Cómo planificar y diseñar        | La IA implementa sin especificación clara   |
| **Contexto**       | Tessl       | Que la IA use APIs correctas     | La IA hallucina APIs de versiones viejas    |
| **Automatización** | GitHub MCP  | Issues, PRs, código desde el IDE | Copias/pegas manualmente entre IDE y GitHub |

---

## 2. Spec Kit (GitHub)

### ¿Qué es?

Toolkit open-source de GitHub para Spec-Driven Development. Define un flujo de trabajo basado en especificaciones que guía a los agentes IA a través de fases estructuradas.

- **Repo:** [github.com/github/spec-kit](https://github.com/github/spec-kit)
- **CLI:** `specify-cli` (instalado via `uv`)
- **Versión actual:** 0.1.13

### Instalación

```bash
# Prerequisito: uv (package manager Python)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Spec Kit
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Inicializar en proyecto
specify init . --ai gemini --no-git --force
```

### Estructura generada

```
.specify/
├── memory/
│   └── constitution.md          ← Principios del proyecto (ADN)
├── scripts/
│   └── bash/
│       ├── check-prerequisites.sh
│       ├── common.sh
│       ├── create-new-feature.sh
│       ├── setup-plan.sh
│       └── update-agent-context.sh
└── templates/
    ├── constitution-template.md
    ├── spec-template.md
    ├── plan-template.md
    ├── tasks-template.md
    ├── checklist-template.md
    └── agent-file-template.md

.gemini/commands/
├── speckit.constitution.toml
├── speckit.specify.toml
├── speckit.clarify.toml
├── speckit.plan.toml
├── speckit.checklist.toml
├── speckit.tasks.toml
├── speckit.analyze.toml
├── speckit.implement.toml
└── speckit.taskstoissues.toml
```

### Slash Commands

| Comando                  | Fase      | Qué genera              | Mapeo al Paradigma                            |
| ------------------------ | --------- | ----------------------- | --------------------------------------------- |
| `/speckit.constitution`  | Setup     | `constitution.md`       | `index.md` → principios no negociables        |
| `/speckit.specify`       | Specify   | `spec.md`               | Capa A (Descubrimiento) + Capa B (Definición) |
| `/speckit.clarify`       | Specify   | Preguntas estructuradas | Gestión de Incertidumbre (Capa 5)             |
| `/speckit.plan`          | Plan      | `plan.md`               | Capa C (Especificación) + Capa D (Ingeniería) |
| `/speckit.checklist`     | Plan      | Checklist de calidad    | Quality Gates (Constitution)                  |
| `/speckit.tasks`         | Tasks     | `tasks.md`              | Atomización a Pomodoros de 25 min             |
| `/speckit.analyze`       | Tasks     | Reporte de consistencia | Cross-check entre artefactos                  |
| `/speckit.implement`     | Implement | Código                  | Ejecución task por task                       |
| `/speckit.taskstoissues` | Implement | GitHub Issues           | Requiere GitHub MCP                           |

### Constitution del proyecto

La `constitution.md` de YourFocus define 6 principios:

1. **TDAH-First Design** — Decisión única, atomización forzada, tags sobre jerarquías
2. **Spec-Driven Development** — Flujo de 5 capas documentado
3. **Domain-Driven Design** — Bounded Contexts como límites de módulo
4. **Kaizen (1% Diario)** — Pomodoro 25 min como unidad atómica
5. **BDD → TDD Pipeline** — Escenarios Gherkin antes de código
6. **Offline-First PWA** — Inbox y Pomodoro funcionan offline

> Ref: [.specify/memory/constitution.md](../../.specify/memory/constitution.md)

---

## 3. Tessl

### ¿Qué es?

Package manager para contexto de agentes IA. Como npm pero para documentación y skills que la IA consume via MCP. Evita que los agentes hallucinen APIs de versiones incorrectas.

- **Docs:** [docs.tessl.io](https://docs.tessl.io)
- **Registry:** [tessl.io/registry](https://tessl.io/registry)
- **CLI:** `tessl`
- **Versión actual:** 0.69.0

### Conceptos clave

| Concepto       | Descripción                                      | Ejemplo                            |
| -------------- | ------------------------------------------------ | ---------------------------------- |
| **Docs Tile**  | Documentación versionada de una librería         | `tessl/npm-xstate@5.21.0`          |
| **Skill Tile** | Workflow procedural que la IA sigue              | `supabase-postgres-best-practices` |
| **Rules Tile** | Convenciones que la IA respeta siempre           | `query_library_docs`               |
| **Manifest**   | `tessl.json` — declara qué tiles usa el proyecto | Like `package.json`                |

### Instalación

```bash
# CLI
curl -fsSL https://get.tessl.io | sh

# Inicializar (auto-detecta dependencias del package.json)
tessl init --agent gemini --project-dependencies install

# Instalar skills adicionales
tessl install github:supabase/agent-skills
tessl install github:onmax/nuxt-skills --skill nuxt --skill nuxt-ui --skill vue
tessl install github:figma/mcp-server-guide --skill implement-design

# Ver tiles instalados
tessl list

# Buscar tiles disponibles
tessl search <keyword>
```

### Tiles instalados en YourFocus (21)

#### Docs Tiles (18)

| Tile                              | Versión | Dependencia del proyecto |
| --------------------------------- | ------- | ------------------------ |
| `tessl/npm-nuxt`                  | 4.1.0   | nuxt ^4.2.1              |
| `tessl/npm-vue`                   | 3.5.0   | vue ^3.5.25              |
| `tessl/npm-vue-router`            | 3.6.0   | vue-router ^4.6.3        |
| `tessl/npm-xstate`                | 5.21.0  | xstate ^5.25.0           |
| `tessl/npm-pinia`                 | 3.0.0   | pinia ^3.0.4             |
| `tessl/npm-supabase--supabase-js` | 2.57.0  | @nuxtjs/supabase         |
| `tessl/npm-zod`                   | 4.3.0   | zod ^4.1.13              |
| `tessl/npm-vitest`                | 4.0.0   | vitest ^4.0.14           |
| `tessl/npm-ai`                    | 5.0.1   | ai ^6.0.45               |
| `tessl/npm-ai-sdk--google`        | 2.0.0   | @ai-sdk/google           |
| `tessl/npm-ai-sdk--provider`      | 2.0.0   | @ai-sdk/provider         |
| `tessl/npm-vueuse--core`          | 13.9.0  | @vueuse/core             |
| `tessl/npm-vueuse--nuxt`          | 13.9.0  | @vueuse/nuxt             |
| `tessl/npm-date-fns`              | 4.1.0   | date-fns                 |
| `tessl/npm-luxon`                 | 2.5.0   | luxon                    |
| `tessl/npm-pg`                    | 8.16.0  | pg                       |
| `tessl/npm-postgres`              | 3.4.0   | postgres                 |
| `tessl/npm-jsonwebtoken`          | 9.0.0   | jsonwebtoken             |

#### Skill Tiles (3)

| Tile                          | Tipo  | Qué aporta                                             |
| ----------------------------- | ----- | ------------------------------------------------------ |
| `supabase/agent-skills`       | Skill | Best practices Postgres: queries, schemas, performance |
| `onmax/nuxt-skills` (nuxt)    | Skill | Server routes, middleware, SSR, composables Nuxt 4+    |
| `onmax/nuxt-skills` (nuxt-ui) | Skill | Componentes @nuxt/ui v4: forms, tables, modals         |

### Estructura generada

```
.tessl/
├── .gitignore
├── RULES.md                     ← Reglas derivadas de tiles instalados
└── tiles/
    ├── tessl/                   ← Docs tiles (per-dependency)
    ├── supabase/
    │   └── agent-skills/
    │       └── skills/supabase-postgres-best-practices/SKILL.md
    └── onmax/
        └── nuxt-skills/

.gemini/settings.json            ← MCP server de Tessl
tessl.json                       ← Manifest del proyecto
```

---

## 4. GitHub MCP Server

### ¿Qué es?

MCP server oficial de GitHub que permite a agentes IA interactuar con repositorios, issues, PRs, y código directamente desde el IDE.

### Configuración

En `~/.gemini/antigravity/mcp_config.json`:

```json
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "<TU_PAT>"
  }
}
```

**PAT requerido:** [github.com/settings/tokens](https://github.com/settings/tokens) con permisos `repo`, `issues`, `pull_requests`, `projects`.

### Capacidades

| Herramienta        | Uso en el flujo                                      |
| ------------------ | ---------------------------------------------------- |
| Crear Issues       | `/speckit.taskstoissues` → convierte tasks en Issues |
| Crear PRs          | Automatizar PRs desde ramas                          |
| Leer código        | Contexto del repo para decisiones de diseño          |
| Gestionar branches | Crear ramas feature desde el IDE                     |
| Code reviews       | Revisar PRs con IA                                   |
| Search             | Buscar código, issues, repos                         |

---

## 5. Configuración para Landing Pages

### MCPs adicionales disponibles

| MCP Server   | Paquete                       | Propósito                           | Madurez      |
| ------------ | ----------------------------- | ----------------------------------- | ------------ |
| **Figma**    | `@anthropic/figma-mcp-server` | Design → Code desde Figma           | ✅ Estable   |
| **Odoo**     | `odoo-mcp-server`             | Backoffice: CRM, ventas, inventario | ⚠️ Alpha     |
| **Meta Ads** | `@nicholaschen/meta-ads-mcp`  | Analizar campañas Meta              | ⚠️ Community |

### Analytics: GA4 + GTM + Meta Pixel

> GA4 y Meta Pixel se integran como **código Nuxt**, no como MCPs.
> Los MCPs de analytics sirven para _analizar datos_, no para _recopilar tracking_.

#### GTM en `nuxt.config.ts`

```typescript
export default defineNuxtConfig({
  app: {
    head: {
      script: [
        {
          innerHTML: `(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
          new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
          j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
          'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
          })(window,document,'script','dataLayer','GTM-XXXXXXX');`,
          type: "text/javascript",
        },
      ],
    },
  },
  runtimeConfig: {
    public: {
      gtmId: "GTM-XXXXXXX",
      metaPixelId: "XXXXXXXXXXXXXXX",
      ga4MeasurementId: "G-XXXXXXXXXX",
    },
  },
});
```

#### Meta Pixel plugin (`plugins/meta-pixel.client.ts`)

```typescript
export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig();
  const pixelId = config.public.metaPixelId;

  !(function (f: any, b: any, e: any, v: any, n?: any, t?: any, s?: any) {
    if (f.fbq) return;
    n = f.fbq = function () {
      n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments);
    };
    if (!f._fbq) f._fbq = n;
    n.push = n;
    n.loaded = !0;
    n.version = "2.0";
    n.queue = [];
    t = b.createElement(e);
    t.async = !0;
    t.src = v;
    s = b.getElementsByTagName(e)[0];
    s.parentNode.insertBefore(t, s);
  })(
    window,
    document,
    "script",
    "https://connect.facebook.net/en_US/fbevents.js",
  );

  window.fbq("init", pixelId);
  window.fbq("track", "PageView");

  const router = useRouter();
  router.afterEach(() => {
    window.fbq("track", "PageView");
  });
});
```

#### Composable de tracking (`composables/useTracking.ts`)

```typescript
export function useTracking() {
  const gtmPush = (event: string, data?: Record<string, any>) => {
    window.dataLayer?.push({ event, ...data });
  };

  const metaTrack = (event: string, data?: Record<string, any>) => {
    window.fbq?.("track", event, data);
  };

  const trackConversion = (eventName: string, value?: number) => {
    gtmPush(eventName, { value });
    metaTrack(eventName, { value, currency: "USD" });
  };

  return { gtmPush, metaTrack, trackConversion };
}
```

### Figma MCP + Tessl Skills

```bash
# Configurar MCP
# En mcp_config.json:
# "figma": {
#   "command": "npx",
#   "args": ["-y", "@anthropic/figma-mcp-server@latest"],
#   "env": { "FIGMA_PERSONAL_ACCESS_TOKEN": "<TOKEN>" }
# }

# Instalar Tessl skills para design → code
tessl install github:figma/mcp-server-guide \
  --skill implement-design \
  --skill create-design-system-rules
```

Skills disponibles:

- **implement-design** — Traduce Figma designs a código con fidelidad 1:1
- **create-design-system-rules** — Genera reglas de design system para tu codebase
- **code-connect-components** — Conecta componentes Figma con código existente

---

## 6. Flujo de trabajo diario

### Setup (una sola vez por proyecto)

```bash
specify init . --ai gemini --no-git --force    # Spec Kit
tessl init --agent gemini                       # Tessl (auto-detecta deps)
# Editar .specify/memory/constitution.md       # Principios del proyecto
```

### Ciclo de desarrollo

```
1. /speckit.constitution     → Definir/actualizar principios
2. /speckit.specify          → "Quiero un sistema de auth con magic links"
3. /speckit.clarify          → Desambiguar dudas antes de planificar
4. /speckit.plan             → Genera plan técnico con arquitectura
5. /speckit.checklist        → Checklist de calidad
6. /speckit.tasks            → Desglose en tareas atómicas (Pomodoro 25 min)
7. /speckit.taskstoissues    → Crear GitHub Issues automáticamente
8. /speckit.implement        → Implementar task por task (con contexto Tessl)
```

### Mantenimiento

```bash
tessl install --project-dependencies   # Actualizar tiles cuando cambien deps
/speckit.constitution                  # Actualizar principios si cambian
tessl search <keyword>                 # Buscar nuevos skills o docs
```

---

## 7. Tokens requeridos (Checklist)

| Servicio   | Variable                       | Dónde obtenerlo                                                  |
| ---------- | ------------------------------ | ---------------------------------------------------------------- |
| GitHub     | `GITHUB_PERSONAL_ACCESS_TOKEN` | [github.com/settings/tokens](https://github.com/settings/tokens) |
| Figma      | `FIGMA_PERSONAL_ACCESS_TOKEN`  | [figma.com/settings](https://www.figma.com/settings)             |
| GA4        | `G-XXXXXXXXXX`                 | Google Analytics → Admin → Data Streams                          |
| GTM        | `GTM-XXXXXXX`                  | Google Tag Manager → Container                                   |
| Meta Pixel | Pixel ID                       | Meta Business → Events Manager                                   |
| Meta Ads   | `META_ACCESS_TOKEN`            | Meta Business → System User                                      |
| Odoo       | `ODOO_PASSWORD` (API key)      | Odoo → Settings → Users → API Keys                               |
| Supabase   | Access token                   | [supabase.com/dashboard](https://supabase.com/dashboard)         |

---

## 8. Estructura completa del proyecto

```
proyecto/
├── .specify/                      # Spec Kit (proceso)
│   ├── memory/constitution.md
│   ├── templates/
│   └── scripts/
│
├── .tessl/                        # Tessl (contexto IA)
│   ├── RULES.md
│   └── tiles/
│
├── .gemini/                       # Antigravity config
│   ├── commands/speckit.*.toml    # 9 slash commands
│   └── settings.json              # MCP Tessl
│
├── docs/
│   ├── convenions/planning_and_design/
│   │   ├── index.md               # Paradigma integrado
│   │   └── feature_template.md    # Template de features
│   ├── features/
│   │   └── <feature>/
│   │       └── feature_<name>.md  # Feature doc
│   └── technical/
│       └── spec_driven_development_stack.md  # Este archivo
│
├── tessl.json                     # Manifest Tessl
└── package.json
```
