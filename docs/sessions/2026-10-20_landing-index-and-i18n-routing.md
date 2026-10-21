# Sesión: Landing como Index e Internacionalización de Rutas del Home (/es/inicio y /en/home)

**Fecha:** 2026-10-20  
**Objetivo:** Configurar la landing page pública como la ruta raíz (`/`), manteniendo su acceso abierto sin requerir autenticación; detectar sesiones activas en la landing para mostrar un botón/CTA directo al espacio de trabajo; y soportar enrutamiento localizado con i18n para la aplicación (`/es/inicio` en español y `/en/home` en inglés).

---

## 1. Contexto y Requerimientos

1. **Landing Page en la Raíz (`/`):**
   * La landing page (`app/pages/landing/index.vue`) pasa a ser la página principal en `/` (`app/pages/index.vue`).
   * Los visitantes no autenticados pueden explorar la landing en `/` (español) y `/en` (inglés) libremente, sin ser redirigidos forzosamente a `/login`.
   * Las visitas a la ruta anterior `/landing` se redirigen permanentemente (HTTP 301) a `/` preservando parámetros de consulta (`query params`).

2. **Detección de Sesión Activa:**
   * Cuando un usuario con sesión abierta en Supabase (`useSupabaseUser` / `useSupabaseSession`) visita la landing, se detecta el estado reactivamente.
   * Se muestra de manera contextual y elegante un botón de acceso directo al espacio de trabajo ("Ir al inicio" / "Go to Home"):
     * En la barra de navegación superior (desktop y drawer móvil).
     * En la sección Hero (reemplazando el formulario de Magic Link por un saludo con el correo activo y botón destacado).
     * En la sección final de llamada a la acción (CTA inferior).

3. **Internacionalización Dinámica de Rutas:**
   * La aplicación principal (anteriormente en `index.vue`) se ubica en `app/pages/inicio.vue`.
   * En español (`locale === 'es'`), la ruta canónica de la app es `/es/inicio` (con alias `/inicio`).
   * En inglés (`locale === 'en'`), la ruta canónica de la app es `/en/home` (con alias `/home`).
   * Enlaces en cabecera (`AppHeader.vue`), callbacks de autenticación (`callback/index.vue`), controladores de login (`login.vue`, `use-auth-controller.ts`) y selector de idioma en la landing respetan estas rutas según el idioma activo.

---

## 2. Arquitectura y Decisiones de Diseño

| Decisión | Implementación | Razón |
| :--- | :--- | :--- |
| **Estrategia Nuxt i18n** | `strategy: "prefix_and_default"` con mapping de páginas personalizado | Permite que `/` sea la raíz por defecto en español, `/en` la landing en inglés, y que la aplicación se exponga como `/es/inicio` o `/en/home` limpiamente. |
| **Protección de Rutas en Supabase** | `include: ["/inicio*", "/es/inicio*", "/en/home*", "/home*", "/note/:path*"]` y `exclude: ["/", "/es", "/en", "/landing*"]` | Evita que el middleware global de Supabase intercepte la landing pública, asegurando al mismo tiempo que la aplicación privada requiera inicio de sesión. |
| **Redirección de `/landing`** | `definePageMeta` con middleware de redirección 301 a `/` | Mantiene compatibilidad con marcadores, enlaces externos y campañas previas que apuntaban a `/landing`. |
| **Cambio de Idioma en Landing** | `useSwitchLocalePath()` y `navigateTo()` | Garantiza que al alternar entre EN y ES en la landing, la URL cambie correctamente entre `/` y `/en` en el navegador. |
| **Logo de AppHeader** | Enlace computado `homePath` (`/es/inicio` o `/en/home`) | Asegura que al hacer clic en el logo dentro de la aplicación, el usuario vuelva al dashboard principal correspondiente a su idioma. |

---

## 3. Resumen de Cambios

### Archivos Modificados y Creados

* **`app/pages/inicio.vue` (Nuevo):**
  * Contiene la aplicación principal (temporizador Pomodoro, Bitácora de chat y notas de voz, reproductor de audio, etc.).
  * Registra `defineI18nRoute({ paths: { es: "/inicio", en: "/home" } })` y `definePageMeta({ layout: "default", alias: ["/home"] })`.

* **`app/pages/index.vue`:**
  * Implementa la landing completa en la raíz con layout `landing`.
  * Detecta reactivamente sesiones mediante `hasActiveSession = computed(() => !!user.value || !session.value)`.
  * Calcula la ruta destino `homeTargetUrl = computed(() => locale.value === 'en' ? '/en/home' : '/es/inicio')`.
  * Expone botones de acceso al inicio en navbar, drawer móvil, hero y footer CTA.
  * Integra `useSwitchLocalePath` en `toggleLocale`.

* **`app/pages/landing/index.vue`:**
  * Reemplazado por un redireccionador HTTP 301 inmediato hacia `/`.

* **`nuxt.config.ts`:**
  * Configurado `i18n.strategy = "prefix_and_default"` y `i18n.pages.inicio = { es: "/inicio", en: "/home" }`.
  * Actualizado `supabase.redirectOptions` protegiendo `/inicio*`, `/es/inicio*`, `/en/home*`, `/home*` y excluyendo `/`, `/es`, `/en`, `/landing*`.

* **`app/components/AppHeader.vue`:**
  * El logo redirige a `locale.value === 'en' ? '/en/home' : '/es/inicio'`.

* **`app/pages/callback/index.vue`, `app/pages/login.vue`, `app/composables/use-auth-controller.ts`:**
  * Los flujos de autenticación exitosa redirigen al home localizado (`targetHome`).

* **`i18n/locales/es.json` y `i18n/locales/en.json`:**
  * Nuevas traducciones para botones y avisos de sesión activa (`landing.nav.goHome`, `landing.hero.goHome`, `landing.hero.signedInAs`).

---

## 4. Verificación y Pruebas Realizadas

1. **Rutas HTTP y Códigos de Estado:**
   * `curl -s -I http://localhost:3000/` $\rightarrow$ `200 OK` (Landing en español).
   * `curl -s -I http://localhost:3000/en` $\rightarrow$ `200 OK` (Landing en inglés).
   * `curl -s -I http://localhost:3000/landing` $\rightarrow$ `301 Moved Permanently` (Redirige a `/`).
   * `curl -s -I http://localhost:3000/es/inicio` $\rightarrow$ `302 Found` (Redirige a `/login` al no estar autenticado).
   * `curl -s -I http://localhost:3000/en/home` $\rightarrow$ `302 Found` (Redirige a `/login` al no estar autenticado).

2. **Tipado y Compilación TypeScript:**
   * `npx tsc --noEmit` completado con 0 errores de tipado en toda la solución.

3. **Renderizado Visual:**
   * Verificación de la landing page con selector de idioma, navegación interactiva y adaptación responsiva.
