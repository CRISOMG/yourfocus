// app/composables/useGoogleDrive.ts
import { ref } from "vue";

export function useGoogleDrive() {
  const isConnected = useState<boolean>("google_drive_connected", () => false);
  const isAuthorized = useState<boolean>("google_drive_authorized", () => false);
  const isLoading = useState<boolean>("google_drive_loading", () => false);
  const isExporting = useState<boolean>("google_drive_exporting", () => false);
  const driveEmail = useState<string | null>("google_drive_email", () => null);

  const supabase = useSupabaseClient();
  const toast = useToast();

  async function checkStatus() {
    try {
      isLoading.value = true;
      const res = await $fetch<{
        connected: boolean;
        isAuthorized: boolean;
        email?: string;
      }>("/api/audio/drive-status");

      isConnected.value = res.connected;
      isAuthorized.value = res.isAuthorized;
      driveEmail.value = res.email || null;
      return res;
    } catch {
      isConnected.value = false;
      isAuthorized.value = false;
      return { connected: false, isAuthorized: false };
    } finally {
      isLoading.value = false;
    }
  }

  async function connectGoogleDrive() {
    try {
      const redirectUrl = `${window.location.origin}/callback?connect_drive=true`;
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          scopes: "https://www.googleapis.com/auth/drive.file",
          queryParams: {
            access_type: "offline",
            prompt: "consent",
          },
          redirectTo: redirectUrl,
        },
      });

      if (error) {
        throw error;
      }
    } catch (err: any) {
      toast.add({
        title: "Error al iniciar conexión",
        description: err?.message || "No se pudo redirigir a Google Drive",
        icon: "i-lucide-alert-circle",
        color: "error",
      });
    }
  }

  async function disconnectGoogleDrive() {
    try {
      isLoading.value = true;
      await $fetch("/api/audio/drive-status", { method: "DELETE" });
      isConnected.value = false;
      toast.add({
        title: "Google Drive desconectado",
        description: "Se han removido los permisos de acceso",
        icon: "i-lucide-check-circle",
        color: "neutral",
      });
    } catch (err: any) {
      toast.add({
        title: "Error al desconectar",
        description: err?.message || "No se pudo desconectar Google Drive",
        icon: "i-lucide-alert-circle",
        color: "error",
      });
    } finally {
      isLoading.value = false;
    }
  }

  async function exportToDrive(audioPath: string) {
    if (!audioPath) return null;
    try {
      isExporting.value = true;
      const result = await $fetch<{
        success: boolean;
        fileId: string;
        name: string;
        webViewLink?: string;
      }>("/api/audio/export-drive", {
        method: "POST",
        body: { audioPath },
      });

      toast.add({
        title: "Exportado a Google Drive",
        description: result.name || "Archivo guardado con éxito",
        icon: "i-lucide-cloud-upload",
        color: "success",
        actions: result.webViewLink
          ? [
              {
                label: "Abrir en Drive",
                icon: "i-lucide-external-link",
                onClick: () => {
                  window.open(result.webViewLink, "_blank", "noopener,noreferrer");
                },
              },
            ]
          : undefined,
      });

      return result;
    } catch (err: any) {
      const msg = err?.data?.statusMessage || err?.message || "Error al subir a Drive";
      toast.add({
        title: "Error al exportar a Google Drive",
        description: msg,
        icon: "i-lucide-alert-circle",
        color: "error",
      });
      throw err;
    } finally {
      isExporting.value = false;
    }
  }

  return {
    isConnected,
    isAuthorized,
    isLoading,
    isExporting,
    driveEmail,
    checkStatus,
    connectGoogleDrive,
    disconnectGoogleDrive,
    exportToDrive,
  };
}
