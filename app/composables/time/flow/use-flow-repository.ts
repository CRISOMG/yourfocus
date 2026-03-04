import type {
  Tables,
  TablesInsert,
  TablesUpdate,
} from "~/types/database.types";
import type { TimelineEvent } from "~/composables/types";

export type TimeSession = Tables<"time_sessions">;
export type TimeSessionInsert = TablesInsert<"time_sessions">;
export type TimeSessionUpdate = TablesUpdate<"time_sessions">;

export type Flow = Tables<"flows">;
export type FlowInsert = TablesInsert<"flows">;
export type FlowUpdate = TablesUpdate<"flows">;

/**
 * Enriched flow type with parsed timeline and session data
 */
export type TFlow = Flow & {
  time_session: Omit<TimeSession, "toggle_timeline"> & {
    toggle_timeline: TimelineEvent[];
  };
};

/**
 * Repository layer for Flow operations.
 * Manages time_sessions (mode='flow') and flows tables.
 */
export const useFlowRepository = () => {
  const supabase = useSupabaseClient();

  /**
   * Get the current active flow for the authenticated user.
   * Returns null if no active flow exists.
   */
  async function getCurrentFlow(): Promise<TFlow | null> {
    const { data, error } = await supabase
      .from("flows")
      .select("*, time_session:time_sessions!inner(*)")
      .not("time_session.state", "in", '("finished","skipped")')
      .maybeSingle();

    if (error) {
      console.error("[FlowRepository] getCurrentFlow error:", error);
      return null;
    }

    if (!data) return null;

    return {
      ...data,
      time_session: {
        ...data.time_session,
        toggle_timeline: (data.time_session.toggle_timeline as any) || [],
      },
    } as TFlow;
  }

  /**
   * Start a new flow: creates a time_session and a flow record.
   */
  async function insertFlow({
    user_id,
    jornada_bloque,
    jornada_limit_at,
  }: {
    user_id: string;
    jornada_bloque: string;
    jornada_limit_at?: string;
  }): Promise<TFlow | null> {
    // 1. Create the time_session
    const { data: session, error: sessionError } = await supabase
      .from("time_sessions")
      .insert({
        user_id,
        mode: "flow" as const,
        state: "current" as const,
        started_at: new Date().toISOString(),
        toggle_timeline: [{ at: new Date().toISOString(), type: "start" }],
      })
      .select()
      .single();

    if (sessionError || !session) {
      console.error("[FlowRepository] insertFlow session error:", sessionError);
      return null;
    }

    // 2. Create the flow record linked to the session
    const { data: flow, error: flowError } = await supabase
      .from("flows")
      .insert({
        time_session_id: session.id,
        user_id,
        jornada_bloque,
        jornada_limit_at,
      })
      .select()
      .single();

    if (flowError || !flow) {
      console.error("[FlowRepository] insertFlow flow error:", flowError);
      return null;
    }

    return {
      ...flow,
      time_session: {
        ...session,
        toggle_timeline: (session.toggle_timeline as any) || [],
      },
    } as TFlow;
  }

  /**
   * Update the time_session state (pause, resume, finish).
   */
  async function updateSession(
    sessionId: number,
    updates: TimeSessionUpdate,
  ): Promise<TimeSession | null> {
    const { data, error } = await supabase
      .from("time_sessions")
      .update(updates)
      .eq("id", sessionId)
      .select()
      .single();

    if (error) {
      console.error("[FlowRepository] updateSession error:", error);
      return null;
    }

    return data;
  }

  return {
    getCurrentFlow,
    insertFlow,
    updateSession,
  };
};
