import { ref, watch } from "vue";

const AGENT_STORAGE_KEY = "yourfocus_chat_agent_active";
const DRIVE_EXPORT_STORAGE_KEY = "yourfocus_chat_auto_export_drive";

export function useChatPreferences() {
  // Use useState so state is shared across any components within Nuxt
  const isAgentActive = useState<boolean>("chat_agent_active", () => {
    if (import.meta.client) {
      const stored = localStorage.getItem(AGENT_STORAGE_KEY);
      if (stored !== null) {
        return stored === "true";
      }
    }
    return true; // Default to active (AI Assistant)
  });

  const isAutoExportDriveActive = useState<boolean>(
    "chat_auto_export_drive",
    () => {
      if (import.meta.client) {
        const stored = localStorage.getItem(DRIVE_EXPORT_STORAGE_KEY);
        if (stored !== null) {
          return stored === "true";
        }
      }
      return false; // Default to inactive until toggled on
    },
  );

  // Keep localStorage synchronized on client
  if (import.meta.client) {
    watch(
      isAgentActive,
      (val) => {
        localStorage.setItem(AGENT_STORAGE_KEY, String(val));
      },
      { immediate: true },
    );

    watch(
      isAutoExportDriveActive,
      (val) => {
        localStorage.setItem(DRIVE_EXPORT_STORAGE_KEY, String(val));
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

  function toggleAutoExportDrive() {
    isAutoExportDriveActive.value = !isAutoExportDriveActive.value;
  }

  function setAutoExportDrive(value: boolean) {
    isAutoExportDriveActive.value = value;
  }

  return {
    isAgentActive,
    toggleAgent,
    setAgentActive,
    isAutoExportDriveActive,
    toggleAutoExportDrive,
    setAutoExportDrive,
  };
}
