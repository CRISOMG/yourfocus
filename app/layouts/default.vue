<script setup lang="ts">
import TimelineModal from "~/components/timeline-modal .vue";

const openProfileModal = ref(false);
const openTimelineModal = ref(false);
const openShortcutsModal = ref(false);
const openWebhookModal = ref(false);
const openCredentialsModal = ref(false);
const openNotesModal = ref(false);
const openPushNotificationsModal = ref(false);
const openInstallAppModal = ref(false);
const openOfflineQueueModal = ref(false);
const openInboxModal = ref(false);

// Provide modal controls to child pages/components
provideLayoutModals({
  openNotes: () => {
    openNotesModal.value = true;
  },
  openTimeline: () => {
    openTimelineModal.value = true;
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

onMounted(() => {
  if (route.query.inbox === "open") {
    openInboxModal.value = true;
    // Clean up query params to avoid re-triggering on navigation
    router.replace({ query: { ...route.query, inbox: undefined, action_id: undefined } });
  }
});

// Also watch for route changes (SPA navigation from SW)
watch(
  () => route.query.inbox,
  (val) => {
    if (val === "open") {
      openInboxModal.value = true;
      router.replace({ query: { ...route.query, inbox: undefined, action_id: undefined } });
    }
  },
);
</script>

<template>
  <UContainer class="mb-16 p-0">
    <AppHeader
      @open-timeline="openTimelineModal = true"
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
    <template v-if="openTimelineModal">
      <TimelineModal v-model="openTimelineModal" />
    </template>
    <ShortcutsModal v-model="openShortcutsModal" />
    <WebhookModal v-model="openWebhookModal" />
    <CredentialsModal v-model="openCredentialsModal" />
    <NotesModal v-model="openNotesModal" />
    <PushNotificationsModal v-model="openPushNotificationsModal" />
    <InstallAppModal v-model="openInstallAppModal" />
    <OfflineQueueModal v-model="openOfflineQueueModal" />
    <InboxModal v-model="openInboxModal" />
  </UContainer>
</template>
