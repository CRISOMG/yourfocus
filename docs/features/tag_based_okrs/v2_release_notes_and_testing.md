# Release Notes: Kaizen Engine & Tag-Based OKRs MVP (v2)

Esta actualización consolida el motor de mejora continua (Kaizen) de `Yourfocus` integrando una arquitectura *TDAH-First*, gamificación automatizada y soporte inteligente mediante IA y Zettelkasten.

## 🌟 Nuevas Características y Cambios Core

### 1. OKR Engine "Silent" (SQL Triggers)
- **Gamificación Backend:** Se añadieron triggers en PostgreSQL (`calculate_kr_progress_on_task_done`, `calculate_kr_progress_on_pomodoro_finish`, `calculate_kr_progress_on_note_tag`) que reaccionan instantáneamente a cambios de estado.
- **Soporte `tag_id` Nativo:** El progreso atómico detecta apropiadamente el tag primario asignado a una tarea, sin depender exclusivamente de tablas pivot.
- **Celebración Automática:** Cuando la puntuación de un KR aumenta, se genera automáticamente un `inbox_action` de tipo `OKR_PROGRESS`.

### 2. Inbox Action Dispatcher (`useInboxController.ts`)
- Componente unificado para orquestar acciones en la UI (Modales, páginas o Chat).
- Realtime activado: `setupRealtime` escucha inserciones para actualizar la campana 🔔 del `AppHeader`.
- **Dopamina Instantánea:** Intercepta el evento `OKR_PROGRESS` desde WebSockets para lanzar un _Toast_ verde 🏆 en toda la aplicación redirigiendo al Radar de Analytics.

### 3. Zettelkasten Auto-Sync (Edge Functions)
- **Webhook Nativo de Storage:** Edge function (`sync-markdown`) activada vía webhook HTTP interno de PostgreSQL al modificar la tabla `storage.objects`.
- Parseo automático de Frontmatter YAML de `.md` y hashtags en el Markdown interno.
- Poblamiento dinámico de la base de conocimiento (`notes` y `notes_tags`) que suma experiencia a KRs de aprendizaje.

### 4. Inteligencia Artificial Coach Inyectada en el Chat
- **`atomizeTask` Tool:** La IA recibe un identificador de una Tarea y usa esta `tool` del Vercel AI SDK para desglosar la tarea en 3 sub-tareas atómicas (max 25m) añadiendo los mismos tags de la tarea base.
- **Gamificación en Chat (`usePendingChat`):** Si completas tu tarea/pomodoro y ganas progreso, el sistema fuerza una interacción en tu Chat diciéndole al LLM: _"He ganado +X% de progreso, acompáñame a celebrarlo"_, creando coaching automatizado.

### 5. Radar Chart Analítico Organíco (`KpiRadarChart.vue`)
- RPC avanzado en base de datos (`get_user_kpi_stats`) que trae datos reales agregados de:
  - **Enfoque:** Pomodoros completados (`type='focus'`).
  - **Agencia:** Tareas completadas (`stage='done'`).
  - **Curiosidad:** Notas markdown creadas (Zettelkasten).
  - **Interés:** Uso orgánico y diverso de tags (etiquetas).
  - **Competencia:** % de avance promedio de KRs globales.
  - **Lucidez:** Días de estudio (`time_sessions`).
- Reemplaza los datos 'mock' del Radar central por estos valores reales generados día a día.

---

## 🚦 Guía de Pruebas: The Happy Path

Este es el paso a paso exacto para comprobar que todos los hilos del MVP están interconectados y fluyendo:

### Escenario A: Progreso Atómico y Dopamina en Vivo
1. Asegúrate de tener al menos una **Etiqueta** (Ej: `#ingles` o `#programacion`).
2. Verifica tener un **Objective** cualquiera, y dentro de él, crea un **Key Result (KR)** de métrica `COUNT_ATOMIC` (Por ejemplo, un objetivo de llegar a 50). Asígnale explícitamente el peso a la etiqueta creada (Ej: `#ingles` peso 1).
3. Entra a la App (Home/Kanban) y **Crea una Tarea**, asociándole la misma etiqueta.
4. Mueve la tarea a **"In Progress"** y luego márcala como **"Done"**.
5. **Comprobación Inmediata:**
   - Sin tener que recargar, debe aparecer un `Toast` verde 🏆 felicitándote por haber ganado progreso.
   - Si abres la ventana lateral del Chat, verás a la IA felicitándote.
   - Tu campana 🔔 en el Header debería tener una notificación que se autocompletó (si lo dejaste así configurado).

### Escenario B: Atomizar Tareas de forma TDAH-First
1. Escribe o selecciona una tarea grande y difícil en el Kanban (Ej: "Investigar arquitecturas").
2. Succionada hacia el Sidebar/Chat, dile a la IA: *"Atomiza mi tarea elegida"*.
3. La IA debe invocar la función _Call Tool (`atomizeTask`)_ y proponer exactamente de 1 a 3 acciones subatómicas, con verbos claros.
4. **Comprobación:** Deben haber aparecido 3 tareas atómicas nuevas en tu Kanban "Backlog" heredando las etiquetas de su tarea madre de forma silenciosa.

### Escenario C: Ver tu Radar Brillando
1. Ve al engranaje (Profile) o modal de **Analytics**.
2. Dale a la Pestaña **KPIs**.
3. **Comprobación:** Deberás ver el Radar Chart ya no con un "Cargando", sino dibujando un polígono orgánico que refleja las Tareas ("Agencia") y Sesiones formales que hayas cursado según el RPC.

### Escenario D: Sincronización Zettelkasten (Deno Edge Function)
1. Inicia sesión en tu terminal / Postman o en el mismo Storage Dashboard de UI Supabase remota o local en `storage.objects`.
2. Sube un archivo `.md` (ejemplo `apuntes.md`) cargado con un header YAML inicial: `title: "Lo de hoy" \n tags: ["#dev"]`.
3. **Comprobación:** Revisa la base de datos `notes`. Automáticamente debería haberse parseado y guardado la nota "Lo de hoy" indexando sus tags por culpa del webhook interno.
