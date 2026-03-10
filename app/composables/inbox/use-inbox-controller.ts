import { useAuthStore } from "~/stores/auth";

export interface InboxAction {
  id: string;
  title: string;
  description: string | null;
  action_type: string;
  action_payload: Record<string, any>;
  status: "pending" | "completed" | "dismissed";
  priority: number;
  execution_count: number;
  created_at: string;
  completed_at: string | null;
}

export const actionTypeMeta: Record<
  string,
  { label: string; icon: string; color: string }
> = {
  NONE: { label: "Informativa", icon: "i-lucide-bell", color: "neutral" },
  CREATE_TASK: {
    label: "Crear tarea",
    icon: "i-lucide-list-todo",
    color: "primary",
  },
  REVIEW_NOTE: {
    label: "Repasar nota",
    icon: "i-lucide-book-open",
    color: "info",
  },
  CREATE_LOG: {
    label: "Crear bitácora",
    icon: "i-lucide-notebook-pen",
    color: "success",
  },
  AI_ATOMIZE: {
    label: "Atomizar con IA",
    icon: "i-lucide-sparkles",
    color: "warning",
  },
  OKR_PROGRESS: {
    label: "Progreso OKR",
    icon: "i-lucide-award",
    color: "success",
  },
};

export function useInboxController() {
  const supabase = useSupabaseClient();
  const authStore = useAuthStore();
  const toast = useToast();

  const inboxActions = useState<InboxAction[]>("inbox-actions-list", () => []);
  const loading = useState("inbox-loading", () => false);
  const pendingCount = computed(() => pendingActions.value.length);
  const unreadCount = computed(
    () => inboxActions.value.filter((a) => a.status === "pending").length,
  );

  const { setPendingChat } = usePendingChat();

  const pendingActions = computed(() =>
    inboxActions.value.filter((a) => a.status === "pending"),
  );

  const completedActions = computed(() =>
    inboxActions.value.filter((a) => a.status === "completed"),
  );

  async function fetchInboxActions() {
    if (!authStore.user?.id) return;
    loading.value = true;
    try {
      const { data, error } = await supabase
        .from("inbox_actions")
        .select("*")
        .eq("user_id", authStore.user.id)
        .in("status", ["pending", "completed"])
        .order("priority", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(50);

      if (error) throw error;
      inboxActions.value = (data as InboxAction[]) || [];
    } catch (e: any) {
      console.error("Error fetching inbox actions:", e);
    } finally {
      loading.value = false;
    }
  }

  function setupRealtime() {
    if (!authStore.user?.id) return;
    const channel = supabase
      .channel("public:inbox_actions")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "inbox_actions",
          filter: `user_id=eq.${authStore.user.id}`,
        },
        (payload) => {
          // Detect INSERT specifically for OKR_PROGRESS
          if (payload.eventType === "INSERT") {
            const newAction = payload.new as InboxAction;
            if (newAction.action_type === "OKR_PROGRESS") {
              const diff = newAction.action_payload?.diff || "+1";
              toast.add({
                title: newAction.title,
                description: newAction.description || undefined,
                color: "success",
                icon: "i-lucide-award",
                actions: [{
                  label: "Ver KPIs",
                  onClick: () => { useRouter().push({ path: "/", hash: "#kpis" }); } // Placeholder routing
                }]
              });
              
              // Also send system text to the chat container via pendingChat
              setPendingChat({
                text: `He ganado +${diff}% de progreso en ${newAction.title.replace('Progreso OKR: ', '')}. Acompañame a celebrarlo! 🎉`,
              });

              // Mark as completed instantly since it's just a notification hook
              markAsCompleted(newAction);
            }
          }

          // Simplest fallback: re-fetch the entire list.
          // More advanced approach: apply the payload directly.
          fetchInboxActions();
        },
      )
      .subscribe();

    onUnmounted(() => {
      supabase.removeChannel(channel);
    });
  }

  async function markAsCompleted(action: InboxAction) {
    try {
      const { error } = await supabase
        .from("inbox_actions")
        .update({
          status: "completed",
          completed_at: new Date().toISOString(),
          execution_count: (action.execution_count || 0) + 1,
        })
        .eq("id", action.id);

      if (error) throw error;

      // Update locally
      const idx = inboxActions.value.findIndex((a) => a.id === action.id);
      if (idx !== -1) {
        const currentAction = inboxActions.value[idx];
        if (currentAction) {
          inboxActions.value[idx] = {
            ...currentAction,
            status: "completed",
            completed_at: new Date().toISOString(),
            execution_count: (currentAction.execution_count || 0) + 1,
          } as InboxAction;
        }
      }
    } catch (e: any) {
      console.error("Error updating inbox action:", e);
      toast.add({
        title: "Error",
        description: "No se pudo actualizar la acción",
        color: "error",
      });
    }
  }

  async function dismissAction(action: InboxAction) {
    try {
      const { error } = await supabase
        .from("inbox_actions")
        .update({ status: "dismissed" })
        .eq("id", action.id);

      if (error) throw error;

      inboxActions.value = inboxActions.value.filter((a) => a.id !== action.id);
    } catch (e: any) {
      console.error("Error dismissing inbox action:", e);
    }
  }

  // The central dispatcher that connects specific inbox actions to application UI/modals
  function dispatchAction(action: InboxAction) {
    const payload = action.action_payload || {};

    switch (action.action_type) {
      case "CREATE_TASK":
        toast.add({
          title: "Crear tarea",
          description: payload.title || action.title,
          color: "info",
        });
        // TODO: Open TASK_FORM modal via layout modals
        break;
      case "REVIEW_NOTE":
        toast.add({
          title: "Repasar nota",
          description: payload.title || action.title,
          color: "info",
        });
        // TODO: Open NOTE_VIEWER modal
        break;
      case "CREATE_LOG":
        toast.add({
          title: "Crear bitácora",
          description: "Abriendo formulario de bitácora...",
          color: "info",
        });
        // TODO: Open LOG_FORM modal
        break;
      case "AI_ATOMIZE":
        // Phase 3 implementation
        toast.add({
          title: "Atomizando con IA...",
          description: "Abriendo chat con AI para desglosar la tarea",
          color: "info",
        });
        const routerAI = useRouter();
        routerAI.push({
          path: "/",
          query: {
            q: `Atomiza esta tarea grande: "${action.action_payload?.task_title || action.title}"\n[ID: ${action.action_payload?.task_id}]`,
          },
        });
        break;
      case "OKR_PROGRESS":
        const routerKpi = useRouter();
        routerKpi.push("/?tab=analytics");
        break;
    }
  }

  return {
    inboxActions,
    pendingActions,
    completedActions,
    loading,
    unreadCount,
    fetchInboxActions,
    setupRealtime,
    markAsCompleted,
    dismissAction,
    dispatchAction,
  };
}
