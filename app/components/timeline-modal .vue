<template>
  <UModal
    :ui="{ body: 'sm:p-0' }"
    :overlay="false"
    v-model:open="isOpen"
    title="Timeline"
  >
    <template #body>
      <div class="flex h-[85vh] p-0">
        <TimeGrid :pomodoros="pomodorosListToday" />
      </div>
    </template>
  </UModal>
</template>

<script setup lang="ts">
import { usePomodoroStore } from "~/stores/pomodoro";
import { storeToRefs } from "pinia";

const pomodoroStore = usePomodoroStore();
const { pomodorosListToday } = storeToRefs(pomodoroStore);

const supabase = useSupabaseClient();
const user = useSupabaseUser();
const user_id = computed(() => {
  return user.value?.sub as string;
});

const isOpen = defineModel<boolean>({ default: false });
</script>
