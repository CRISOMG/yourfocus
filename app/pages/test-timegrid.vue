<script setup lang="ts">
import TimeGrid from "~/components/TimeGrid.vue";

const today = new Date();
const setTime = (h: number, m: number) => {
  const d = new Date(today);
  d.setHours(h, m, 0, 0);
  return d;
};

const pomodoros = [
  { id: 1, start: setTime(9, 0), durationMinutes: 25, label: "Morning Focus" },
  {
    id: 2,
    start: setTime(10, 30),
    durationMinutes: 25,
    label: "Coding Session",
  },
  { id: 3, start: setTime(14, 15), durationMinutes: 50, label: "Deep Work" },
];
</script>

<template>
  <div class="p-8 max-w-md mx-auto">
    <h1 class="text-2xl font-bold mb-4">TimeGrid Component Test</h1>

    <div class="mb-8">
      <h2 class="text-xl font-semibold mb-2">Default (0-24h)</h2>
      <TimeGrid :pomodoros="pomodoros" />
    </div>

    <div class="mb-8">
      <h2 class="text-xl font-semibold mb-2">Work Hours (8-18h)</h2>
      <TimeGrid :start-hour="8" :end-hour="18" :pomodoros="pomodoros" />
    </div>

    <div class="mb-8">
      <h2 class="text-xl font-semibold mb-2">12h Format</h2>
      <TimeGrid
        :start-hour="8"
        :end-hour="20"
        :format24h="false"
        :pomodoros="pomodoros"
      />
    </div>
  </div>
</template>
