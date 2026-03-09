import type { 
  ObjectiveInsert, 
  ObjectiveUpdate, 
  KeyResultInsert, 
  KeyResultUpdate, 
  KeyResultTagInsert,
  ObjectiveWithKeyResults
} from "../../types/okr";

export const useOkrRepository = () => {
  const supabase = useSupabaseClient();

  // --- Objectives ---
  async function listObjectives(userId: string): Promise<ObjectiveWithKeyResults[]> {
    const { data } = await supabase
      .from("objectives")
      .select(`
        *,
        key_results (
          *,
          tags:key_result_tags (
            *,
            tag:tags (*)
          )
        )
      `)
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .throwOnError();

    return (data || []) as unknown as ObjectiveWithKeyResults[];
  }

  async function insertObjective(objective: ObjectiveInsert) {
    const { data } = await supabase
      .from("objectives")
      .insert(objective)
      .select()
      .maybeSingle()
      .throwOnError();
    return data;
  }

  async function updateObjective(id: string, updates: ObjectiveUpdate) {
    const { data } = await supabase
      .from("objectives")
      .update(updates)
      .eq("id", id)
      .select()
      .maybeSingle()
      .throwOnError();
    return data;
  }

  async function deleteObjective(id: string) {
    await supabase.from("objectives").delete().eq("id", id).throwOnError();
  }

  // --- Key Results ---
  async function insertKeyResult(kr: KeyResultInsert) {
    const { data } = await supabase
      .from("key_results")
      .insert(kr)
      .select()
      .maybeSingle()
      .throwOnError();
    return data;
  }

  async function updateKeyResult(id: string, updates: KeyResultUpdate) {
    const { data } = await supabase
      .from("key_results")
      .update(updates)
      .eq("id", id)
      .select()
      .maybeSingle()
      .throwOnError();
    return data;
  }

  async function deleteKeyResult(id: string) {
    await supabase.from("key_results").delete().eq("id", id).throwOnError();
  }

  // --- Key Result Tags ---
  async function insertKeyResultTags(tags: KeyResultTagInsert[]) {
    if (tags.length === 0) return [];
    const { data } = await supabase
      .from("key_result_tags")
      .insert(tags)
      .select()
      .throwOnError();
    return data;
  }

  async function deleteKeyResultTags(keyResultId: string) {
    await supabase.from("key_result_tags").delete().eq("key_result_id", keyResultId).throwOnError();
  }

  return {
    listObjectives,
    insertObjective,
    updateObjective,
    deleteObjective,
    insertKeyResult,
    updateKeyResult,
    deleteKeyResult,
    insertKeyResultTags,
    deleteKeyResultTags,
  };
};
