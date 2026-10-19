import { ref, watch } from "vue";

const STORAGE_KEY = "yourfocus_chat_agent_active";

export function useChatPreferences() {
  // Use useState so state is shared across any components within Nuxt
  const isAgentActive = useState<boolean>("chat_agent_active", () => {
    if (import.meta.client) {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored !== null) {
        return stored === "true";
      }
    }
    return true; // Default to active (AI Assistant)
  });

  // Keep localStorage synchronized on client
  if (import.meta.client) {
    watch(
      isAgentActive,
      (val) => {
        localStorage.setItem(STORAGE_KEY, String(val));
      },
      { immediate: true },
    );
  }

  function toggleAgent() {
    isAgentActive.value = !isAgentActive.value;
  }

  function setAgentActive(value: boolean) {
    isAgentActive.value = value;
  }

  return {
    isAgentActive,
    toggleAgent,
    setAgentActive,
  };
}
