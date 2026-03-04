import { formatElapsedTime } from "~/utils/time-domain";

/**
 * Progressive stopwatch composable (counts UP).
 * Mirror of useTimer but in the opposite direction.
 *
 * Unlike useTimer (countdown), this tracks elapsed time from start
 * and optionally stops at a jornada-based limit.
 */
export const useStopwatch = () => {
  const timer = ref<NodeJS.Timeout | null>(null);
  const clockDisplay = ref("00:00");
  const elapsedSeconds = ref(0);
  const _startTime = ref<number | null>(null);
  const _previousElapsed = ref(0); // accumulated time from previous segments

  function startStopwatch({
    onTick,
    onLimit,
    limitAt,
    resumeFromSeconds = 0,
  }: {
    onTick?: (elapsedSeconds: number) => void;
    onLimit?: () => void;
    limitAt?: string; // ISO timestamp — jornada end
    resumeFromSeconds?: number; // resume from previously accumulated seconds
  }) {
    if (timer.value) clearInterval(timer.value);

    _previousElapsed.value = resumeFromSeconds;
    _startTime.value = Date.now();

    const limitTime = limitAt ? new Date(limitAt).getTime() : null;

    timer.value = setInterval(() => {
      const now = Date.now();
      const segmentElapsed = Math.floor((now - _startTime.value!) / 1000);
      const totalElapsed = _previousElapsed.value + segmentElapsed;

      elapsedSeconds.value = totalElapsed;
      clockDisplay.value = formatElapsedTime(totalElapsed);

      onTick?.(totalElapsed);

      // Check jornada limit
      if (limitTime && now >= limitTime) {
        clearStopwatch();
        onLimit?.();
      }
    }, 1000);
  }

  function pauseStopwatch(): number {
    if (timer.value) {
      clearInterval(timer.value);
      timer.value = null;
    }

    // Accumulate the elapsed time from this segment
    if (_startTime.value) {
      const segmentElapsed = Math.floor((Date.now() - _startTime.value) / 1000);
      _previousElapsed.value += segmentElapsed;
      _startTime.value = null;
    }

    return elapsedSeconds.value;
  }

  function clearStopwatch() {
    if (timer.value) {
      clearInterval(timer.value);
      timer.value = null;
    }
    elapsedSeconds.value = 0;
    clockDisplay.value = "00:00";
    _startTime.value = null;
    _previousElapsed.value = 0;
  }

  return {
    startStopwatch,
    pauseStopwatch,
    clearStopwatch,
    clockDisplay,
    elapsedSeconds,
    timer,
  };
};
