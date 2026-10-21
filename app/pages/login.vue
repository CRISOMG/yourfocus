<template>
  <div class="flex items-center justify-center h-screen">
    <LoginContainer />
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  middleware: [
    async (to, from) => {
      const { data } = await useSupabaseClient().auth.getSession();

      if (data.session) {
        const nuxtApp = useNuxtApp();
        const locale = nuxtApp.$i18n?.locale?.value || "es";
        return navigateTo(locale === "en" ? "/en/home" : "/es/inicio");
      }
    },
  ],
});
</script>
