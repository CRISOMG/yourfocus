import { usePomodoroStore } from "~/stores/pomodoro";
import type { Pomodoro, PomodoroCycle } from "~/types/Pomodoro";
import {
  hasCycleFinished,
  calculateTimelineFromNow,
} from "~/utils/pomodoro-domain";

export const usePomodoroRepository = () => {
  const supabase = useSupabaseClient();
  const cycleRepository = usePomodoroCycleRepository();

  async function getCurrentPomodorosOfCurrentCycle() {
    const pomodorosWithCycleAndTagsQuery = await supabase
      .from("pomodoros")
      .select(
        `
          *,
          cycle (*),
          tags (*)
          `
      )
      .eq("cycle.state", "current")
      .throwOnError();
    const result = pomodorosWithCycleAndTagsQuery.data;
    return result;
  }

  async function insert(pomodoro: Pomodoro["Insert"]) {
    const currentCycle = await cycleRepository.getCurrent();

    let pomodoroCycleId: number | null = null;
    if (!currentCycle) {
      const { data: pomodoroCycle } = await supabase
        .from("pomodoros_cycles")
        .insert({
          state: "current",
          user_id: pomodoro.user_id,
        })
        .select()
        .single()
        .throwOnError();
      pomodoroCycleId = pomodoroCycle.id;
    }

    const { data } = await supabase
      .from("pomodoros")
      .insert({ ...pomodoro, cycle: pomodoroCycleId })
      .select()
      .single()
      .throwOnError();

    const tags = await supabase
      .from("pomodoros_tags")
      .insert({
        pomodoro: data.id,
        user_id: pomodoro.user_id,
        tag: 1,
      })
      .select()
      .single()
      .throwOnError();

    return data;
  }
  async function update(id: number, pomodoro: Pomodoro["Update"]) {
    const { data } = await supabase
      .from("pomodoros")
      .update(pomodoro)
      .eq("id", id)
      .select()
      .order("created_at", { ascending: false })
      .single()
      .throwOnError();

    return data;
  }
  async function getCurrentPomodoro(): Promise<Pomodoro["Row"]> {
    const { data } = await supabase
      .from("pomodoros")
      .select(
        `
          *,
          cycle (state)
          `
      )
      .neq("state", "finished")
      .single()
      .throwOnError();

    return data;
  }
  async function getOne(id: number): Promise<Pomodoro["Row"] | null> {
    const { data } = await supabase
      .from("pomodoros")
      .select()
      .eq("id", id)
      .order("created_at", { ascending: false })
      .single()
      .throwOnError();

    return data;
  }
  async function listToday() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const { data } = await supabase
      .from("pomodoros")
      .select(
        `
          *,
          cycle (state),
          tags (*)
          `
      )
      .gte("started_at", today.toISOString())
      .lt("started_at", tomorrow.toISOString())
      .throwOnError();

    return data;
  }
  return {
    insert,
    update,
    getOne,
    getCurrentPomodoro,
    getCurrentPomodorosOfCurrentCycle,
    listToday,
  };
};

export const usePomodoroCycleRepository = () => {
  const supabase = useSupabaseClient();

  async function getCurrent() {
    const { data } = await supabase
      .from("pomodoros_cycles")
      .select(
        `
            *,
            pomodoros (
              *,
              tags (*)
            )
          `
      )
      .filter("state", "eq", "current")
      .single()
      .throwOnError();

    return data;
  }

  async function insert(pomodoroCycle: PomodoroCycle["Insert"]) {
    const { data } = await supabase
      .from("pomodoros_cycles")
      .insert({
        state: "current",
        user_id: pomodoroCycle.user_id,
      })
      .select()
      .single()
      .throwOnError();

    return data;
  }

  async function update(id: number, pomodoroCycle: PomodoroCycle["Update"]) {
    const { data } = await supabase
      .from("pomodoros_cycles")
      .update(pomodoroCycle)
      .eq("id", id)
      .select()
      .single()
      .throwOnError();

    return data;
  }

  async function getOne(id: number) {
    const { data } = await supabase
      .from("pomodoros_cycles")
      .select()
      .eq("id", id)
      .single()
      .throwOnError();

    return data;
  }

  return {
    insert,
    update,
    getOne,
    getCurrent,
  };
};

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
      // if (syncAccSeconds) {
      // }
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

/**
 * TODO:
 * _ hacer global datos de configuracion como el tiempo de duracion del pomodoro y currPomodoro
 */
export const usePomodoroUtils = () => {
  const pomodoroStore = usePomodoroStore();
  const { currPomodoro, pomodorosListToday, loadingPomodoros } =
    storeToRefs(pomodoroStore);

  const pomodoroRepository = usePomodoroRepository();
  const { timer, startTimer, clockInMinutes } = useTimer();

  const pomodoroService = usePomodoroService();
  const toast = useSuccessErrorToast();

  function handleStartTimer() {
    startTimer({
      onTick: () => {
        if (!currPomodoro.value) return;
        currPomodoro.value.timelapse += 1;
      },
      onFinish: () => {
        handleFinishPomodoro();
      },
      syncAccSeconds: currPomodoro.value?.timelapse || 0,
    });
  }
  async function getCurrentPomodoro() {
    const upstreamPomodoro = await pomodoroRepository.getCurrentPomodoro();

    if (upstreamPomodoro) {
      currPomodoro.value = upstreamPomodoro;
      localStorage.setItem("currPomodoro", JSON.stringify(upstreamPomodoro));
    }

    if (upstreamPomodoro?.state === "current") {
      handleStartTimer();
    }
  }
  async function handleStartPomodoro(user_id: string) {
    if (!currPomodoro.value) {
      const { started_at, expected_end } = calculateTimelineFromNow();
      const result = await pomodoroRepository.insert({
        user_id,
        started_at,
        expected_end,
        timelapse: 0,
        toggle_timeline: [],
        created_at: new Date().toISOString(),
        state: "current",
        expected_duration: DEFAULT_POMODORO_DURATION_IN_MINUTES * 60,
      });
      currPomodoro.value = result;
      localStorage.setItem("currPomodoro", JSON.stringify(result));
    } else {
      const currToggleTimeline =
        ((currPomodoro.value as any)?.toggle_timeline as Array<{
          at: string;
          type: "play" | "pause";
        }>) || [];
      const result = await pomodoroRepository.update(currPomodoro.value.id, {
        state: "current",
        toggle_timeline: [
          ...currToggleTimeline,
          {
            at: new Date().toISOString(),
            type: "play",
          },
        ],
      });
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

    const result = await pomodoroRepository.update(currPomodoro.value.id, {
      timelapse: currPomodoro.value.timelapse,
      state: "finished",
      finished_at: new Date().toISOString(),
    });

    const isCurrentCycleEnd = await pomodoroService.checkIsCurrentCycleEnd();
    if (isCurrentCycleEnd) {
      await pomodoroService.finishCurrentCycle();
    }

    currPomodoro.value = null;
  }
  async function handleResetPomodoro() {
    if (!currPomodoro.value) {
      return;
    }
    currPomodoro.value = null;
    localStorage.removeItem("currPomodoro");
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

export const usePomodoroService = () => {
  const pomodoroRepository = usePomodoroRepository();
  const cycleRepository = usePomodoroCycleRepository();

  async function checkIsCurrentCycleEnd() {
    const { pomodoros, required_tags } = await cycleRepository.getCurrent();
    const pomodoroTagsTypesArray =
      pomodoros?.flatMap((p) => p.tags?.map((t) => t.type)) || [];
    return hasCycleFinished(pomodoroTagsTypesArray, required_tags);
  }

  async function finishCurrentCycle() {
    const cycle = await cycleRepository.getCurrent();
    if (!cycle) {
      return;
    }
    await cycleRepository.update(cycle.id, {
      state: "finished",
    });
  }

  return {
    checkIsCurrentCycleEnd,
    finishCurrentCycle,
  };
};
