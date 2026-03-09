import type { Database } from "../types/supabase";

// Entities
export type DbObjective = Database["public"]["Tables"]["objectives"]["Row"];
export type DbKeyResult = Database["public"]["Tables"]["key_results"]["Row"];
export type DbKeyResultTag = Database["public"]["Tables"]["key_result_tags"]["Row"];

export type DbMetricCategory = Database["public"]["Enums"]["metric_category"];

// Inserts
export type ObjectiveInsert = Database["public"]["Tables"]["objectives"]["Insert"];
export type KeyResultInsert = Database["public"]["Tables"]["key_results"]["Insert"];
export type KeyResultTagInsert = Database["public"]["Tables"]["key_result_tags"]["Insert"];

// Updates
export type ObjectiveUpdate = Database["public"]["Tables"]["objectives"]["Update"];
export type KeyResultUpdate = Database["public"]["Tables"]["key_results"]["Update"];
export type KeyResultTagUpdate = Database["public"]["Tables"]["key_result_tags"]["Update"];

// Enriched types for UI
export type KeyResultWithTags = DbKeyResult & {
  tags: (DbKeyResultTag & {
    tag: { id: number; label: string; type: string | null };
  })[];
};

export type ObjectiveWithKeyResults = DbObjective & {
  key_results: KeyResultWithTags[];
};
