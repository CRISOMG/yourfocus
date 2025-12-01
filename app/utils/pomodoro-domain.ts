export const DEFAULT_REQUIRED_TAGS_FOR_FINISH_CYCLE = [
  "focus",
  "break",
  "long-break",
];

export const DEFAULT_POMODORO_DURATION_IN_MINUTES = 25;

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
  pomodoroDuration: number = DEFAULT_POMODORO_DURATION_IN_MINUTES * 60
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
