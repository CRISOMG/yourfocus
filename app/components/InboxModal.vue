<script setup lang="ts">
import { useAuthStore } from "~/stores/auth";
import { actionTypeMeta, useInboxController, type InboxAction } from "~/composables/inbox/use-inbox-controller";

const open = defineModel<boolean>({ default: false });

const {
  inboxActions,
  pendingActions,
  completedActions,
  loading,
  unreadCount,
  fetchInboxActions,
  markAsCompleted,
  dismissAction,
  dispatchAction
} = useInboxController();

const confirmingReExecution = ref<string | null>(null);

async function executeAction(action: InboxAction) {
  // If already completed, ask for confirmation to re-execute
  if (action.status === "completed") {
    if (confirmingReExecution.value !== action.id) {
      confirmingReExecution.value = action.id;
      return;
    }
    confirmingReExecution.value = null;
  }

  // If action_type is NONE, just mark as completed
  if (action.action_type === "NONE") {
    await markAsCompleted(action);
    return;
  }

  // Dispatch the action
  dispatchAction(action);

  // Mark as completed and increment execution_count
  await markAsCompleted(action);
}

function formatTimeAgo(dateStr: string): string {
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "Ahora";
  if (diffMin < 60) return `Hace ${diffMin}min`;
  const diffHours = Math.floor(diffMin / 60);
  if (diffHours < 24) return `Hace ${diffHours}h`;
  const diffDays = Math.floor(diffHours / 24);
  return `Hace ${diffDays}d`;
}

function cancelReExecution() {
  confirmingReExecution.value = null;
}

// Load on open
watch(open, (isOpen) => {
  if (isOpen) {
    fetchInboxActions();
    confirmingReExecution.value = null;
  }
});
</script>

<template>
  <UModal
    v-model:open="open"
    title="Inbox"
    :ui="{ content: 'sm:max-w-lg' }"
  >
    <template #body>
      <div class="space-y-4">
        <!-- Loading -->
        <div v-if="loading" class="flex justify-center py-8">
          <UIcon name="i-lucide-loader-2" class="animate-spin text-2xl" />
        </div>

        <!-- Empty state -->
        <div
          v-else-if="inboxActions.length === 0"
          class="text-center py-8 text-neutral-500"
        >
          <UIcon name="i-lucide-inbox" class="text-4xl mb-2" />
          <p class="text-sm">No tienes acciones pendientes</p>
        </div>

        <template v-else>
          <!-- Pending actions -->
          <div v-if="pendingActions.length > 0">
            <p
              class="text-xs font-semibold text-neutral-400 uppercase tracking-wide mb-2"
            >
              Pendientes ({{ pendingActions.length }})
            </p>
            <div class="space-y-2">
              <div
                v-for="action in pendingActions"
                :key="action.id"
                class="group flex items-start gap-3 p-3 rounded-lg border border-neutral-200 dark:border-neutral-700 hover:bg-neutral-50 dark:hover:bg-neutral-800/50 transition-colors"
              >
                <!-- Action type icon -->
                <div
                  class="flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center bg-primary-100 dark:bg-primary-900/30"
                >
                  <UIcon
                    :name="
                      actionTypeMeta[action.action_type]?.icon ||
                      'i-lucide-bell'
                    "
                    class="text-primary-600 dark:text-primary-400"
                  />
                </div>

                <!-- Content -->
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <p
                      class="font-medium text-sm text-gray-900 dark:text-white truncate"
                    >
                      {{ action.title }}
                    </p>
                    <UBadge
                      v-if="action.action_type !== 'NONE'"
                      size="xs"
                      variant="subtle"
                      :color="
                        (actionTypeMeta[action.action_type]?.color as any) ||
                        'neutral'
                      "
                    >
                      {{ actionTypeMeta[action.action_type]?.label }}
                    </UBadge>
                  </div>
                  <p
                    v-if="action.description"
                    class="text-xs text-neutral-500 mt-0.5 line-clamp-1"
                  >
                    {{ action.description }}
                  </p>
                  <p class="text-xs text-neutral-400 mt-1">
                    {{ formatTimeAgo(action.created_at) }}
                  </p>
                </div>

                <!-- Actions -->
                <div
                  class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0"
                >
                  <UButton
                    v-if="action.action_type !== 'NONE'"
                    size="xs"
                    color="primary"
                    variant="soft"
                    :icon="
                      actionTypeMeta[action.action_type]?.icon ||
                      'i-lucide-play'
                    "
                    @click="executeAction(action)"
                  />
                  <UButton
                    v-else
                    size="xs"
                    color="success"
                    variant="soft"
                    icon="i-lucide-check"
                    @click="markAsCompleted(action)"
                  />
                  <UButton
                    size="xs"
                    color="neutral"
                    variant="ghost"
                    icon="i-lucide-x"
                    @click="dismissAction(action)"
                  />
                </div>
              </div>
            </div>
          </div>

          <USeparator v-if="completedActions.length > 0 && pendingActions.length > 0" />

          <!-- Completed actions (re-executable) -->
          <div v-if="completedActions.length > 0">
            <p
              class="text-xs font-semibold text-neutral-400 uppercase tracking-wide mb-2"
            >
              Completadas ({{ completedActions.length }})
            </p>
            <div class="space-y-2">
              <div
                v-for="action in completedActions"
                :key="action.id"
                class="group flex items-start gap-3 p-3 rounded-lg border border-neutral-200/50 dark:border-neutral-700/50 opacity-70 hover:opacity-100 transition-all"
              >
                <div
                  class="flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center bg-neutral-100 dark:bg-neutral-800"
                >
                  <UIcon
                    name="i-lucide-check-circle"
                    class="text-green-500"
                  />
                </div>

                <div class="flex-1 min-w-0">
                  <p
                    class="font-medium text-sm text-gray-600 dark:text-gray-400 truncate line-through"
                  >
                    {{ action.title }}
                  </p>
                  <div class="flex items-center gap-2 mt-1">
                    <span class="text-xs text-neutral-400">
                      {{ formatTimeAgo(action.completed_at || action.created_at) }}
                    </span>
                    <span
                      v-if="action.execution_count > 1"
                      class="text-xs text-neutral-400"
                    >
                      × {{ action.execution_count }}
                    </span>
                  </div>

                  <!-- Re-execution confirmation -->
                  <div
                    v-if="confirmingReExecution === action.id"
                    class="mt-2 flex items-center gap-2"
                  >
                    <p class="text-xs text-amber-600 dark:text-amber-400">
                      ¿Re-ejecutar esta acción?
                    </p>
                    <UButton
                      size="xs"
                      color="primary"
                      variant="soft"
                      @click="executeAction(action)"
                    >
                      Sí
                    </UButton>
                    <UButton
                      size="xs"
                      color="neutral"
                      variant="ghost"
                      @click="cancelReExecution"
                    >
                      No
                    </UButton>
                  </div>
                </div>

                <!-- Re-execute button -->
                <div
                  v-if="
                    action.action_type !== 'NONE' &&
                    confirmingReExecution !== action.id
                  "
                  class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0"
                >
                  <UButton
                    size="xs"
                    color="neutral"
                    variant="soft"
                    icon="i-lucide-repeat"
                    @click="executeAction(action)"
                  />
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>
    </template>

    <template #footer>
      <div class="flex justify-end">
        <UButton @click="open = false" color="neutral" variant="ghost">
          Cerrar
        </UButton>
      </div>
    </template>
  </UModal>
</template>
