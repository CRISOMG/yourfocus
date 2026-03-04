import type { TFlow } from "./use-flow-repository";
import type { BloqueJornada } from "~~/shared/utils/v2/jornada";
import {
  getJornadaDisplayInfo,
  getRemainingJornadaOptions,
  type JornadaOption,
} from "~/utils/time-domain";
import { calculatePomodoroTimelapse } from "~/utils/pomodoro-domain";

enum FlowState {
  IDLE = "idle",
  RUNNING = "running",
  PAUSED = "paused",
}

/**
 * Controller for the Flow mode.
 * Manages the UI state, stopwatch, and interactions.
 */
export const useFlowController = () => {
  const flowService = useFlowService();
  const stopwatch = useStopwatch();
  const { profile } = useProfileController();

  const currentFlow = ref<TFlow | null>(null);
  const flowState = ref<FlowState>(FlowState.IDLE);
  const loading = ref(false);
  const jornadaInfo = ref(getJornadaDisplayInfo());

  // Jornada selector state
  const jornadaOptions = ref<JornadaOption[]>(getRemainingJornadaOptions());
  const selectedJornadaValue = ref<string | undefined>(undefined);

  // Computed: the selected block object (or null for auto/current)
  const selectedBlock = computed<BloqueJornada | undefined>(() => {
    if (!selectedJornadaValue.value) return undefined;
    const opt = jornadaOptions.value.find(
      (o) => o.value === selectedJornadaValue.value,
    );
    return opt?.bloque;
  });

  // Update jornada info every minute
  const jornadaInterval = ref<NodeJS.Timeout | null>(null);

  function startJornadaUpdater() {
    jornadaInfo.value = getJornadaDisplayInfo();
    jornadaOptions.value = getRemainingJornadaOptions();
    jornadaInterval.value = setInterval(() => {
      jornadaInfo.value = getJornadaDisplayInfo();
      jornadaOptions.value = getRemainingJornadaOptions();
    }, 60_000);
  }

  function stopJornadaUpdater() {
    if (jornadaInterval.value) {
      clearInterval(jornadaInterval.value);
      jornadaInterval.value = null;
    }
  }

  /**
   * Initialize: check if there's an active flow from the database.
   */
  async function init() {
    loading.value = true;
    try {
      const existing = await flowService.getCurrentFlow();
      if (existing) {
        currentFlow.value = existing;

        if (existing.time_session.state === "current") {
          flowState.value = FlowState.RUNNING;
          const elapsed = calculatePomodoroTimelapse(
            existing.time_session.toggle_timeline,
            Infinity,
          );
          stopwatch.startStopwatch({
            resumeFromSeconds: elapsed,
            limitAt: existing.jornada_limit_at || undefined,
            onLimit: () => handleFinish(),
          });
        } else if (existing.time_session.state === "paused") {
          flowState.value = FlowState.PAUSED;
          const elapsed = calculatePomodoroTimelapse(
            existing.time_session.toggle_timeline,
            Infinity,
          );
          stopwatch.elapsedSeconds.value = elapsed;
          stopwatch.clockDisplay.value = (
            await import("~/utils/time-domain")
          ).formatElapsedTime(elapsed);
        }
      }
    } finally {
      loading.value = false;
    }
  }

  /**
   * Start a new flow with the selected jornada limit.
   */
  async function handleStart() {
    const userId = profile.value?.id;
    if (!userId) return;

    loading.value = true;
    try {
      const flow = await flowService.startFlow(userId, selectedBlock.value);
      if (flow) {
        currentFlow.value = flow;
        flowState.value = FlowState.RUNNING;
        stopwatch.startStopwatch({
          limitAt: flow.jornada_limit_at || undefined,
          onLimit: () => handleFinish(),
        });
      }
    } finally {
      loading.value = false;
    }
  }

  /**
   * Pause the current flow.
   */
  async function handlePause() {
    if (!currentFlow.value) return;

    const elapsed = stopwatch.pauseStopwatch();
    flowState.value = FlowState.PAUSED;

    await flowService.pauseFlow(
      currentFlow.value.time_session.id,
      currentFlow.value.time_session.toggle_timeline,
    );

    currentFlow.value.time_session.toggle_timeline.push({
      at: new Date().toISOString(),
      type: "pause",
    });
  }

  /**
   * Resume the paused flow.
   */
  async function handleResume() {
    if (!currentFlow.value) return;

    flowState.value = FlowState.RUNNING;

    await flowService.resumeFlow(
      currentFlow.value.time_session.id,
      currentFlow.value.time_session.toggle_timeline,
    );

    currentFlow.value.time_session.toggle_timeline.push({
      at: new Date().toISOString(),
      type: "play",
    });

    stopwatch.startStopwatch({
      resumeFromSeconds: stopwatch.elapsedSeconds.value,
      limitAt: currentFlow.value.jornada_limit_at || undefined,
      onLimit: () => handleFinish(),
    });
  }

  /**
   * Finish the current flow.
   */
  async function handleFinish() {
    if (!currentFlow.value) return;

    const elapsed = stopwatch.elapsedSeconds.value;
    stopwatch.clearStopwatch();
    flowState.value = FlowState.IDLE;

    await flowService.finishFlow(
      currentFlow.value.time_session.id,
      currentFlow.value.time_session.toggle_timeline,
      elapsed,
    );

    currentFlow.value = null;
    // Reset selector for next session
    selectedJornadaValue.value = undefined;
  }

  /**
   * Toggle play/pause.
   */
  function handlePlayPause() {
    switch (flowState.value) {
      case FlowState.IDLE:
        handleStart();
        break;
      case FlowState.RUNNING:
        handlePause();
        break;
      case FlowState.PAUSED:
        handleResume();
        break;
    }
  }

  // Init when profile is available
  watch(
    () => profile.value?.id,
    (id) => {
      if (id) {
        init();
        startJornadaUpdater();
      }
    },
    { immediate: true },
  );

  onUnmounted(() => {
    stopJornadaUpdater();
  });

  return {
    // State
    currentFlow: readonly(currentFlow),
    flowState: readonly(flowState),
    loading: readonly(loading),
    jornadaInfo: readonly(jornadaInfo),
    // Jornada selector
    jornadaOptions: readonly(jornadaOptions),
    selectedJornadaValue,
    // Stopwatch
    clockDisplay: stopwatch.clockDisplay,
    elapsedSeconds: stopwatch.elapsedSeconds,
    // Actions
    handleStart,
    handlePause,
    handleResume,
    handleFinish,
    handlePlayPause,
    // Constants
    FlowState,
  };
};
