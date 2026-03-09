import { useOkrService } from "./use-okr-service";
import type { ObjectiveWithKeyResults } from "../../types/okr";
import type { DbMetricCategory } from "../../types/okr";

export const useOkrController = () => {
  const service = useOkrService();
  const profileController = useProfileController();

  // State
  const objectives = useState<ObjectiveWithKeyResults[]>("okr_objectives", () => []);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  const loadObjectives = async () => {
    const userId = profileController.profile.value?.id;
    if (!userId) return;

    isLoading.value = true;
    error.value = null;
    
    try {
      const data = await service.getObjectivesWithKeyResults(userId);
      objectives.value = data;
    } catch (err: any) {
      error.value = err.message;
    } finally {
      isLoading.value = false;
    }
  };

  const handleCreateObjective = async (title: string, description?: string) => {
    const userId = profileController.profile.value?.id;
    if (!userId) return;

    isLoading.value = true;
    error.value = null;
    try {
      await service.createObjective(userId, title, description);
      await loadObjectives(); // Refresh state
    } catch (err: any) {
      error.value = err.message;
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  const handleDeleteObjective = async (id: string) => {
    isLoading.value = true;
    error.value = null;
    try {
      await service.removeObjective(id);
      objectives.value = objectives.value.filter(o => o.id !== id);
    } catch (err: any) {
      error.value = err.message;
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  const handleCreateKeyResult = async (
    objectiveId: string, 
    title: string, 
    metricType: DbMetricCategory, 
    targetValue: number, 
    tags: { tagId: number, weight: number }[]
  ) => {
    isLoading.value = true;
    error.value = null;
    try {
      await service.createKeyResult(objectiveId, title, metricType, targetValue, tags);
      await loadObjectives(); // Refresh state
    } catch (err: any) {
      error.value = err.message;
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  const handleDeleteKeyResult = async (id: string) => {
    isLoading.value = true;
    error.value = null;
    try {
      await service.removeKeyResult(id);
      await loadObjectives(); // Easier to re-fetch to ensure nested arrays are accurate
    } catch (err: any) {
      error.value = err.message;
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  // Watch for profile availability to load initial data
  watch(
    () => profileController.profile.value,
    (newProfile) => {
      if (newProfile) {
        loadObjectives();
      } else {
        objectives.value = [];
      }
    },
    { immediate: true }
  );

  return {
    objectives,
    isLoading,
    error,
    loadObjectives,
    handleCreateObjective,
    handleDeleteObjective,
    handleCreateKeyResult,
    handleDeleteKeyResult
  };
};
