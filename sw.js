/* DevOS Habit Tracker — Service Worker */
const CACHE = 'devos-v1';
const STATIC = [
  './index.html',
  './journal.html',
  './stats.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png',
];

/* ── INSTALL: cache static assets ── */
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(STATIC))
  );
  self.skipWaiting();
});

/* ── ACTIVATE: remove old caches ── */
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

/* ── FETCH strategy ── */
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  // ให้ network จัดการ: Supabase API, Google Fonts, CDN
  const passThrough = [
    'supabase.co',
    'fonts.googleapis.com',
    'fonts.gstatic.com',
    'cdn.jsdelivr.net',
  ];
  if (passThrough.some(h => url.hostname.includes(h))) return;

  // HTML files: network-first (ได้ข้อมูลล่าสุด), fallback to cache
  if (e.request.destination === 'document') {
    e.respondWith(
      fetch(e.request)
        .then(res => {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
          return res;
        })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  // อื่นๆ: cache-first
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});
