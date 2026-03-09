import { useOkrRepository } from "./use-okr-repository";
import { prepareInitialObjective, isValidObjective, prepareInitialKeyResult, isValidKeyResult } from "./use-okr-domain";
import type { DbMetricCategory } from "../../types/okr";

export const useOkrService = () => {
  const repository = useOkrRepository();

  async function getObjectivesWithKeyResults(userId: string) {
    if (!userId) throw new Error("User ID is required");
    return await repository.listObjectives(userId);
  }

  async function createObjective(userId: string, title: string, description?: string) {
    if (!isValidObjective(title)) {
      throw new Error("Objective title must be at least 3 characters long");
    }
    const objectiveData = prepareInitialObjective(userId, title, description);
    return await repository.insertObjective(objectiveData);
  }

  async function removeObjective(id: string) {
    return await repository.deleteObjective(id);
  }

  async function createKeyResult(
    objectiveId: string, 
    title: string, 
    metricType: DbMetricCategory, 
    targetValue: number, 
    tags: { tagId: number, weight: number }[]
  ) {
    if (!isValidKeyResult(title, targetValue)) {
      throw new Error("Invalid Key Result title or target value");
    }

    // 1. Insert KR
    const krData = prepareInitialKeyResult(objectiveId, title, metricType, targetValue);
    const newKr = await repository.insertKeyResult(krData);

    if (!newKr) throw new Error("Failed to create Key Result");

    // 2. Attach tags
    if (tags.length > 0) {
      const tagInserts = tags.map(t => ({
        key_result_id: newKr.id,
        tag_id: t.tagId,
        weight: t.weight
      }));
      await repository.insertKeyResultTags(tagInserts);
    }

    return newKr;
  }

  async function removeKeyResult(id: string) {
    return await repository.deleteKeyResult(id);
  }

  return {
    getObjectivesWithKeyResults,
    createObjective,
    removeObjective,
    createKeyResult,
    removeKeyResult
  };
};
