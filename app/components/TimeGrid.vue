<script setup lang="ts">
import { computed, ref } from "vue";
import { usePomodoroStore } from "~/stores/pomodoro";
import type { Pomodoro } from "~/types/Pomodoro";
const currHour = ref(new Date().getHours());
const pomodoroStore = usePomodoroStore();
const pomodoroStoreRefs = storeToRefs(pomodoroStore);

const elementToScrollRef = ref<HTMLElement | null>(null);

/**
 * 2. Función que se llama para cada elemento en el v-for
 * Solo guarda el elemento si su 'hour' coincide con 'currHour'.
 */
const setHourRef = (el: any, hour: number) => {
  if (el && hour === currHour.value) {
    elementToScrollRef.value = el as HTMLElement;
  }
};

onMounted(() => {
  // 3. Esperar hasta que el DOM esté completamente renderizado
  nextTick(() => {
    if (elementToScrollRef.value) {
      elementToScrollRef.value.scrollIntoView({
        behavior: "smooth",
        block: "center",
      });
    }
  });
});

const props = withDefaults(
  defineProps<{
    startHour?: number;
    endHour?: number;
    pomodoros?: Pomodoro["Row"][];
    format24h?: boolean;
  }>(),
  {
    startHour: 0,
    endHour: 23,
    pomodoros: [],
    format24h: true,
  }
);

const hours = computed(() => {
  const h = [];
  for (let i = props.startHour; i <= props.endHour; i++) {
    h.push(i);
  }
  return h;
});

function getDiffInMinutes(from: string, to: string) {
  const tiempoAMinutos = (tiempoStr: string) => {
    const [horas, minutos] = tiempoStr.split(":").map(Number);
    return horas * 60 + minutos;
  };

  const minutosInicio = tiempoAMinutos(from);
  const minutosFin = tiempoAMinutos(to);

  if (minutosFin < minutosInicio) {
    return minutosFin + 1440 - minutosInicio;
  }

  return minutosFin - minutosInicio;
}

const formatHour = (hour: number) => {
  if (props.format24h) {
    return `${hour.toString().padStart(2, "0")}:00`;
  }
  const ampm = hour >= 12 ? "PM" : "AM";
  const h = hour % 12 || 12;
  return `${h} ${ampm}`;
};

const proportion = 2;
const hourInPx = 60 * proportion;
const caclTop = (hour: number, minutes: number) => {
  const startMinutesInPx = hour * hourInPx + minutes * proportion;
  const totalGridMinutesInPx = 23 * hourInPx;

  const top = (startMinutesInPx / totalGridMinutesInPx) * 100;

  return top;
};

const getPomodoroStyle = (pomodoro: Pomodoro["Row"]) => {
  const start = new Date(pomodoro.started_at);
  const hour = start.getHours();
  const minutes = start.getMinutes();

  const end = new Date(pomodoro.finished_at || pomodoro.expected_end);

  const diff = getDiffInMinutes(
    start.toLocaleTimeString().slice(0, 5),
    end.toLocaleTimeString().slice(0, 5)
  );

  const top = caclTop(hour, minutes);
  let height = diff * proportion;
  return {
    top: `calc(${top}%)`,
    height: `${height}px`,
  };
};
</script>

<template>
  <div
    class="relative w-full h-full border border-gray-200 rounded-lg overflow-hidden bg-white dark:bg-gray-900 dark:border-gray-800 overflow-y-scroll"
  >
    <!-- Grid -->
    <div
      class="relative"
      :style="{
        height: `${24 * hourInPx}px`,
        // height: 'calc(100vh - 80px)',
      }"
    >
      <div
        v-for="hour in hours"
        :key="hour"
        :ref="(el) => setHourRef(el, hour)"
        class="absolute select-none w-full border-t border-gray-100 dark:border-gray-800 flex items-baseline"
        :style="{
          top: `${((hour - startHour) / (endHour - startHour)) * 100}%`,
          height: `${hourInPx}px`,
          //   top: `${((1 - startHour) / (endHour - startHour)) * 100}%`,
        }"
      >
        <span
          class="text-sm text-gray-400 ml-2 -mt-[10px] bg-white dark:bg-gray-900 px-1"
        >
          {{ formatHour(hour) }}
        </span>
      </div>
      <div
        class="absolute h-0.5 w-full rounded-sm border border-red-500 flex flex-row justify-left transition-all hover:shadow-md z-10"
        :style="{
          top: `calc(${caclTop(
            new Date().getHours(),
            new Date().getMinutes()
          )}%)`,
        }"
      ></div>
      <!-- Pomodoros -->
      <div
        v-for="pomodoro in pomodoros"
        :key="pomodoro.id"
        class="absolute left-2 right-4 rounded-sm shadow-sm border border-primary-200 bg-primary-50 dark:bg-primary-900/20 dark:border-primary-800 p-0 transition-all hover:shadow-md z-10"
        :style="getPomodoroStyle(pomodoro)"
      >
        <span
          class="absolute -top-[5px] bg-amber- select-none text-sm text-primary-500 dark:text-primary-400 mx-1"
        >
          {{ new Date(pomodoro.started_at).toLocaleTimeString().slice(0, 5) }}
        </span>
        <span
          class="absolute -bottom-[4px] bg-amber- select-none text-sm text-primary-500 dark:text-primary-400 mx-1"
        >
          {{
            new Date(pomodoro.finished_at || pomodoro.expected_end)
              .toLocaleTimeString()
              .slice(0, 5)
          }}
        </span>
        <div class="ml-12 flex flex-row justify-left items-baseline">
          <div
            class="select-none text-sm text-primary-500 dark:text-primary-400 mx-1"
          >
            {{ (pomodoro.expected_duration || 0) / 60 }}m
          </div>
          <div
            class="select-none text-md font-medium text-primary-700 dark:text-primary-300"
          >
            {{ pomodoro.type || "Pomodoro" }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
