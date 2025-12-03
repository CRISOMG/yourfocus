export const DEFAULT_REQUIRED_TAGS_FOR_FINISH_CYCLE = [
  "focus",
  "break",
  "long-break",
];

export const DEFAULT_POMODORO_DURATION_IN_MINUTES = 25;
export const DEFAULT_BREAK_DURATION_IN_MINUTES = 5;
export const DEFAULT_LONG_BREAK_DURATION_IN_MINUTES = 15;

export enum TagIdByType {
  FOCUS = 1,
  BREAK = 2,
  LONG_BREAK = 3,
}

export enum TagType {
  FOCUS = "focus",
  BREAK = "break",
  LONG_BREAK = "long-break",
}

export const TagTypeById = {
  [TagIdByType.FOCUS]: "focus",
  [TagIdByType.BREAK]: "break",
  [TagIdByType.LONG_BREAK]: "long-break",
};

export const PomodoroDurationInSecondsByDefaultCycleConfiguration = {
  [TagIdByType.FOCUS]: DEFAULT_POMODORO_DURATION_IN_MINUTES * 60,
  [TagIdByType.BREAK]: DEFAULT_BREAK_DURATION_IN_MINUTES * 60,
  [TagIdByType.LONG_BREAK]: DEFAULT_LONG_BREAK_DURATION_IN_MINUTES * 60,
};

export function hasCycleFinished(
  pomodoroTags: string[],
  requiredTags:
    | string[]
    | null
    | undefined = DEFAULT_REQUIRED_TAGS_FOR_FINISH_CYCLE
): boolean {
  return (
    requiredTags?.reduce(
      (acc, curr) => acc && pomodoroTags.includes(curr),
      true
    ) || false
  );
}

export function calculateTimelineFromNow(
  pomodoroDuration: number = PomodoroDurationInSecondsByDefaultCycleConfiguration[
    TagIdByType.FOCUS
  ]
) {
  const started_at = new Date();
  const expectedDate = new Date(started_at.getTime());
  const durationInMs = pomodoroDuration * 1000;
  expectedDate.setTime(expectedDate.getTime() + durationInMs);

  return {
    started_at: started_at.toISOString(),
    expected_end: expectedDate.toISOString(),
  };
}

export function calculateNextTagFromCycleSecuence({
  currentSecuense,
  secuense,
}: {
  currentSecuense: string[];
  secuense: string[];
}) {
  const required_tags = secuense || DEFAULT_REQUIRED_TAGS_FOR_FINISH_CYCLE;

  const nextTagType = required_tags.filter(
    (tag) => !currentSecuense.includes(tag)
  );

  return nextTagType[0];
}
