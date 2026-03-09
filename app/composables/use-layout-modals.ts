// Composable to share modal controls between layout and pages/components
// Uses provide/inject pattern for cross-component communication

export interface LayoutModals {
  openNotes: () => void;
  openAnalytics: () => void;
  openProfile: () => void;
  openShortcuts: () => void;
  openWebhook: () => void;
  openCredentials: () => void;
  openPushNotifications: () => void;
  openInstallApp: () => void;
  openOfflineQueue: () => void;
  openInbox: () => void;
}

const LAYOUT_MODALS_KEY = "layout-modals" as const;

export function provideLayoutModals(modals: LayoutModals) {
  provide(LAYOUT_MODALS_KEY, modals);
}

export function useLayoutModals(): LayoutModals {
  const modals = inject<LayoutModals>(LAYOUT_MODALS_KEY);
  if (!modals) {
    // Fallback noop if used outside provider
    return {
      openNotes: () => {},
      openAnalytics: () => {},
      openProfile: () => {},
      openShortcuts: () => {},
      openWebhook: () => {},
      openCredentials: () => {},
      openPushNotifications: () => {},
      openInstallApp: () => {},
      openOfflineQueue: () => {},
      openInbox: () => {},
    };
  }
  return modals;
}
