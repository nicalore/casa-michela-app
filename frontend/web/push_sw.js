// Shows the notifications the server pushes and leads a click back to the app.
//
// Scoped to /push/, where no page lives: it answers no request and controls no
// tab. The tabs hear from it on a BroadcastChannel.

const CHANNEL = 'casa-michela-notifications';

// The favicon, as the browser's tab shows it; the app keeps the round logo.
const ICON = '/favicon.png';

// Mirrors _openedParameter in device_push_web.dart: tells a new tab what was clicked.
const OPENED = 'notification';

self.addEventListener('install', (event) => event.waitUntil(self.skipWaiting()));

self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  const message = event.data ? event.data.json() : null;

  event.waitUntil(message && message.type === 'dismiss' ? dismiss(message.id) : arrive(message));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(open(event.notification.data ? event.notification.data.id : null));
});

function tell(news) {
  const channel = new BroadcastChannel(CHANNEL);

  channel.postMessage(news);
  channel.close();
}

function windows() {
  return self.clients.matchAll({ type: 'window', includeUncontrolled: true });
}

async function arrive(notification) {
  if (!notification) {
    return;
  }

  // The app in front shows it itself, unless Safari, which revokes after three silent pushes.
  if (notification.skippable) {
    const open = await windows();

    if (open.some((client) => client.visibilityState === 'visible' && client.focused)) {
      tell({ type: 'arrived', id: notification.id, quiet: true });
      return;
    }
  }

  tell({ type: 'arrived', id: notification.id, quiet: false });

  await self.registration.showNotification(notification.title, {
    body: notification.body,
    icon: ICON,
    tag: `notification-${notification.id}`,
    data: { id: notification.id },
  });
}

// Read or withdrawn elsewhere: off the tray here too.
async function dismiss(id) {
  const shown = await self.registration.getNotifications({ tag: `notification-${id}` });

  shown.forEach((notification) => notification.close());
  tell({ type: 'dismissed', id });
}

async function open(id) {
  const [client] = await windows();

  if (!client) {
    await self.clients.openWindow(id === null ? '/' : `/?${OPENED}=${id}`);
    return;
  }

  await client.focus();

  if (id !== null) {
    tell({ type: 'opened', id });
  }
}
