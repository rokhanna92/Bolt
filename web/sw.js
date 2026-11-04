// Keeps Bolt working with no signal, as it does on a phone. tool/build_web.dart
// fills in VERSION and FILES. A new build changes this file, which makes the
// browser fetch the whole new set in the background; it opens on the next launch.
const VERSION = '__BOLT_VERSION__';
const FILES = ['__BOLT_FILES__'];
const CACHE = `bolt-${VERSION}`;
const FONTS = 'bolt-fonts';

// Fetch only what this browser will run, the same way Flutter's loader picks:
// WebAssembly with Skwasm where WasmGC exists, else JavaScript with CanvasKit.
const WASM_GC = !self.navigator.userAgent.includes('Firefox/') &&
  WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 95, 1, 120, 0]));
const CHROME = self.navigator.userAgent.includes('Chrome/');
const ENGINE = WASM_GC
  ? (CHROME ? 'canvaskit/skwasm.' : 'canvaskit/skwasm_heavy.')
  : (CHROME ? 'canvaskit/chromium/canvaskit.' : 'canvaskit/canvaskit.');
const NEEDED = FILES.filter((f) => {
  if (f.startsWith('canvaskit/')) return f.startsWith(ENGINE);
  if (f.startsWith('main.dart.')) return f.endsWith('.js') !== WASM_GC;
  return true;
});

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

  // The page is kept as './': hosts like Cloudflare redirect index.html to it,
  // and Chrome refuses to open a saved redirect as a page.
  if (req.mode === 'navigate') {
    event.respondWith(caches.match('./').then((hit) => (hit && !hit.redirected ? hit : fetch(req))));
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
