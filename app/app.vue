<template>
  <UApp>
    <NuxtRouteAnnouncer />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>

<script setup lang="ts">
const supabase = useSupabaseClient()
onMounted(() => {
  defineShortcuts({
    "s-o": () => {
      confirm("Are you sure you want to sign out?") && supabase.auth.signOut()
    }
  })
})
</script>