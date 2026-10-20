<script setup lang="ts">
const supabase = useSupabaseClient();
const route = useRoute();
const router = useRouter();

const loading = ref(true);
const error = ref<string | null>(null);

const toast = useToast();

async function handleDriveTokensIfPresent(session: any) {
  if (route.query.connect_drive === "true" && session) {
    if (session.provider_token || session.provider_refresh_token) {
      try {
        await $fetch("/api/auth/google-drive-tokens", {
          method: "POST",
          body: {
            accessToken: session.provider_token,
            refreshToken: session.provider_refresh_token,
            expiryDate: session.expires_at ? session.expires_at * 1000 : undefined,
          },
        });
        toast.add({
          title: "Google Drive conectado",
          description: "Tu cuenta de Google Drive ha sido vinculada exitosamente",
          icon: "i-lucide-check-circle",
          color: "success",
        });
      } catch (err: any) {
        console.error("[Callback] Error storing Drive tokens:", err);
        toast.add({
          title: "Error al vincular Drive",
          description: err?.message || "No se pudieron guardar las credenciales",
          icon: "i-lucide-alert-circle",
          color: "error",
        });
      }
    }
  }
}

onMounted(async () => {
  try {
    // Check for OTP verification (magic link flow)
    const token_hash = route.query.token_hash as string;
    const type = route.query.type as string;
    const source = route.query.source as string;

    if (token_hash && type) {
      const { error: verifyError } = await supabase.auth.verifyOtp({
        token_hash,
        type: type as any,
      });
      if (verifyError) throw verifyError;

      router.push({
        path: "/",
        query: route.query,
      });
      return;
    }

    // For OAuth flows, check session immediately
    const { data: { session } } = await supabase.auth.getSession();
    if (session) {
      await handleDriveTokensIfPresent(session);
      const cleanQuery = { ...route.query };
      delete cleanQuery.connect_drive;
      router.push({
        path: "/",
        query: cleanQuery,
      });
      return;
    }

    const user = useSupabaseUser();
    if (user.value) {
      const cleanQuery = { ...route.query };
      delete cleanQuery.connect_drive;
      router.push({
        path: "/",
        query: cleanQuery,
      });
      return;
    }

    // If no user yet, wait for auth state change
    const { data: listener } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (event === "SIGNED_IN" || session) {
          listener.subscription.unsubscribe();
          if (session) {
            await handleDriveTokensIfPresent(session);
          }
          const cleanQuery = { ...route.query };
          delete cleanQuery.connect_drive;
          router.push({
            path: "/",
            query: cleanQuery,
          });
        }
      },
    );
  } catch (e: any) {
    error.value = e.message || "Error al iniciar sesión.";
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="flex items-center justify-center min-h-screen">
    <div v-if="error" class="text-center">
      <p class="text-red-500">{{ error }}</p>
      <NuxtLink to="/landing" class="text-sm underline mt-2 block">
        Volver al inicio
      </NuxtLink>
    </div>
    <div v-else class="text-center">
      <p class="text-muted">Verificando sesión...</p>
    </div>
  </div>
</template>
