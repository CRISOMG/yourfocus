# Sesión: Exportación de Audios a Google Drive (OAuth2 Delegado, Auto-Export y Aislamiento)

**Fecha:** 2026-10-20  
**Duración aprox:** ~2.5h  
**Objetivo:** Implementar la exportación bajo demanda y automática de notas de audio a la carpeta personal de Google Drive del usuario propietario (`DRIVE_FOLDER_ID`), garantizando aislamiento y privacidad absoluta (403 Forbidden para cualquier otro usuario), almacenamiento cifrado de tokens OAuth2 mediante AES-256-GCM en la bóveda de Supabase (`user_secrets`), y experiencia de usuario fluida con toogle de auto-exportación y opciones en el avatar de audio.

---

## 1. Contexto y Requerimientos

1. **Exportación Bajo Demanda en el Avatar de Audio:**
   * En el menú desplegable de acciones del audio (`FileAvatar.vue`), añadir la opción **"Exportar a Google Drive"** con su icono correspondiente.
   * Mostrar retroalimentación de carga durante la exportación y notificación toast con acción directa para abrir el archivo subido en Google Drive (`webViewLink`).

2. **Auto-Exportación Configurable (Toggle en el Chat):**
   * Incorporar un control en el menú de configuración del prompt (`chatConfigItems` en `chat-container.vue`) para activar o desactivar la exportación automática de audios a Google Drive.
   * Si está activo, cualquier nota de audio grabada o subida se enviará asíncronamente a Google Drive tras guardarse en Supabase Storage, sin bloquear la interfaz ni el flujo de conversación del usuario.

3. **Aislamiento y Privacidad Estricta (RBAC & Sandbox):**
   * La funcionalidad de Google Drive está restringida de forma inviolable al propietario (`cristiancaraballo112@gmail.com` / UID `4ddb8909-ef46-4cde-8feb-8ce0a3c72564`). Cualquier petición de otro usuario es rechazada con `403 Forbidden`.
   * Los archivos solo pueden extraerse de la ruta propia del usuario en el bucket `yourfocus` (`${userId}/...`), previniendo secuencias de path traversal (`..`).

---

## 2. Diagnóstico Técnico y Hallazgos Clave

### Limitación de Service Accounts en Cuentas Personales de Google (@gmail.com)
* Inicialmente se evaluó usar la Service Account configurada en el proyecto (`GOOGLE_CLIENT_EMAIL`).
* **Error identificado:** Al ejecutar `drive.files.create` con la Service Account apuntando a una carpeta compartida de un correo personal `@gmail.com`, Google rechaza la creación con el error:  
  `GaxiosError: 403 Forbidden: Service Accounts do not have storage quota. Leverage shared drives or use OAuth delegation instead.`
* **Causa raíz:** En cuentas estándar personales de Google (@gmail.com) no existen *Shared Drives* empresariales. Google considera a la Service Account como creadora/propietaria del archivo, y dado que las Service Accounts en GCP tienen cuota de almacenamiento personal de 0 MB, la subida es bloqueada por la API de Google.
* **Solución adoptada (OAuth2 Delegado):** Conectar la cuenta personal de Google Drive de Cristian mediante OAuth2 con scope restringido (`https://www.googleapis.com/auth/drive.file`). De este modo, los archivos se crean directamente a nombre del usuario, consumen su cuota de 15 GB y se depositan de manera natural en la carpeta designada (`1l4jeHY9VN-ihIVdS-T_4kzxfgVB-_2Pd`).

---

## 3. Decisiones de Diseño y Arquitectura

| Decisión | Opción Elegida | Razón |
| :--- | :--- | :--- |
| **Flujo de Autorización OAuth2** | Supabase OAuth + Scopes de Google Drive | Reutiliza el Client ID y Secret existentes en `.env` sin necesidad de exponer nuevas URLs ni configurar servidores OAuth adicionales. |
| **Cifrado de Credenciales** | AES-256-GCM en `user_secrets` con clave derivada de `SUPABASE_JWT_SECRET` | Almacenamiento seguro "at-rest" de tokens de refresco y acceso; los tokens nunca se exponen al cliente en texto plano. |
| **Refresco Automático de Tokens** | Escuchador `oauth2Client.on('tokens')` | Mantiene la sesión de Google Drive viva indefinidamente sin requerir que el usuario vuelva a iniciar sesión constantemente. |
| **Toggle de Preferencia** | `useChatPreferences` con `localStorage` | Sincronización instantánea entre pestañas y componentes sin dependencias complejas. |
| **Ejecución No Bloqueante** | Auto-exportación en segundo plano (`Promise.catch`) | Si la conexión con Google Drive tarda o experimenta latencia, el usuario puede seguir escribiendo o reproduciendo audios con fluidez. |

---

## 4. Cambios Realizados

### Nuevos Módulos y Archivos

| Archivo | Propósito |
| :--- | :--- |
| `server/utils/google-drive-auth.ts` | Utilidad central de autenticación y autorización: validación de rol de propietario, cifrado/descifrado de tokens en `user_secrets`, y creación de cliente `OAuth2Client` con auto-renovación de credenciales. |
| `server/api/auth/google-drive-tokens.post.ts` | Endpoint seguro para recibir y almacenar los tokens OAuth de Google Drive cifrados en la base de datos. |
| `server/api/audio/drive-status.get.ts` | Endpoint para consultar el estado de conexión de Google Drive del usuario actual. |
| `server/api/audio/drive-status.delete.ts` | Endpoint para desconectar la integración y desactivar las credenciales almacenadas. |
| `server/api/audio/export-drive.post.ts` | Endpoint para descargar el audio desde Supabase Storage (`yourfocus`) y subirlo a la carpeta de Google Drive configurada en `DRIVE_FOLDER_ID`. |
| `app/composables/useGoogleDrive.ts` | Composable reactivo de cliente para verificar estado, disparar OAuth2 (`signInWithOAuth`), desconectar y solicitar exportación a Drive con toasts informativos. |
| `test/unit/utils/google-drive-auth.test.ts` | Pruebas unitarias de autorización RBAC (rechazo 401/403 a no autorizados) y verificación de cifrado/descifrado AES-256-GCM. |

### Archivos Modificados

| Archivo | Cambios |
| :--- | :--- |
| `nuxt.config.ts` | Añadido `clientId` y `clientSecret` a `runtimeConfig.google` para que el servidor pueda instanciar el cliente OAuth2. |
| `server/utils/vault.ts` | Exportada la interfaz `EncryptedPayload` y añadido soporte para leer `SUPABASE_JWT_SECRET` desde el entorno o `runtimeConfig`. |
| `app/pages/callback/index.vue` | Captura de `provider_token` y `provider_refresh_token` tras el callback de OAuth cuando `connect_drive === 'true'` para persistirlos de forma segura. |
| `app/composables/useChatPreferences.ts` | Añadido estado `isAutoExportDriveActive`, persistencia en `localStorage` y helpers de alternancia (`toggleAutoExportDrive`). |
| `app/components/FileAvatar.vue` | Añadida opción "Exportar a Google Drive" en el menú de audio con spinner de carga y toast interactivo para abrir el archivo. |
| `app/components/containers/chat-container.vue` | Integrado estado y menú de Google Drive en `chatConfigItems`, verificación de estado al montar y disparador automático de exportación en `handleAudioUploaded` y `handleFilesSelected`. |

---

## 5. Pruebas y Validación

1. **Tipado Estático:**  
   * Ejecutado `npx tsc --noEmit` resultando en **0 errores de compilación**.
2. **Seguridad y Bóveda Criptográfica:**  
   * Verificación unitaria de derivación de claves SHA-256 y cifrado/descifrado autenticado AES-256-GCM de payloads de tokens.
   * Comprobación estricta de control de acceso: los usuarios que no coinciden con `cristiancaraballo112@gmail.com` reciben `403 Forbidden`.
3. **Manejo de Errores y Robustez:**  
   * Prevención de fallos silenciosos: en caso de que Google Drive no esté conectado, el usuario recibe un toast contextual con un botón de acción para vincularlo inmediatamente.
