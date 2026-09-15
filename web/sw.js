/* Bookstore Manager — service worker.

   Its only job is to make the app itself openable with no connection. Business
   data does not pass through here; that lives in IndexedDB and the outbox
   inside the page. Bump CACHE when you deploy so old shells are cleared out. */

const CACHE = 'bookstore-shell-v2';

const SHELL = [
  './',
  './index.html',
  './vendor/supabase.js',
  './fonts/open-sans-latin-400-normal.woff2',
  './fonts/open-sans-latin-600-normal.woff2',
  './fonts/open-sans-latin-700-normal.woff2',
  './fonts/montserrat-latin-600-normal.woff2',
  './fonts/montserrat-latin-700-normal.woff2',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // Never cache Supabase traffic — the sync engine needs real answers, and a
  // cached "success" would make the app think a write had landed.
  if (url.origin !== self.location.origin) return;

  // Pages: try the network first so a new deploy is picked up on the next
  // launch, fall back to the cached shell when there is nothing to reach.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then(res => {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put('./index.html', copy));
          return res;
        })
        .catch(() => caches.match('./index.html').then(r => r || caches.match('./')))
    );
    return;
  }

  // Everything else: serve from cache, refresh it in the background.
  event.respondWith(
    caches.match(req).then(hit => {
      const live = fetch(req).then(res => {
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy));
        }
        return res;
      }).catch(() => hit);
      return hit || live;
    })
  );
});
