// Serves a generated document at a readable address, so the browser's own PDF
// viewer names a download after the document instead of after the UUID of a
// blob: URL — which is all it can see otherwise.
//
// The bytes are held here, in the worker's memory, and never written to Cache
// Storage: a filled enrolment form carries a member's data, health notes
// included, and has no business reaching the disk. A worker that gets shut
// down forgets them, and the tab is regenerated from the wizard.

const SCOPE = '/documenti/';

// Long enough to print and to reload the tab once or twice, short enough that
// a form does not linger in a worker that stays warm.
const LIFETIME_MS = 5 * 60 * 1000;

const held = new Map();

self.addEventListener('install', (event) => event.waitUntil(self.skipWaiting()));

self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('message', (event) => {
  const { path, bytes, fileName } = event.data;

  held.set(path, { bytes, fileName });
  setTimeout(() => held.delete(path), LIFETIME_MS);

  // The page waits for this before it sends the tab to the new address.
  event.ports[0].postMessage(true);
});

self.addEventListener('fetch', (event) => {
  const path = new URL(event.request.url).pathname;

  if (!path.startsWith(SCOPE)) {
    return;
  }

  const document = held.get(path);

  if (document === undefined) {
    event.respondWith(gone());

    return;
  }

  event.respondWith(new Response(document.bytes, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': disposition(document.fileName),
      'Cache-Control': 'no-store',
    },
  }));
});

// A name carries spaces and may carry accents: the quoted form is folded to
// ASCII for readers that only know it, the encoded one carries the real name.
function disposition(fileName) {
  const folded = fileName.normalize('NFKD').replace(/[^\x20-\x7E]/g, '').replace(/["\\]/g, '');

  return `inline; filename="${folded}"; filename*=UTF-8''${encodeURIComponent(fileName)}`;
}

function gone() {
  return new Response(
    '<!doctype html><meta charset="utf-8"><title>Documento scaduto</title>'
    + '<p style="font:15px system-ui;color:#5B7280;padding:24px">Questo documento non è '
    + 'più disponibile: chiudi la scheda e generalo di nuovo.</p>',
    { status: 404, headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
}
