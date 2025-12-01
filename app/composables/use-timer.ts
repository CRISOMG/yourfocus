export const useTimer = () => {
  const timer = ref<NodeJS.Timeout | null>(null);
  const clockInMinutes = ref(`${DEFAULT_POMODORO_DURATION_IN_MINUTES}:00`);
  const accSeconds = ref(0);

  function startTimer({
    onTick,
    onFinish,
    syncAccSeconds,
  }: {
    onTick: () => void;
    onFinish: () => void;
    syncAccSeconds: number;
  }) {
    if (timer.value) clearInterval(timer.value);

    timer.value = setInterval(() => {
      onTick();
      const pomodoroDurationInSeconds =
        DEFAULT_POMODORO_DURATION_IN_MINUTES * 60;

      syncAccSeconds += 1;
      const remainingSeconds = pomodoroDurationInSeconds - syncAccSeconds;
      const minutes = Math.floor(remainingSeconds / 60);
      const seconds = remainingSeconds % 60;
      clockInMinutes.value = `${minutes.toString().padStart(2, "0")}:${seconds
        .toString()
        .padStart(2, "0")}`;

      if (remainingSeconds <= 0) {
        if (timer.value) clearInterval(timer.value);
        clockInMinutes.value = `${DEFAULT_POMODORO_DURATION_IN_MINUTES}:00`;
        accSeconds.value = 1;
        return onFinish();
      }
    }, 1000);
  }

  return {
    DEFAULT_POMODORO_DURATION_IN_MINUTES,
    startTimer,
    timer,
    clockInMinutes,
  };
};
