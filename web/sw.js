// Keeps Bolt working with no signal, as it does on a phone. tool/build_web.dart
// fills in VERSION and FILES. A new build changes this file, which makes the
// browser fetch the whole new set in the background; it opens on the next launch.
const VERSION = '__BOLT_VERSION__';
const FILES = ['__BOLT_FILES__'];
const CACHE = `bolt-${VERSION}`;
const FONTS = 'bolt-fonts';

// Chrome loads its own CanvasKit, every other browser (an iPhone's too) the plain one.
const NEEDED = FILES.filter((f) => !f.startsWith('canvaskit/chromium/') || self.navigator.userAgent.includes('Chrome/'));

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(NEEDED)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(names.filter((n) => n !== CACHE && n !== FONTS).map((n) => caches.delete(n))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Flutter's fallback fonts for symbols, kept after their first download.
  if (url.hostname === 'fonts.gstatic.com') {
    event.respondWith(
      caches.open(FONTS).then((c) =>
        c.match(req).then((hit) => hit || fetch(req).then((res) => {
          if (res.ok) c.put(req, res.clone());
          return res;
        })),
      ),
    );
    return;
  }

  // Everything else from elsewhere (coach list, news) is always live.
  if (url.origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    event.respondWith(caches.match('index.html').then((hit) => hit || fetch(req)));
    return;
  }

  event.respondWith(
    caches.open(CACHE).then((c) =>
      c.match(req, { ignoreSearch: true }).then((hit) => hit || fetch(req).then((res) => {
        if (res.ok) c.put(req, res.clone());
        return res;
      })),
    ),
  );
});
