import type { DbMetricCategory, ObjectiveInsert, KeyResultInsert } from "../../types/okr";

export function calculateProgressPercentage(current: number, target: number): number {
  if (target === 0) return 0;
  const raw = (current / target) * 100;
  return Math.min(Math.max(raw, 0), 100); // Clamp between 0 and 100
}

export function isValidObjective(title: string): boolean {
  return title.trim().length >= 3;
}

export function isValidKeyResult(title: string, targetValue: number): boolean {
  return title.trim().length >= 3 && targetValue > 0;
}

export function prepareInitialObjective(userId: string, title: string, description?: string): ObjectiveInsert {
  return {
    user_id: userId,
    title: title.trim(),
    description: description?.trim() || null,
  };
}

export function prepareInitialKeyResult(
  objectiveId: string, 
  title: string, 
  metricType: DbMetricCategory, 
  targetValue: number = 100
): KeyResultInsert {
  return {
    objective_id: objectiveId,
    title: title.trim(),
    metric_type: metricType,
    target_value: targetValue,
    current_value: 0,
  };
}
