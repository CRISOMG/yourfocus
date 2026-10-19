# Sesión: Chat Modo Dual (Agente / Bitácora), Append Response y Conversión de Audio MP3

**Fecha:** 2026-10-19  
**Duración aprox:** ~4h  
**Objetivo:** Implementar modo dual en el chat (Asistente ON vs Bitácora de notas), respuestas diferidas del agente ("Append Agent Response"), compartición y descarga de audios con enlaces firmados de Supabase Storage, resolución de problemas de persistencia y auto-scroll, y conversión nativa de audios a MP3 en el cliente con `@breezystack/lamejs`.

---

## 1. Contexto y Requerimientos

1. **Flujo de chat dual:**
   * Selector / Dropdown en el prompt para alternar entre **Modo Asistente** (el agente responde automáticamente) y **Modo Bitácora** (las notas y audios se guardan en la base de datos sin disparar generación de IA).
   * Estado persistente con `useChatPreferences` (`localStorage` + `useState`).
2. **Respuestas diferidas sin romper la línea de tiempo:**
   * Para notas de bitácora no procesadas por el agente, mostrar un botón `"Append Agent Response"`.
   * Al hacer clic, invocar al agente con el contexto histórico hasta ese mensaje y colocar la respuesta inmediatamente debajo de dicho mensaje.
3. **Compartición de recursos de audio:**
   * Menú en los avatares de audio para generar enlaces firmados de Supabase Storage (1 hora, 24 horas, 7 días o permanente ~5 años) y descarga directa.
4. **Problemas reportados durante las pruebas:**
   * Al enviar notas en modo bitácora, el contenedor no bajaba automáticamente (se requería scroll manual).
   * Al presionar "Append Agent Response", la respuesta se veía en DevTools pero, al refrescar `GET /api/chat`, desaparecían tanto la nota como la respuesta del agente.
   * La notificación emergente (snackbar/toast) tras cada mensaje en bitácora resultaba intrusiva; se solicitó reemplazarla por un estado de carga (*loading*) directo en el chat y en el input.
5. **Almacenamiento y exportación de audios por defecto en MP3:**
   * Conversión en el cliente de WebM/Opus a MP3 mediante `@breezystack/lamejs` compatible con Vercel Serverless, con fallback transparente a WebM para no bloquear el flujo de grabación.
6. **Factibilidad de exportación a Google Drive privado:**
   * Análisis técnico para exportar audios a la cuenta de Google Drive del usuario sin acceso para terceros.

---

## 2. Diagnóstico Técnico de Problemas y Causas Raíz

### A. Desaparición de mensajes en `GET /api/chat`
* **Causa principal:** Desfase en la secuencia de identidad de Postgres en `n8n_chat_histories` (`n8n_chat_histories_id_seq1`). La secuencia estaba en `54`, mientras que la tabla contenía registros históricos hasta el ID `1325`. Al insertar una nota de bitácora, Postgres le asignaba ID `55`.
* Como `GET /api/chat` consulta `WHERE session_id = ... ORDER BY id DESC LIMIT 40`, el límite tomaba los mensajes más altos (1285-1325), dejando fuera los registros con ID menor.
* **Causa secundaria (Protocolo SSE):** `streamText(...).toUIMessageStreamResponse()` en Vercel AI SDK v6 utiliza el formato Server-Sent Events (`data: {"type":"text-delta","delta":"..."}`), mientras que el lector en el frontend esperaba el formato legacy de AI SDK v3 (`0:...`).
* **Causa terciaria (Condición de carrera):** `onFinish` en el servidor persistía la respuesta de forma asíncrona; `await refresh()` en el cliente se disparaba inmediatamente al cerrar el stream antes de que el `INSERT` completara el commit en base de datos.

### B. Auto-scroll en modo Bitácora
* `UChatMessages` de `@nuxt/ui` solo realiza scroll automático cuando `chat.status === 'streaming'`. Al hacer push local a `chat.messages`, no se disparaba el desplazamiento.

---

## 3. Decisiones de Diseño

| Decisión | Opción Elegida | Razón |
| :--- | :--- | :--- |
| **Conversión de Audio a MP3** | En el cliente (Navegador) con Web Audio API + `@breezystack/lamejs` | Cero costo de servidor, compatible 100% con Vercel Serverless (sin problemas de límites de 50MB ni timeouts de 10s de FFmpeg). |
| **Manejo de Fallback de Audio** | Detección de fallos con retorno del `Blob` original WebM | Si el navegador no soporta `AudioContext` o el stream falla, el audio se sube como WebM sin bloquear al usuario. |
| **Integridad de Secuencia DB** | Helper `insertChatHistory` con recuperación automática de colisiones (`23505`) | Si la secuencia se desincroniza de `MAX(id)`, se resincroniza automáticamente en tiempo de ejecución. |
| **Intercalado de Respuestas** | Reordenamiento topológico en `server/api/chat.get.ts` por `reply_to_id` | Mantiene el historial en orden cronológico real intercalando las respuestas diferidas exactamente bajo el mensaje padre. |
| **Feedback de Bitácora** | Loading en `UChatPrompt`, `UChatPromptSubmit` y banner sutil en chat; sin toasts | Experiencia silenciosa y fluida sin saturar al usuario con snackbars repetitivos. |

---

## 4. Cambios Realizados

### Nuevos Módulos y Archivos

| Archivo | Propósito |
| :--- | :--- |
| `app/utils/audio-converter.ts` | Utilidad de decodificación PCM nativa (`AudioContext`) y codificación MP3 pura con `@breezystack/lamejs`, con tipado estricto y fallback. |
| `app/composables/useChatPreferences.ts` | Estado reactivo global (`isAgentActive`, `toggleAgent`) con persistencia en `localStorage`. |
| `server/api/audio/share.post.ts` | Endpoint seguro para generar signed URLs de Supabase Storage con TTL configurable (1h, 24h, 7d, permanente) y flag de descarga. |
| `server/api/chat/journal.post.ts` | Endpoint para persistir notas de bitácora directamente en `n8n_chat_histories` usando SQL directo y `insertChatHistory`. |
| `docs/features/chat_dual_mode_and_audio_sharing/feature_chat_dual_mode_and_audio_sharing.md` | Especificación formal del feature (SDD). |
| `test/unit/utils/audio-converter.test.ts` | Suite de pruebas unitarias para la conversión de audio, detección de formato y fallbacks. |

### Archivos Modificados

| Archivo | Cambios Principales |
| :--- | :--- |
| `server/utils/messages-db.ts` | Se añadieron las funciones `insertChatHistory` y `syncChatHistoriesSequence` para prevenir colisiones de ID y asegurar ordenación. |
| `server/api/chat.get.ts` | Soporte para extraer `parts`, `reply_to_id`, normalización de `userId` (`id || sub`) e intercalado topológico de respuestas diferidas. |
| `server/api/chat.post.ts` | Soporte para `replyToMessageId`, lectura de `usePro` en el body, persistencia mediante `insertChatHistory` y streaming SSE compatible con AI SDK v6. |
| `server/api/audio/upload.post.ts` | Normalización de `userId` (`(user as any).id || (user as any).sub`). |
| `app/components/containers/chat-container.vue` | Inclusión de `scrollContainerRef`, funciones `scrollToBottom`, eliminación del toast de guardado, incorporación de spinners de carga en `UChatPrompt` y `UChatPromptSubmit`, banner `Guardando en bitácora...`, y decodificación de chunks SSE (`data: `). |
| `app/components/UserMessage.vue` | Badge identificador `"Bitácora (sin procesar)"` y botón `"Append Agent Response"` con estado de carga. |
| `app/components/FileAvatar.vue` | Menú desplegable para compartir enlaces firmados y descarga directa de audio con extensión `.mp3` por defecto. |
| `app/components/AudioRecorderButton.vue` | Integración de `convertBlobToMp3` para enviar audios como MP3 a Supabase Storage con fallback a WebM. |
| `app/pages/index.vue` | Grabación de micrófono de la barra inferior con conversión a MP3 antes de la subida a Supabase Storage. |
| `app/composables/useFileUpload.ts` | Conversión automática a MP3 para archivos de audio adjuntos en WebM/OGG. |

---

## 5. Pruebas y Verificación

1. **Pruebas unitarias (`vitest run test/unit`):**
   * `audio-converter.test.ts` (4 pruebas passing):
     * Retorno intacto de audios que ya son MP3.
     * Fallback transparente si `AudioContext` no existe.
     * Fallback ante corrupción de audio.
     * Codificación exitosa de PCM a MP3 (`audio/mpeg`).
   * `pomodoro-domain.test.ts` (6 pruebas passing).
   * **Total: 10 pruebas exitosas.**

2. **Compilación y tipado Nuxt:**
   * `nuxt prepare` ejecutado con éxito, sin errores de TypeScript.

3. **Verificación en Base de Datos:**
   * Secuencia `n8n_chat_histories_id_seq1` sincronizada al valor actual (`> 1325`), garantizando que los mensajes se listen siempre en las primeras 40 posiciones.

---

## 6. Siguiente Paso Planificado: Exportación a Google Drive Privado

* **Opción Recomendada:** Crear endpoint `POST /api/audio/export-drive` utilizando las credenciales de Service Account existentes en `runtimeConfig.google`.
* **Seguridad:** Restringir el endpoint estrictamente al ID/correo del usuario autorizado y otorgar permisos de acceso exclusivos a su cuenta en Google Drive.
