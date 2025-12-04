import { usePomodoroStore } from "~/stores/pomodoro";
import type { Pomodoro, PomodoroCycle } from "~/types/Pomodoro";
import {
  hasCycleFinished,
  calculateTimelineFromNow,
} from "~/utils/pomodoro-domain";
import { usePomodoroService } from "./pomodoro/use-pomodoro-service";
import { usePomodoroRepository } from "./pomodoro/use-pomodoro-repository";

/**
 * TODO:
 * _ hacer global datos de configuracion como el tiempo de duracion del pomodoro
 */
export const usePomodoroUtils = () => {
  const pomodoroStore = usePomodoroStore();
  const { currPomodoro, pomodorosListToday, loadingPomodoros } =
    storeToRefs(pomodoroStore);

  const pomodoroRepository = usePomodoroRepository();
  const { timer, startTimer, clockInMinutes, setClockInSeconds } = useTimer();

  const pomodoroService = usePomodoroService();
  const toast = useSuccessErrorToast();

  function handleStartTimer() {
    startTimer({
      onTick: () => {
        if (!currPomodoro.value) return;
        currPomodoro.value.timelapse += 1;

        if (currPomodoro.value.timelapse % 10 === 0) {
          handleSyncPomodoro();
        }
      },
      onFinish: () => {
        handleFinishPomodoro();
      },
      syncAccSeconds: currPomodoro.value?.timelapse || 0,
      clockStartInMinute: (currPomodoro.value?.expected_duration || 0) / 60,
    });
  }
  async function getCurrentPomodoro() {
    const upstreamPomodoro = await pomodoroRepository.getCurrentPomodoro();

    if (upstreamPomodoro && upstreamPomodoro.state !== "finished") {
      currPomodoro.value = upstreamPomodoro;
      localStorage.setItem("currPomodoro", JSON.stringify(upstreamPomodoro));

      const remainingSeconds =
        upstreamPomodoro.timelapse <= upstreamPomodoro.expected_duration
          ? upstreamPomodoro.expected_duration - upstreamPomodoro.timelapse
          : 0;

      if (remainingSeconds <= 0) {
        return handleFinishPomodoro();
      }

      setClockInSeconds(remainingSeconds);
    }

    if (upstreamPomodoro?.state === "current") {
      handleStartTimer();
    }
  }
  async function handleStartPomodoro(user_id: string) {
    if (!currPomodoro.value) {
      const tag = await pomodoroService.getTagByCycleSecuense();

      const result = await pomodoroService.startPomodoro({
        user_id,
        tagId: tag?.id,
      });
      await handleListPomodoros();

      currPomodoro.value = result;
      localStorage.setItem("currPomodoro", JSON.stringify(result));
    } else {
      const result = await pomodoroService.registToggleTimelinePomodoro(
        currPomodoro.value.id,
        "play"
      );
      currPomodoro.value = result;
    }

    handleStartTimer();
  }
  async function handlePausePomodoro() {
    if (!currPomodoro.value) {
      return;
    }
    const currToggleTimeline =
      ((currPomodoro.value as any)?.toggle_timeline as Array<{
        at: string;
        type: "play" | "pause";
      }>) || [];
    const result = await pomodoroRepository.update(currPomodoro.value.id, {
      timelapse: currPomodoro.value.timelapse,
      toggle_timeline: [
        ...currToggleTimeline,
        {
          at: new Date().toISOString(),
          type: "pause",
        },
      ],
      state: "paused",
    });
    currPomodoro.value = result;
    if (timer.value) clearInterval(timer.value);
  }
  async function handleFinishPomodoro() {
    if (!currPomodoro.value) {
      return;
    }

    const result = await pomodoroService.finishCurrentPomodoro({
      timelapse: currPomodoro.value.timelapse,
    });

    const isCurrentCycleEnd = await pomodoroService.checkIsCurrentCycleEnd();
    if (isCurrentCycleEnd) {
      await pomodoroService.finishCurrentCycle();
    }

    currPomodoro.value = null;
    localStorage.removeItem("currPomodoro");
  }
  async function handleResetPomodoro() {
    if (
      !confirm(
        "Are you sure you want to reset the pomodoro? this will finish the current cycle."
      )
    ) {
      return;
    }

    if (timer.value) clearInterval(timer.value);
    await handleFinishPomodoro();
    await pomodoroService.finishCurrentCycle();
    setClockInSeconds(
      PomodoroDurationInSecondsByDefaultCycleConfiguration[TagIdByType.FOCUS]
    );
    localStorage.removeItem("currPomodoro");
    currPomodoro.value = null;
  }
  async function handleSyncPomodoro() {
    if (!currPomodoro.value) {
      return;
    }

    try {
      const result = await pomodoroRepository.update(currPomodoro.value.id, {
        timelapse: currPomodoro.value.timelapse,
      });
      currPomodoro.value = result;
    } catch (error) {
      console.error(error);

      toast.addErrorToast({ title: error.type, description: error.message });
    }
  }

  async function handleListPomodoros() {
    try {
      loadingPomodoros.value = true;
      const result = await pomodoroRepository.listToday();

      pomodorosListToday.value = result;
      return result;
    } catch (error) {
      console.error(error);
      toast.addErrorToast({
        title: "Error",
        description: (error as Error).message,
      });
      return null;
    } finally {
      loadingPomodoros.value = false;
    }
  }

  return {
    handleSyncPomodoro,
    handleStartPomodoro,
    handlePausePomodoro,
    handleFinishPomodoro,
    handleResetPomodoro,
    getCurrentPomodoro,
    handleListPomodoros,
    currPomodoro,
    clockInMinutes,
    timer,
    startTimer,
  };
};
