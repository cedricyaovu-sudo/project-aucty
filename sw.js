// Aucty service worker
// Strategy:
//   - Navigations (HTML): network-first, fall back to cached index.html (offline).
//   - CDN assets (unpkg, jsdelivr): cache-first (they're versioned, immutable).
//   - Supabase (*.supabase.co / *.supabase.in / realtime websockets): NEVER cached.
//   - Everything else same-origin: stale-while-revalidate.

const VERSION = 'aucty-v1';
const STATIC_CACHE = `${VERSION}-static`;
const RUNTIME_CACHE = `${VERSION}-runtime`;

const PRECACHE = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
];

const CDN_HOSTS = new Set([
  'unpkg.com',
  'cdn.jsdelivr.net',
]);

const isSupabase = (url) =>
  url.hostname.endsWith('.supabase.co') ||
  url.hostname.endsWith('.supabase.in') ||
  url.hostname.includes('supabase');

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== STATIC_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // Never intercept Supabase traffic (auth, data, realtime).
  if (isSupabase(url)) return;

  // Navigations → network-first, fall back to cached shell.
  if (req.mode === 'navigate' || req.destination === 'document') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(RUNTIME_CACHE).then((c) => c.put(req, copy));
          return res;
        })
        .catch(() =>
          caches.match(req).then((c) => c || caches.match('./index.html'))
        )
    );
    return;
  }

  // CDN assets → cache-first (they're content-addressed).
  if (CDN_HOSTS.has(url.hostname)) {
    event.respondWith(
      caches.match(req).then((cached) =>
        cached ||
        fetch(req).then((res) => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(RUNTIME_CACHE).then((c) => c.put(req, copy));
          }
          return res;
        })
      )
    );
    return;
  }

  // Same-origin & misc → stale-while-revalidate.
  if (url.origin === location.origin) {
    event.respondWith(
      caches.match(req).then((cached) => {
        const network = fetch(req)
          .then((res) => {
            if (res.ok) {
              const copy = res.clone();
              caches.open(RUNTIME_CACHE).then((c) => c.put(req, copy));
            }
            return res;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
  }
});

// Allow the page to trigger a refresh of the SW (e.g. after deploy).
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
