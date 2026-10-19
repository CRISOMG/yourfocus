<script setup lang="ts">
import { navigateTo } from "#app";
import { useClipboard } from "@vueuse/core";

interface FileAvatarProps {
  name: string;
  type: string;
  previewUrl?: string;
  status?: "idle" | "uploading" | "uploaded" | "error";
  error?: string;
  url?: string;
  storagePath?: string;
  removable?: boolean;
}

const props = withDefaults(defineProps<FileAvatarProps>(), {
  status: "idle",
  removable: false,
});

const emit = defineEmits<{
  remove: [];
}>();

const toast = useToast();
const clipboard = useClipboard();
const isGeneratingLink = ref(false);

const isAudio = computed(() => {
  return (
    props.type?.startsWith("audio/") ||
    props.name?.endsWith(".webm") ||
    props.name?.endsWith(".mp3") ||
    props.name?.endsWith(".wav") ||
    props.name?.endsWith(".ogg")
  );
});

async function handleShare(expiresIn: number, label: string) {
  if (!props.storagePath && !props.url) return;
  try {
    isGeneratingLink.value = true;
    let shareUrl = props.url || "";
    if (props.storagePath) {
      const res = await $fetch<{ signedUrl: string }>("/api/audio/share", {
        method: "POST",
        body: { audioPath: props.storagePath, expiresIn },
      });
      shareUrl = res.signedUrl;
    }
    await clipboard.copy(shareUrl);
    toast.add({
      title: "Enlace copiado",
      description: `Enlace de audio copiado (${label})`,
      icon: "i-lucide-check-circle",
      color: "success",
    });
  } catch (err: any) {
    toast.add({
      title: "Error al generar enlace",
      description: err?.message || "No se pudo generar el enlace",
      icon: "i-lucide-alert-circle",
      color: "error",
    });
  } finally {
    isGeneratingLink.value = false;
  }
}

async function handleDownload() {
  if (!props.storagePath && !props.url) return;
  try {
    let downloadUrl = props.url || "";
    if (props.storagePath) {
      const res = await $fetch<{ signedUrl: string }>("/api/audio/share", {
        method: "POST",
        body: { audioPath: props.storagePath, expiresIn: 3600, download: true },
      });
      downloadUrl = res.signedUrl;
    }
    const link = document.createElement("a");
    link.href = downloadUrl;
    link.download = props.name || "audio.mp3";
    link.target = "_blank";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    toast.add({
      title: "Descargando audio",
      description: props.name,
      icon: "i-lucide-download",
      color: "info",
    });
  } catch (err: any) {
    toast.add({
      title: "Error al descargar",
      description: err?.message || "No se pudo iniciar la descarga",
      icon: "i-lucide-alert-circle",
      color: "error",
    });
  }
}

const audioMenuItems = computed(() => [
  [
    {
      label: "Copiar enlace (1 hora)",
      icon: "i-lucide-clock",
      onSelect: () => handleShare(3600, "1 hora"),
    },
    {
      label: "Copiar enlace (24 horas)",
      icon: "i-lucide-calendar",
      onSelect: () => handleShare(86400, "24 horas"),
    },
    {
      label: "Copiar enlace (7 días)",
      icon: "i-lucide-calendar-days",
      onSelect: () => handleShare(604800, "7 días"),
    },
    {
      label: "Copiar enlace permanente",
      icon: "i-lucide-infinity",
      onSelect: () => handleShare(-1, "Permanente"),
    },
  ],
  [
    {
      label: "Descargar archivo",
      icon: "i-lucide-download",
      onSelect: () => handleDownload(),
    },
    {
      label: "Abrir en nueva pestaña",
      icon: "i-lucide-external-link",
      onSelect: () => {
        if (props.url) {
          navigateTo(props.url, {
            external: true,
            open: { target: "_blank" },
          });
        }
      },
    },
  ],
]);
</script>

<template>
  <div class="relative group inline-flex items-center">
    <UTooltip arrow :text="name">
      <UAvatar
        size="3xl"
        :src="type?.startsWith('image/') ? previewUrl : undefined"
        :icon="getFileIcon(type, name)"
        class="cursor-pointer border border-default rounded-lg"
        :class="{
          'opacity-50': status === 'uploading',
          'border-error': status === 'error',
        }"
        @click.prevent="
          url && navigateTo(url, { external: true, open: { target: '_blank' } })
        "
      />
    </UTooltip>

    <div
      v-if="status === 'uploading'"
      class="absolute inset-0 flex items-center justify-center bg-black/50 rounded-lg"
    >
      <UIcon name="i-lucide-loader-2" class="size-8 animate-spin text-white" />
    </div>

    <UTooltip v-if="status === 'error'" :text="error">
      <div
        class="absolute inset-0 flex items-center justify-center bg-error/50 rounded-lg"
      >
        <UIcon name="i-lucide-alert-circle" class="size-8 text-white" />
      </div>
    </UTooltip>

    <!-- Audio actions dropdown trigger -->
    <div
      v-if="isAudio && status !== 'uploading' && status !== 'error'"
      class="absolute -bottom-1 -right-1 z-10"
    >
      <UDropdownMenu
        :items="audioMenuItems"
        :content="{ align: 'start' }"
        :ui="{ content: 'w-52' }"
      >
        <UButton
          icon="i-lucide-share-2"
          size="xs"
          square
          color="neutral"
          variant="solid"
          :loading="isGeneratingLink"
          class="rounded-full shadow-md bg-neutral-800 text-white hover:bg-neutral-700"
          title="Compartir o descargar audio"
        />
      </UDropdownMenu>
    </div>

    <UButton
      v-if="removable && status !== 'uploading'"
      icon="i-lucide-x"
      size="xs"
      square
      color="neutral"
      variant="solid"
      class="absolute p-0 -top-1 -right-1 opacity-0 group-hover:opacity-100 transition-opacity rounded-full"
      @click="emit('remove')"
    />
  </div>
</template>
