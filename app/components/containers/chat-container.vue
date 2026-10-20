<template>
  <div
    ref="scrollContainerRef"
    tabindex="0"
    class="h-[calc(100vh-6rem)] overflow-y-scroll custom-scrollbar select-text w-full p-0 sm:p-0 outline-none"
  >
    <DragDropOverlay :show="isDragging" />
    <div
      ref="dropzoneRef"
      class="flex-1 flex flex-col gap-4 sm:gap-6 min-h-full"
    >
      <UChatMessages
        should-auto-scroll
        should-scroll-to-bottom
        :messages="chat.messages || []"
        :status="chat.status"
        :assistant="
          chat.status !== 'streaming'
            ? {
                actions: [
                  {
                    label: 'Copy',
                    icon: copied ? 'i-lucide-copy-check' : 'i-lucide-copy',
                    onClick: copy,
                  },
                ],
              }
            : { actions: [] }
        "
        :spacing-offset="160"
        :ui="{
          root: '',
        }"
      >
        <template #content="{ message }">
          <template
            v-for="(part, index) in message.parts"
            :key="`${message.id}-${part.type}-${index}${'state' in part ? `-${part.state}` : ''}`"
          >
            <Reasoning
              v-if="part.type === 'reasoning'"
              :text="part.text"
              :is-streaming="part.state !== 'done'"
            />
            <!-- Only render markdown for assistant messages to prevent XSS from user input -->
            <template
              v-else-if="part.type === 'text' && message.role === 'assistant'"
            >
              <template
                v-for="(component, compIndex) in parseMessageComponents(
                  part.text,
                )"
                :key="compIndex"
              >
                <ToolDebugResult
                  v-if="component.type === 'log'"
                  v-bind="component.log"
                />

                <MDCCached
                  v-if="component.type === 'text'"
                  :value="component.content"
                  :cache-key="`${message.id}-${index}-${compIndex}`"
                  :components="components"
                  :parser-options="{ highlight: false }"
                  class="*:first:mt-0 *:last:mb-0 border-r-2 border-orange-400/30 rounded-lg max-w-[320px] sm:max-w-[600px]"
                />
              </template>
            </template>
            <div
              v-else-if="part.type === 'file' || part.type === 'source-url'"
              class="flex flex-row gap-2 no-wrap"
            >
              <FileAvatar
                :name="(part as any)?.filename || (part as any)?.title || 'File'"
                :type="
                  String(
                    (part as any)?.mediaType ||
                    (part as any)?.providerMetadata?.supabaseStorage?.mimeType ||
                    (part as any)?.providerMetadata?.googleDrive?.mimeType ||
                    'application/octet-stream'
                  )
                "
                :url="
                  String(
                    (part as any)?.url ||
                    (part as any)?.providerMetadata?.supabaseStorage?.url ||
                    (part as any)?.providerMetadata?.googleDrive?.webViewLink ||
                    ''
                  )
                "
                :storage-path="String((part as any)?.providerMetadata?.supabaseStorage?.path || '') || undefined"
              />
            </div>
            <!-- User messages are rendered as plain text (safely escaped by Vue) -->
            <UserMessage
              v-else-if="part.type === 'text' && message.role === 'user'"
              :text="part.text"
              :can-append-response="canAppendResponse(message.id)"
              :is-appending="appendingMap[message.id]"
              @append-response="handleAppendAgentResponse(message.id)"
            />
            <!-- <ToolWeather
                  v-else-if="part.type === 'tool-weather'"
                  :invocation="part as WeatherUIToolInvocation"
                />
                <ToolChart
                  v-else-if="part.type === 'tool-chart'"
                  :invocation="part as ChartUIToolInvocation"
                /> -->
          </template>
          <div
            v-if="
              message.role === 'user' &&
              !message.parts?.some((p) => p.type === 'text') &&
              canAppendResponse(message.id)
            "
            class="mt-1 pt-1.5 border-t border-neutral-700/30 flex items-center justify-between gap-2"
          >
            <span class="text-xs text-muted flex items-center gap-1 font-mono">
              <UIcon name="i-lucide-notebook-pen" class="size-3.5 text-amber-500" />
              Bitácora (audio/adjunto)
            </span>
            <UButton
              size="xs"
              color="primary"
              variant="subtle"
              icon="i-lucide-sparkles"
              :loading="appendingMap[message.id]"
              :disabled="appendingMap[message.id]"
              @click.stop="handleAppendAgentResponse(message.id)"
            >
              Append Agent Response
            </UButton>
          </div>
        </template>

        <template #indicator>
          <div class="flex items-center gap-3 px-4 py-3">
            <div class="relative">
              <img
                src="/favicon.ico"
                alt="Loading"
                class="w-8 h-8 rounded-full animate-pulse"
              />
              <span
                class="absolute inset-0 rounded-full bg-peach-500/20 animate-ping"
              />
            </div>
            <div class="flex items-center gap-1">
              <span
                class="w-1.5 h-1.5 rounded-full bg-peach-400 animate-bounce"
                style="animation-delay: 0ms"
              />
              <span
                class="w-1.5 h-1.5 rounded-full bg-peach-400 animate-bounce"
                style="animation-delay: 150ms"
              />
              <span
                class="w-1.5 h-1.5 rounded-full bg-peach-400 animate-bounce"
                style="animation-delay: 300ms"
              />
            </div>
          </div>
        </template>
      </UChatMessages>

      <!-- Loading indicator en el chat al guardar nota en bitácora -->
      <Transition
        enter-active-class="transition duration-200 ease-out"
        enter-from-class="opacity-0 translate-y-1"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition duration-150 ease-in"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 translate-y-1"
      >
        <div
          v-if="isSavingJournal"
          class="flex items-center justify-end px-4 py-1.5 gap-2 text-xs text-muted"
        >
          <UIcon name="i-lucide-loader-2" class="size-3.5 animate-spin text-amber-500" />
          <span>Guardando en bitácora...</span>
        </div>
      </Transition>

      <UChatPrompt
        v-model="input"
        :error="chat.error"
        :disabled="isUploading || isSavingJournal"
        :loading="isSavingJournal"
        variant="subtle"
        class="sticky bottom-0 [view-transition-name:chat-prompt] rounded-b-none z-10"
        :ui="{ base: 'px-1.5' }"
        @submit="handleSubmit"
      >
        <template v-if="files.length > 0" #header>
          <div class="flex flex-wrap gap-2">
            <FileAvatar
              v-for="fileWithStatus in files"
              :key="fileWithStatus.id"
              :name="fileWithStatus.file.name"
              :type="fileWithStatus.file.type"
              :preview-url="fileWithStatus.previewUrl"
              :url="fileWithStatus.url"
              :storage-path="fileWithStatus.driveFile?.path"
              :status="fileWithStatus.status"
              :error="fileWithStatus.error"
              removable
              @remove="removeFile(fileWithStatus.id)"
            />
          </div>
        </template>

        <template #footer>
          <div class="flex items-center gap-1">
            <FileUploadButton @files-selected="handleFilesSelected" />
            <AudioRecorderButton @uploaded="handleAudioUploaded" />
          </div>
          <div class="flex items-center gap-1">
            <!-- Dropdown Selector: Modo Agente ON vs Modo Bitácora -->
            <UDropdownMenu
              :items="chatConfigItems"
              :content="{ align: 'end' }"
              :ui="{ content: 'w-64' }"
            >
              <UButton
                size="xs"
                :color="isAgentActive ? 'primary' : 'warning'"
                :variant="isAgentActive ? 'subtle' : 'solid'"
                :icon="isAgentActive ? 'i-lucide-bot' : 'i-lucide-notebook-pen'"
                class="gap-1 font-medium transition-colors"
                title="Configuración de flujo del chat"
              >
                {{ isAgentActive ? "Agente ON" : "Bitácora" }}
                <UIcon name="i-lucide-chevron-down" class="size-3 opacity-60" />
              </UButton>
            </UDropdownMenu>

            <UButton
              size="xs"
              class="w-16 flex justify-center"
              :variant="isPro ? 'solid' : 'outline'"
              :color="isPro ? 'success' : 'neutral'"
              @click="isPro = !isPro"
            >
              {{ isPro ? "Pro" : "Flash" }}
            </UButton>

            <UChatPromptSubmit
              :status="chat.status"
              :disabled="isUploading || isSavingJournal"
              :loading="isSavingJournal"
              color="primary"
              size="sm"
              @stop="chat.stop()"
              @reload="chat.regenerate()"
            />
          </div>
        </template>
      </UChatPrompt>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { DefineComponent } from "vue";
import { Chat } from "@ai-sdk/vue";
import { DefaultChatTransport } from "ai";
import type {
  CreateUIMessage,
  FilePart,
  SourceUrlUIPart,
  UIDataTypes,
  UIMessage,
  UIMessagePart,
  UITools,
} from "ai";
import { useClipboard } from "@vueuse/core";
import { getTextFromMessage } from "@nuxt/ui/utils/ai";
import ProseStreamPre from "~/components/prose/PreStream.vue";
import ProseA from "~/components/prose/ProseA.vue";
import { useFileUploadWithStatus } from "~/composables/useFileUpload";
const components = {
  pre: ProseStreamPre as unknown as DefineComponent,
  a: ProseA as unknown as DefineComponent,
};

// Utility to parse mixed content (text + tool logs)
type MessageComponent =
  | { type: "text"; content: string; log?: never }
  | { type: "log"; log: any; content?: never };
import { parseMessageComponents } from "~~/shared/utils/messageParser";

const route = useRoute();

const router = useRouter();
const toast = useToast();
const clipboard = useClipboard();

function getFileName(url: string): string {
  try {
    const urlObj = new URL(url);
    const pathname = urlObj.pathname;
    const filename = pathname.split("/").pop() || "file";
    return decodeURIComponent(filename);
  } catch {
    return "file";
  }
}
const {
  dropzoneRef,
  isDragging,
  files,
  isUploading,
  uploadedFiles,
  addFiles,
  removeFile,
  clearFiles,
} = useFileUploadWithStatus();

const scrollContainerRef = ref<HTMLElement | null>(null);

function scrollToBottom(smooth = true) {
  nextTick(() => {
    if (scrollContainerRef.value) {
      scrollContainerRef.value.scrollTo({
        top: scrollContainerRef.value.scrollHeight,
        behavior: smooth ? "smooth" : "instant",
      });
    }
  });
}

const { data, refresh } = await useFetch(`/api/chat`);

const input = ref("");
const isPro = ref(false);

const brainPulse = useBrainPulseState();

const chat = new Chat({
  id: "me",
  messages: data?.value?.messages || [],
  transport: new DefaultChatTransport({
    api: `/api/chat`,
  }),
  onData: (dataPart) => {
    if (dataPart.type === "data-chat-title") {
      refreshNuxtData("chats");
    }
  },
  onError(error) {
    console.log(error);

    const { message } =
      typeof error.message === "string" && error.message[0] === "{"
        ? JSON.parse(error.message)
        : error;
    toast.add({
      description: message,
      icon: "i-lucide-alert-circle",
      color: "error",
      duration: 0,
    });
  },
  onFinish: () => {
    clearFiles();
    refresh();
  },
});

import { useChatPreferences } from "~/composables/useChatPreferences";
import { useGoogleDrive } from "~/composables/useGoogleDrive";

const {
  isAgentActive,
  toggleAgent,
  isAutoExportDriveActive,
  toggleAutoExportDrive,
} = useChatPreferences();

const {
  isConnected: isDriveConnected,
  isAuthorized: isDriveAuthorized,
  isLoading: isDriveLoading,
  checkStatus: checkDriveStatus,
  connectGoogleDrive,
  disconnectGoogleDrive,
  exportToDrive,
} = useGoogleDrive();

const isSavingJournal = ref(false);
const appendingMap = ref<Record<string, boolean>>({});

const chatConfigItems = computed(() => {
  const items = [
    [
      {
        label: isAgentActive.value
          ? "Modo Asistente (Respuestas activas)"
          : "Modo Bitácora (Solo notas/pensamientos)",
        icon: isAgentActive.value ? "i-lucide-bot" : "i-lucide-notebook-pen",
        disabled: true,
      },
    ],
    [
      {
        label: isAgentActive.value
          ? "Desactivar Respuestas del Agente"
          : "Activar Respuestas del Agente",
        icon: isAgentActive.value
          ? "i-lucide-toggle-right"
          : "i-lucide-toggle-left",
        onSelect: () => {
          toggleAgent();
          toast.add({
            title: isAgentActive.value
              ? "Modo Asistente Activado"
              : "Modo Bitácora Activado",
            description: isAgentActive.value
              ? "El agente responderá y analizará tus mensajes."
              : "Tus mensajes y audios se guardarán como notas sin respuestas automáticas.",
            icon: isAgentActive.value ? "i-lucide-bot" : "i-lucide-notebook-pen",
            color: isAgentActive.value ? "primary" : "warning",
          });
        },
      },
    ],
  ];

  // Google Drive integration controls
  const driveMenuSection: any[] = [
    {
      label: isDriveConnected.value
        ? "Google Drive: Conectado"
        : "Google Drive: Desconectado",
      icon: isDriveConnected.value
        ? "i-lucide-check-circle"
        : "i-lucide-cloud-off",
      disabled: true,
    },
  ];

  if (isDriveConnected.value) {
    driveMenuSection.push(
      {
        label: isAutoExportDriveActive.value
          ? "Auto-exportar audios: ON"
          : "Auto-exportar audios: OFF",
        icon: isAutoExportDriveActive.value
          ? "i-lucide-toggle-right"
          : "i-lucide-toggle-left",
        onSelect: () => {
          toggleAutoExportDrive();
          toast.add({
            title: isAutoExportDriveActive.value
              ? "Auto-exportación a Drive Activada"
              : "Auto-exportación a Drive Desactivada",
            description: isAutoExportDriveActive.value
              ? "Tus nuevas notas de audio se guardarán automáticamente en tu Google Drive."
              : "Los audios no se guardarán automáticamente en Google Drive.",
            icon: "i-lucide-cloud-upload",
            color: isAutoExportDriveActive.value ? "success" : "neutral",
          });
        },
      },
      {
        label: "Desconectar Google Drive",
        icon: "i-lucide-log-out",
        onSelect: () => disconnectGoogleDrive(),
      },
    );
  } else {
    driveMenuSection.push({
      label: "Conectar Google Drive",
      icon: "i-lucide-cloud-upload",
      onSelect: () => connectGoogleDrive(),
    });
  }

  items.push(driveMenuSection);
  return items;
});

async function handleSaveJournal(parts: any[], text: string) {
  try {
    isSavingJournal.value = true;
    const saved = await $fetch<UIMessage>("/api/chat/journal", {
      method: "POST",
      body: { parts, content: text },
    });

    if (saved) {
      chat.messages.push(saved);
      clearFiles();
      scrollToBottom(true);
    }
  } catch (err: any) {
    console.error("[Chat] Failed to save journal entry:", err);
    toast.add({
      title: "Error al guardar nota",
      description: err?.message || "No se pudo registrar la entrada en la bitácora",
      icon: "i-lucide-alert-circle",
      color: "error",
    });
  } finally {
    isSavingJournal.value = false;
  }
}

function canAppendResponse(messageId: string): boolean {
  if (!chat.messages) return false;
  const idx = chat.messages.findIndex((m) => m.id === messageId);
  if (idx === -1) return false;
  const msg = chat.messages[idx];
  if (msg.role !== "user") return false;

  // 1. Hay alguna respuesta del asistente que referencie explícitamente a este mensaje?
  const hasExplicit = chat.messages.some(
    (m) => m.role === "assistant" && (m as any).replyToId === messageId,
  );
  if (hasExplicit) return false;

  // 2. El mensaje siguiente es un asistente que NO sea respuesta a otro mensaje?
  const next = chat.messages[idx + 1];
  if (next && next.role === "assistant" && !(next as any).replyToId) {
    return false;
  }

  return true;
}

async function handleAppendAgentResponse(messageId: string) {
  const targetIdx = chat.messages.findIndex((m) => m.id === messageId);
  if (targetIdx === -1) return;

  appendingMap.value[messageId] = true;

  // Tomar contexto histórico hasta este mensaje
  const contextMessages = chat.messages.slice(0, targetIdx + 1);

  // Crear placeholder visual justo debajo del mensaje seleccionado
  const tempId = `temp-reply-${Date.now()}`;
  const tempAssistant: UIMessage & { replyToId?: string } = {
    id: tempId,
    role: "assistant",
    content: "",
    parts: [{ type: "text", text: "" }],
    createdAt: new Date(),
    replyToId: messageId,
  };

  chat.messages.splice(targetIdx + 1, 0, tempAssistant);

  try {
    const response = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        messages: contextMessages,
        replyToMessageId: messageId,
        usePro: isPro.value,
      }),
    });

    if (!response.ok || !response.body) {
      throw new Error(`Chat API error: ${response.statusText}`);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let accumulatedText = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const chunk = decoder.decode(value, { stream: true });
      const lines = chunk.split("\n");
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed === "data: [DONE]") continue;

        let jsonStr = "";
        if (trimmed.startsWith("data: ")) {
          jsonStr = trimmed.slice(6);
        } else if (trimmed.startsWith("data:")) {
          jsonStr = trimmed.slice(5);
        } else if (trimmed.startsWith("0:")) {
          jsonStr = trimmed.slice(2);
        }

        if (jsonStr) {
          try {
            const parsed = JSON.parse(jsonStr);
            const piece =
              typeof parsed === "string"
                ? parsed
                : parsed?.delta || parsed?.text || "";
            if (piece) {
              accumulatedText += piece;
              tempAssistant.content = accumulatedText;
              tempAssistant.parts = [{ type: "text", text: accumulatedText }];
              scrollToBottom(true);
            }
          } catch {
            if (!trimmed.startsWith("data:")) {
              accumulatedText += trimmed;
              tempAssistant.content = accumulatedText;
              tempAssistant.parts = [{ type: "text", text: accumulatedText }];
              scrollToBottom(true);
            }
          }
        }
      }
    }

    // Permitir que el guardado asíncrono onFinish en el servidor se complete antes de refrescar
    await new Promise((r) => setTimeout(r, 600));
    await refresh();
  } catch (err: any) {
    console.error("[Chat] Failed to append agent response:", err);
    const tempIdx = chat.messages.findIndex((m) => m.id === tempId);
    if (tempIdx !== -1) {
      chat.messages.splice(tempIdx, 1);
    }
    toast.add({
      title: "Error al generar respuesta",
      description: err?.message || "No se pudo procesar la respuesta del agente",
      icon: "i-lucide-alert-circle",
      color: "error",
    });
  } finally {
    appendingMap.value[messageId] = false;
  }
}

type N8NUITools = UITools;
type N8NUIDataTypes = UIDataTypes;
async function handleSubmit(e: Event) {
  e.preventDefault();
  const text = input.value.trim();
  const hasFiles = uploadedFiles.value.length > 0;

  if ((text || hasFiles) && !isUploading.value && !isSavingJournal.value) {
    const parts: UIMessagePart<N8NUIDataTypes, N8NUITools>[] = [];

    if (text) {
      parts.push({ type: "text", text });
    }

    if (hasFiles) {
      brainPulse.value = false;
      uploadedFiles.value.forEach((f) => {
        parts.push({
          type: "source-url",
          sourceId: f.driveFile?.id,
          title: f.filename,
          url: f.driveFile?.webViewLink,
          providerMetadata: {
            supabaseStorage: {
              path: (f.driveFile as any)?.path,
              url: f.driveFile?.webViewLink,
              mimeType: (f.driveFile as any)?.mimeType,
            },
          },
        } as SourceUrlUIPart);
      });
    }

    input.value = "";

    if (isAgentActive.value) {
      chat.sendMessage({
        role: "user",
        parts,
        usePro: isPro.value,
      });
    } else {
      await handleSaveJournal(parts, text);
    }
    scrollToBottom(true);
  }
}

async function handleFilesSelected(selectedFiles: File[]) {
  const response = await addFiles(selectedFiles, { skipTranscription: true });

  if (response && response[0]) {
    const result = response[0];
    // Set the formatted bitacora ID as the text input
    if (result.formatted_id) {
      input.value = result.formatted_id;
      isPro.value = true;
    }

    // Auto-export to Google Drive if active and audio file present
    if (
      isAutoExportDriveActive.value &&
      isDriveConnected.value &&
      result.audio?.path
    ) {
      exportToDrive(result.audio.path).catch((err) => {
        console.warn("[Auto Export Drive] Error exporting selected audio:", err);
      });
    }
    // File parts are already added to the files array by useFileUpload
    // They will be sent as source-url parts in handleSubmit
  }
}

interface TranscriptionResponse {
  audio?: { path: string; name: string; url: string; mimeType: string };
  text?: { path: string; name: string; url: string; mimeType: string };
  formatted_id?: string;
}

function handleAudioUploaded(response: TranscriptionResponse) {
  // Set the formatted bitacora ID as the text input
  if (response.formatted_id) {
    input.value = response.formatted_id;
    isPro.value = true;
  }

  // Auto-export to Google Drive if active
  if (
    isAutoExportDriveActive.value &&
    isDriveConnected.value &&
    response.audio?.path
  ) {
    exportToDrive(response.audio.path).catch((err) => {
      console.warn("[Auto Export Drive] Error exporting recorded audio:", err);
    });
  }

  // Add audio and text as files to be sent as source-url parts
  if (response.audio) {
    const audioId = "audio-" + Date.now();
    files.value.push({
      id: audioId,
      file: new File([], response.audio.name, {
        type: response.audio.mimeType,
      }),
      status: "uploaded",
      driveFile: {
        ...response.audio,
        id: audioId,
        webViewLink: response.audio.url,
      } as any,
      url: response.audio.url,
      previewUrl: "",
    });
  }

  if (response.text) {
    const textId = "text-" + Date.now();
    files.value.push({
      id: textId,
      file: new File([], response.text.name, { type: response.text.mimeType }),
      status: "uploaded",
      driveFile: {
        ...response.text,
        id: textId,
        webViewLink: response.text.url,
      } as any,
      url: response.text.url,
      previewUrl: "",
    });
  }
}

const copied = ref(false);

function copy(e: MouseEvent, message: UIMessage) {
  clipboard.copy(getTextFromMessage(message));

  copied.value = true;

  setTimeout(() => {
    copied.value = false;
  }, 2000);
}

// Watch for pending audio from bottom navbar mic recording
const { pendingAudio, consumePendingAudio } = usePendingAudio();

watch(
  pendingAudio,
  (value) => {
    if (value) {
      const data = consumePendingAudio();
      if (data) {
        handleAudioUploaded(data);
      }
    }
  },
  { immediate: true },
);

watch(
  () => route.query.chat_q,
  (newChatQ) => {
    if (newChatQ && typeof newChatQ === "string") {
      chat.sendMessage({ text: String(newChatQ) });
      router.replace({ query: { ...route.query, chat_q: undefined } });
    }
  },
  { immediate: true },
);

// Watch for pending chat messages from global state (used for system gamification toasts)
const { pendingChat, consumePendingChat } = usePendingChat();

watch(
  pendingChat,
  (value) => {
    if (value) {
      const data = consumePendingChat();
      if (data) {
        // Send it directly to chat to trigger AI celebration
        chat.sendMessage({ text: data.text });
      }
    }
  },
  { immediate: true }
);

watch(
  () => data.value?.messages,
  (newMessages) => {
    if (newMessages && newMessages.length > 0) {
      chat.messages = newMessages;
      scrollToBottom(false);
    }
  },
);

watch(
  () => chat.messages.length,
  () => {
    scrollToBottom(true);
  },
);

onMounted(() => {
  scrollToBottom(false);
  checkDriveStatus();
  if (data.value?.messages.length === 1 && !route.query.chat_q) {
    chat.regenerate();
  }
});
</script>
