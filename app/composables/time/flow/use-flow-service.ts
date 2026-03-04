import type { TimelineEvent } from "~/composables/types";
import type { BloqueJornada } from "~~/shared/utils/v2/jornada";
import {
  getCurrentJornadaBlock,
  getJornadaLimitTimestamp,
} from "~/utils/time-domain";

/**
 * Service layer for Flow operations.
 * Business logic for starting, pausing, resuming, and finishing flows.
 */
export const useFlowService = () => {
  const flowRepository = useFlowRepository();

  /**
   * Start a new flow session.
   * If targetBlock is provided, uses it as the limit.
   * Otherwise, auto-detects the current jornada block.
   */
  async function startFlow(userId: string, targetBlock?: BloqueJornada) {
    // Guard: check if there's already an active flow
    const existing = await flowRepository.getCurrentFlow();
    if (existing) {
      console.warn(
        `[FlowService] Active flow already exists (id: ${existing.id}). Returning existing.`,
      );
      return existing;
    }

    const now = new Date();
    const bloque = targetBlock || getCurrentJornadaBlock(now);
    const limitAt = getJornadaLimitTimestamp(
      now,
      "America/Caracas",
      targetBlock,
    );

    const flow = await flowRepository.insertFlow({
      user_id: userId,
      jornada_bloque: bloque.nombre,
      jornada_limit_at: limitAt,
    });

    return flow;
  }

  /**
   * Pause the current flow.
   */
  async function pauseFlow(
    sessionId: number,
    currentTimeline: TimelineEvent[],
  ) {
    const timeline = [
      ...currentTimeline,
      { at: new Date().toISOString(), type: "pause" as const },
    ];

    return flowRepository.updateSession(sessionId, {
      state: "paused",
      toggle_timeline: timeline as any,
    });
  }

  /**
   * Resume a paused flow.
   */
  async function resumeFlow(
    sessionId: number,
    currentTimeline: TimelineEvent[],
  ) {
    const timeline = [
      ...currentTimeline,
      { at: new Date().toISOString(), type: "play" as const },
    ];

    return flowRepository.updateSession(sessionId, {
      state: "current",
      toggle_timeline: timeline as any,
    });
  }

  /**
   * Finish the current flow.
   * Calculates timelapse from the toggle_timeline.
   */
  async function finishFlow(
    sessionId: number,
    currentTimeline: TimelineEvent[],
    elapsedSeconds: number,
  ) {
    const timeline = [
      ...currentTimeline,
      { at: new Date().toISOString(), type: "finish" as const },
    ];

    return flowRepository.updateSession(sessionId, {
      state: "finished",
      finished_at: new Date().toISOString(),
      timelapse: elapsedSeconds,
      toggle_timeline: timeline as any,
    });
  }

  /**
   * Get the current active flow.
   */
  async function getCurrentFlow() {
    return flowRepository.getCurrentFlow();
  }

  return {
    startFlow,
    pauseFlow,
    resumeFlow,
    finishFlow,
    getCurrentFlow,
  };
};
