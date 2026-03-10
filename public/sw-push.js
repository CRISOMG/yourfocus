// Service Worker for Web Push Notifications
// Receives push events and displays native notifications

self.addEventListener("push", function (event) {
  let data = {};
  try {
    if (event.data) {
      data = event.data.json();
    }
  } catch (e) {
    console.error("Error parsing push data:", e);
    try {
      data = { body: event.data.text() };
    } catch (e2) { }
  }

  const title = data.title || "YourFocus";
  const options = {
    body: data.body || "Tienes una notificación",
    icon: data.icon || "/check-focus.png",
    badge: data.badge || "/check-focus.png",
    data: {
      url: data.url || "/",
      timestamp: data.timestamp || Date.now(),
    },
    tag: data.tag || "yourfocus-notification",
    renotify: true,
    requireInteraction: false,
    vibrate: [200, 100, 200],
  };

  event.waitUntil(
    self.registration.showNotification(title, options).catch((err) => {
      console.error("Error showing notification:", err);
    })
  );
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();

  // Ensure the URL is absolute relative to the Service Worker's origin
  const urlToOpen = new URL(event.notification.data?.url || "/", self.location.origin).href;

  event.waitUntil(
    clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then(function (windowClients) {
        // Find if there is any window for our origin
        for (const client of windowClients) {
          if (client.url.startsWith(self.location.origin) && "focus" in client) {
            // Instead of just focusing, let's try to navigate it so Vue Router catches the query param
            client.navigate(urlToOpen);
            return client.focus();
          }
        }
        // Open a new window if none exists
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

// Handle service worker activation
self.addEventListener("activate", function (event) {
  event.waitUntil(clients.claim());
});
