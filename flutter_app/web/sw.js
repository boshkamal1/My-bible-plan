const CACHE = 'bible-journey-flutter-v33';
const CORE = ['./', 'index.html', 'manifest.json', 'flutter_bootstrap.js', 'app_shell.js', 'firebase_loader.js', 'downloads.js', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/maskable-512.png'];

self.addEventListener('push', (event) => {
  let message = {};
  try { message = event.data ? event.data.json() : {}; } catch (_) {}
  if (!message || typeof message !== 'object') message = {};
  event.waitUntil(self.registration.showNotification(
    message.title || 'وقت قراءة الكتاب المقدس', {
      body: message.body || 'قراءة اليوم مستنياك',
      icon: 'icons/icon-192.png',
      data: {url: message.url || './'},
    },
  ));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  let target = new URL('./', self.location.href);
  try {
    const proposed = new URL(event.notification.data?.url || './', self.location.href);
    if (proposed.origin === self.location.origin) target = proposed;
  } catch (_) {}
  event.waitUntil(clients.openWindow(target.href));
});

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key.startsWith('bible-journey-flutter-') && key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  // Never cache Firebase Auth helper responses or user/account endpoints.
  const staticAsset = /^\/(assets|canvaskit|icons)\//.test(url.pathname) ||
    ['/main.dart.js', '/main.dart.wasm', '/main.dart.mjs', '/app_shell.js', '/firebase_loader.js', '/downloads.js', '/flutter.js', '/flutter_bootstrap.js', '/push.js', '/manifest.json'].includes(url.pathname);
  if (request.mode !== 'navigate' && !staticAsset) return;
  const cacheResponse = (key, response) => {
    if (response.ok && response.type !== 'opaque') {
      const copy = response.clone();
      event.waitUntil(caches.open(CACHE).then((cache) => cache.put(key, copy)).catch(() => {}));
    }
    return response;
  };
  if (request.mode === 'navigate') {
    if (url.pathname.startsWith('/__/')) return;
    event.respondWith(fetch(request).then((response) => {
      return cacheResponse('./', response);
    }).catch(async () => (await (await caches.open(CACHE)).match('./')) || Response.error()));
    return;
  }

  // Static assets are tied to this release's cache. Bootstrap stays network-first
  // so a new release is discovered even while an older worker controls the tab.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(request);
    if (cached && url.pathname !== '/flutter_bootstrap.js') return cached;
    try { return cacheResponse(request, await fetch(request)); }
    catch (_) { return cached || Response.error(); }
  })());
});
