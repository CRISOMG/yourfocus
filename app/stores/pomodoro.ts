import { defineStore } from "pinia";
import type { Pomodoro } from "~/types/Pomodoro";

export const usePomodoroStore = defineStore("pomodoro", () => {
  const currPomodoro = ref<Pomodoro["Row"] | null>(null);
  const pomodorosListToday = ref<Pomodoro["Row"][] | null>(null);
  const loadingPomodoros = ref<boolean>(false);
  return { currPomodoro, pomodorosListToday, loadingPomodoros };
});
