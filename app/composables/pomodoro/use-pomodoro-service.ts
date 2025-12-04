import type { Pomodoro, PomodoroCycle } from "~/types/Pomodoro";
import {
  hasCycleFinished,
  calculateTimelineFromNow,
  DEFAULT_POMODORO_DURATION_IN_MINUTES,
} from "~/utils/pomodoro-domain";
import {
  usePomodoroRepository,
  usePomodoroCycleRepository,
  useTagRepository,
} from "./use-pomodoro-repository";

export const usePomodoroService = () => {
  const pomodoroRepository = usePomodoroRepository();
  const cycleRepository = usePomodoroCycleRepository();
  const tagRepository = useTagRepository();

  async function checkIsCurrentCycleEnd() {
    const currCycle = await cycleRepository.getCurrent();

    if (!currCycle) {
      return false;
    }

    const pomodoros = currCycle.pomodoros;
    const required_tags = currCycle.required_tags;

    const pomodoroTagsTypesArray =
      pomodoros?.flatMap((p) => p.tags?.map((t) => t.type)) || [];
    return hasCycleFinished(pomodoroTagsTypesArray, required_tags);
  }

  async function getOrCreateCurrentCycleId(userId: string): Promise<number> {
    const isCurrentCycleEnd = await checkIsCurrentCycleEnd();
    if (isCurrentCycleEnd) {
      await finishCurrentCycle();
    } else {
      const currentCycle = await cycleRepository.getCurrent();
      if (currentCycle) {
        return currentCycle.id;
      }
    }

    const newCycle = await cycleRepository.insert({
      state: "current",
      user_id: userId,
    });

    if (!newCycle) {
      throw new Error("Failed to create new pomodoro cycle.");
    }
    return newCycle.id;
  }

  async function startPomodoro({
    user_id,
    tagId = TagIdByType.FOCUS,
  }: {
    user_id: string;
    tagId?: TagIdByType;
  }) {
    const defaultDurationBytag =
      PomodoroDurationInSecondsByDefaultCycleConfiguration[tagId];

    const { started_at, expected_end } =
      calculateTimelineFromNow(defaultDurationBytag);

    const pomodoroCycleId = await getOrCreateCurrentCycleId(user_id);

    const expected_duration = defaultDurationBytag;
    const result = await pomodoroRepository.insert(
      {
        user_id,
        started_at,
        expected_end,
        timelapse: 0,
        toggle_timeline: [],
        created_at: new Date().toISOString(),
        state: "current",
        expected_duration,
        cycle: pomodoroCycleId,
      },
      tagId
    );

    return result;
  }

  async function registToggleTimelinePomodoro(
    pomodoroId: number,
    type: "play" | "pause"
  ) {
    const { toggle_timeline } = await pomodoroRepository.getOne(pomodoroId);

    const result = await pomodoroRepository.update(pomodoroId, {
      state: "current",
      toggle_timeline: [
        ...(toggle_timeline as []),
        {
          at: new Date().toISOString(),
          type: type,
        },
      ],
    });

    return result;
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

  async function finishCurrentPomodoro({ timelapse }: { timelapse: number }) {
    const pomodoro = await pomodoroRepository.getCurrentPomodoro();
    if (!pomodoro) {
      return;
    }
    await pomodoroRepository.update(pomodoro.id, {
      timelapse,
      state: "finished",
      finished_at: new Date().toISOString(),
    });
  }

  async function getTagByCycleSecuense() {
    const cycle = await cycleRepository.getCurrent();
    if (!cycle) {
      return;
    }
    const pomodoros = cycle.pomodoros;
    const required_tags =
      cycle.required_tags || DEFAULT_REQUIRED_TAGS_FOR_FINISH_CYCLE;

    const pomodoroTagsTypesArray =
      pomodoros?.flatMap((p) => p.tags?.map((t) => t.type)) || [];

    const tagType = calculateNextTagFromCycleSecuence(
      pomodoroTagsTypesArray,
      required_tags
    );
    const tag = await tagRepository.getOneByType(tagType);

    if (!tag) {
      return;
    }
    return tag;
  }

  async function getTagIdByType(type: string) {
    const tag = await tagRepository.getOneByType(type);
    if (!tag) {
      return;
    }
    return tag.id;
  }

  return {
    checkIsCurrentCycleEnd,
    finishCurrentCycle,
    registToggleTimelinePomodoro,
    startPomodoro,
    getOrCreateCurrentCycleId,
    finishCurrentPomodoro,
    getTagByCycleSecuense,
    getTagIdByType,
  };
};
