# Feature Template: Single Source of Truth

> Plantilla estratégica basada en el [Paradigma Integrado de Planificación y Diseño](../../convenions/planning_and_design/index.md) y la [Constitución de YourFocus](../../../.specify/memory/constitution.md).
> Este documento actúa como contrato vivo entre TPM y TPE para la evolución del Chat.

---

## Metadata

| Campo                    | Valor                                                                |
| ------------------------ | -------------------------------------------------------------------- |
| **Feature / Módulo**     | Chat Dual Mode (Journal vs AI Agent) & Audio Resource Management     |
| **Estado**               | `Approved` (En Implementación)                                       |
| **Owner**                | Cris (TPM / TPE)                                                     |
| **Dominio (DDD)**        | Segundo Cerebro / Captura Cognitiva & Multimedia                     |
| **Módulo (Bounded Ctx)** | Asistencia de Chat & Bitácora de Voz                                 |
| **Fecha de creación**    | 2026-10-19                                                           |
| **Última actualización** | 2026-10-19                                                           |
| **Sprint / Ciclo**       | Sprint: Experiencia de Captura TDAH-First                            |

---

## 1. Capa de Descubrimiento (Contexto de Negocio) — TPM

### User Stories

```
US-01 (Modo Bitácora sin Interrupciones):
Como usuario con TDAH en ráfaga creativa o de reflexión,
quiero poder desactivar las respuestas automáticas del agente mediante un toggle en el chat,
para registrar notas de texto y bitácoras de voz como un diario o bloc de notas limpio, sin que la IA responda inmediatamente ni me genere fatiga cognitiva.
```

```
US-02 (Procesamiento Asíncrono "Append Agent Response"):
Como usuario que revisa su historial de notas previas no procesadas,
quiero pulsar un botón "Append Agent Response" en un mensaje específico,
para solicitarle al agente que procese únicamente esa entrada e inserte la respuesta justo debajo de ella sin desordenar la línea de tiempo.
```

```
US-03 (Compartir y Descargar Recursos de Audio de Supabase):
Como usuario que graba bitácoras de voz en la app,
quiero generar enlaces compartibles con tiempo de expiración configurable (o permanente) y poder descargar el audio directamente,
para compartir mis notas con terceros o respaldarlas fuera de la plataforma sin temor a que el enlace firmado expire a los 60 minutos.
```

### Problema a Resolver

1. **Sobrecarga de Interacción para TDAH**: A veces el usuario solo necesita volcar pensamientos ("brain dump") o notas de audio sin la presión de entablar una conversación interactiva con el modelo de lenguaje.
2. **Pérdida de Contexto Temporal**: Si el usuario escribe notas y más tarde quiere que el agente las analice, un chat tradicional solo permite responder al final del hilo, descontextualizando la respuesta de la nota original.
3. **Enlaces de Audio Efímeros en Storage Privado**: El bucket `yourfocus` es privado y genera URLs firmadas de 1 hora que caducan, impidiendo compartir audios con colegas o descargarlos de forma sencilla.

### KPI / Métricas de Éxito

| Métrica                                | Valor objetivo         | Método de medición                                  |
| -------------------------------------- | ---------------------- | --------------------------------------------------- |
| **Reducción de consumo de tokens innecesarios** | ≥ 30% en sesiones de notas | Comparativa de llamadas a `/api/chat` vs `/api/chat/journal` |
| **Tasa de éxito en Append Response**   | 100% orden cronológico | Verificación de orden topológico padre/hijo en UI   |
| **Disponibilidad de enlaces de audio** | 100% enlaces válidos   | Signed URLs generadas según TTL solicitado          |

---

## 2. Capa de Definición (Requerimientos) — Bridge TPM ↔ TPE

### Requerimientos Funcionales (RF)

| ID    | Descripción | Prioridad |
| ----- | ----------- | --------- |
| RF-01 | El chat debe incluir un botón de configuración con menú desplegable (`UDropdownMenu`) que contenga un switch/toggle para activar o desactivar las respuestas del agente (`isAgentActive`). | Alta |
| RF-02 | El estado del toggle debe persistirse en `localStorage` para recordar la preferencia del usuario. | Media |
| RF-03 | Si el agente está desactivado, el envío de texto o audios debe persistir el mensaje directamente en Supabase y agregarlo a la UI sin invocar la generación LLM (`streamText`). | Alta |
| RF-04 | Cada mensaje del usuario que no cuente con una respuesta del asistente asociada debe mostrar un botón de acción `"Append Agent Response"` (o ícono contextual). | Alta |
| RF-05 | Al pulsar `"Append Agent Response"`, el sistema debe invocar al agente para procesar ese mensaje específico e insertar la respuesta del asistente visualmente y en base de datos inmediatamente debajo del mensaje de origen, sin descolocar el resto de la cronología. | Alta |
| RF-06 | Cada recurso de audio en el chat debe ofrecer un menú para: (a) generar enlace firmado con expiración elegible (1h, 24h, 7d, 30d, Permanente/1 año), (b) copiar enlace al portapapeles con toast, y (c) descargar el archivo de audio directamente al dispositivo. | Alta |

### Requerimientos No Funcionales (RNF)

| Categoría         | Descripción | Criterio |
| ----------------- | ----------- | -------- |
| **Performance**   | El guardado en modo bitácora no debe esperar streaming | Latencia < 200ms en el guardado |
| **Seguridad**     | Todo enlace generado de audio debe verificar permisos de usuario | Solo el dueño del archivo puede generar el signedUrl |
| **Consistencia**  | El reordenamiento cronológico de respuestas diferidas debe persistir tras recargar | `reply_to_id` enlazado en base de datos |

### Criterios de Aceptación

- [x] Toggle accesible en el prompt del chat con feedback visual del modo activo (Bitácora vs Asistente).
- [x] Mensajes enviados en modo Bitácora se guardan en la DB y aparecen inmediatamente sin respuesta del bot.
- [x] Botón "Append Agent Response" visible en mensajes sin respuesta.
- [x] Respuesta diferida se ubica justo después del mensaje seleccionado.
- [x] Modal o menú de audio con generación de enlace firmado por TTL y descarga directa.

---

## 3. Capa de Especificación (BDD & Comportamiento) — TPE

### Escenarios BDD (Gherkin)

```gherkin
Feature: Chat Dual Mode y Gestión de Audios

  Scenario: Enviar mensaje en Modo Bitácora
    Given que el usuario tiene el toggle "Respuestas del Agente" desactivado
    When escribe una reflexión y pulsa Enviar
    Then el mensaje se guarda en Supabase
    And aparece inmediatamente en la lista de mensajes
    And el agente NO responde ni genera streaming
    And el mensaje muestra la opción "Append Agent Response"

  Scenario: Generar respuesta diferida bajo un mensaje anterior
    Given un mensaje M1 del usuario creado en la posición 2 sin respuesta
    And un mensaje M2 posterior en la posición 3
    When el usuario pulsa "Append Agent Response" sobre M1
    Then se invoca al agente para procesar M1
    And la respuesta del asistente se inserta en la posición 3 (justo tras M1)
    And el mensaje M2 pasa a la posición 4
    And al recargar la página la respuesta permanece vinculada bajo M1

  Scenario: Generar enlace compartido de audio con expiración
    Given un mensaje que contiene un audio grabado
    When el usuario abre el menú del audio y selecciona "Compartir enlace"
    And elige una caducidad de 7 días
    Then se genera un signed URL de Supabase con 604800 segundos de validez
    And el link se copia al portapapeles con confirmación Toast
```

---

## 4. Capa de Ingeniería y Arquitectura

### Modelo de Datos
- Modificación en `n8n_chat_histories.message`:
  - `reply_to_id?: string | number`: Identificador del mensaje de usuario al que responde.
  - Al consultar en `server/api/chat.get.ts`, se ejecuta un algoritmo de reordenamiento que intercala las respuestas debajo de su correspondiente `reply_to_id`.

### Endpoints
1. `POST /api/chat/journal`: Inserta el mensaje del usuario en `n8n_chat_histories` sin llamar a Gemini.
2. `POST /api/chat`: Soporta parámetro opcional `replyToMessageId` para asociar la respuesta en `onFinish`.
3. `POST /api/audio/share`: Recibe `{ audioPath, expiresIn, download }` y genera un signedUrl en el bucket `yourfocus`.
4. `POST /api/audio/upload`: Recibe el archivo de audio (.mp3 o .webm) y lo registra en la base de datos de jornada.

### Conversión de Audio en Cliente
- Módulo `app/utils/audio-converter.ts` usando `@breezystack/lamejs` y Web Audio API.
- Convierte por defecto a MP3 a 128 kbps antes de subir a Supabase Storage.
- Fallback automático a WebM ante cualquier error de decodificación o entorno.

---

## 5. Roadmap de Implementación

- [x] **Fase 1**: Endpoint `POST /api/audio/share` y componente de menú de audio (enlace + descarga).
- [x] **Fase 2**: Composable `useChatPreferences`, toggle en UI de chat y endpoint `POST /api/chat/journal`.
- [x] **Fase 3**: Lógica de `reply_to_id`, algoritmo de intercalación en `chat.get.ts` y botón "Append Agent Response".
- [x] **Fase 4**: Resolución de persistencia de secuencia Postgres (`n8n_chat_histories_id_seq1`), streaming SSE y auto-scroll.
- [x] **Fase 5**: Feedback visual silencioso (loading en chat prompt/submit sin snackbars intrusivos).
- [x] **Fase 6**: Conversión en cliente a MP3 con `@breezystack/lamejs` y suite de pruebas unitarias.
