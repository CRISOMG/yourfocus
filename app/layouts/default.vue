<script setup lang="ts">
import AnalyticsModal from "~/components/analytics-modal.vue";

const openProfileModal = ref(false);
const openAnalyticsModal = ref(false);
const openShortcutsModal = ref(false);
const openWebhookModal = ref(false);
const openCredentialsModal = ref(false);
const openNotesModal = ref(false);
const openPushNotificationsModal = ref(false);
const openInstallAppModal = ref(false);
const openOfflineQueueModal = ref(false);
const openInboxModal = ref(false);

// Provide modal controls to child pages/components
import { useTaskController } from "~/composables/task/use-task-controller";

const isCreateFromTemplateModalOpen = useState<boolean>("inbox-create-task-modal-open", () => false);
const taskController = useTaskController();

provideLayoutModals({
  openNotes: () => {
    openNotesModal.value = true;
  },
  openAnalytics: () => {
    openAnalyticsModal.value = !openAnalyticsModal.value;
  },
  openProfile: () => {
    openProfileModal.value = true;
  },
  openShortcuts: () => {
    openShortcutsModal.value = true;
  },
  openWebhook: () => {
    openWebhookModal.value = true;
  },
  openCredentials: () => {
    openCredentialsModal.value = true;
  },
  openPushNotifications: () => {
    openPushNotificationsModal.value = true;
  },
  openInstallApp: () => {
    openInstallAppModal.value = true;
  },
  openOfflineQueue: () => {
    openOfflineQueueModal.value = true;
  },
  openInbox: () => {
    openInboxModal.value = true;
  },
});

// Deep link: open inbox from push notification click (?inbox=open&action_id=...)
const route = useRoute();
const router = useRouter();

onMounted(async () => {
  if (route.query.inbox === "open") {
    openInboxModal.value = true;
    router.replace({
      query: { ...route.query, inbox: undefined },
    });
  }

  if (route.query.action_id) {
    const actionId = route.query.action_id as string;
    
    // Clean up query param immediately to avoid double execution on refresh
    router.replace({
      query: { ...route.query, action_id: undefined },
    });

    try {
      const supabase = useSupabaseClient();
      const { data, error } = await supabase
        .from("inbox_actions")
        .select("*")
        .eq("id", actionId)
        .single();
        
      if (!error && data) {
        const { dispatchAction, markAsCompleted } = useInboxController();
        dispatchAction(data as any);
        await markAsCompleted(data as any);
      }
    } catch (e) {
      console.error("Error auto-dispatching inbox action:", e);
    }
  }
});

// Also watch for route changes (SPA navigation from SW)
watch(
  () => route.query.inbox,
  (val) => {
    if (val === "open") {
      openInboxModal.value = true;
      router.replace({
        query: { ...route.query, inbox: undefined },
      });
    }
  },
);

watch(
  () => route.query.action_id,
  async (val) => {
    if (val) {
      const actionId = val as string;
      router.replace({
        query: { ...route.query, action_id: undefined },
      });

      try {
        const supabase = useSupabaseClient();
        const { data, error } = await supabase
          .from("inbox_actions")
          .select("*")
          .eq("id", actionId)
          .single();
          
        if (!error && data) {
          const { dispatchAction, markAsCompleted } = useInboxController();
          dispatchAction(data as any);
          await markAsCompleted(data as any);
        }
      } catch (e) {
        console.error("Error auto-dispatching inbox action from route change:", e);
      }
    }
  },
);
</script>

<template>
  <UContainer class="mb-16 p-0">
    <AppHeader
      @open-analytics="openAnalyticsModal = true"
      @open-profile="openProfileModal = true"
      @open-shortcuts="openShortcutsModal = true"
      @open-webhook="openWebhookModal = true"
      @open-credentials="openCredentialsModal = true"
      @open-notes="openNotesModal = true"
      @open-push-notifications="openPushNotificationsModal = true"
      @open-install-app="openInstallAppModal = true"
      @open-offline-queue="openOfflineQueueModal = true"
      @open-inbox="openInboxModal = true"
    />
    <USeparator />

    <slot />

    <!-- Modals managed at layout level -->
    <template v-if="openProfileModal">
      <UserProfileModal v-model="openProfileModal" />
    </template>
    <template v-if="openAnalyticsModal">
      <AnalyticsModal v-model="openAnalyticsModal" />
    </template>
    <ShortcutsModal v-model="openShortcutsModal" />
    <WebhookModal v-model="openWebhookModal" />
    <CredentialsModal v-model="openCredentialsModal" />
    <NotesModal v-model="openNotesModal" />
    <PushNotificationsModal v-model="openPushNotificationsModal" />
    <InstallAppModal v-model="openInstallAppModal" />
    <OfflineQueueModal v-model="openOfflineQueueModal" />
    <InboxModal v-model="openInboxModal" />
    <CreateTaskFromTemplateModal
      v-model:open="isCreateFromTemplateModalOpen"
      @task-created="taskController.loadTasks()"
    />
  </UContainer>
</template>
