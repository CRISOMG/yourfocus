<template>
    <div v-if="user">
        <pomodoro-container :user_id="user.sub" />
    </div>

</template>

<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()

</script>