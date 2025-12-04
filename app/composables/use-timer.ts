export const useTimer = () => {
  const timer = ref<NodeJS.Timeout | null>(null);
  const clockInMinutes = ref(`${DEFAULT_POMODORO_DURATION_IN_MINUTES}:00`);
  const accSeconds = ref(0);

  function setClockInSeconds(remainingSeconds: number) {
    const minutes = Math.floor(remainingSeconds / 60);
    const seconds = remainingSeconds % 60;
    clockInMinutes.value = `${minutes.toString().padStart(2, "0")}:${seconds
      .toString()
      .padStart(2, "0")}`;
  }

  function startTimer({
    onTick,
    onFinish,
    syncAccSeconds,
    clockStartInMinute,
  }: {
    onTick: (accSeconds: number) => void;
    onFinish: () => void;
    syncAccSeconds: number;
    clockStartInMinute?: number;
  }) {
    if (timer.value) clearInterval(timer.value);

    timer.value = setInterval(() => {
      onTick(accSeconds.value);
      const pomodoroDurationInSeconds = clockStartInMinute
        ? clockStartInMinute * 60
        : PomodoroDurationInSecondsByDefaultCycleConfiguration[
            TagIdByType.FOCUS
          ];

      syncAccSeconds += 1;
      accSeconds.value += 1;
      const remainingSeconds = pomodoroDurationInSeconds - syncAccSeconds;
      setClockInSeconds(remainingSeconds);

      if (remainingSeconds <= 0) {
        if (timer.value) clearInterval(timer.value);
        clockInMinutes.value = `${clockStartInMinute}:00`;
        accSeconds.value = 1;
        return onFinish();
      }
    }, 1000);
  }

  return {
    DEFAULT_POMODORO_DURATION_IN_MINUTES,
    startTimer,
    setClockInSeconds,
    timer,
    clockInMinutes,
  };
};
