import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'pdf_tab.dart';

// The address the service worker answers on. Its own file lives at the root,
// which is what lets it claim a scope below it.
const String _scope = '/documenti/';

const String _workerScript = 'documents_sw.js';

// Registering and activating a worker is quick; if it is not, the blob is
// there and waiting.
const Duration _workerTimeout = Duration(seconds: 4);

String _waitingPage(String title) => '''
<!doctype html><html lang="it"><head><meta charset="utf-8">
<title>${_escaped(title)}</title>
<style>
  html,body{margin:0;height:100%;background:#EBEFF3;color:#5B7280;
    font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
  body{display:flex;flex-direction:column}
  #wait{flex:1;display:flex;align-items:center;justify-content:center;
    font-size:15px;text-align:center;padding:0 24px}
  embed{flex:1;width:100%;border:0;display:block;min-height:0}
  #bar{flex:0 0 auto;display:none;padding:7px 16px;background:#EBEFF3;
    border-top:1px solid #DDE8E6;font-size:13px}
  #bar a{color:#0B6478;font-weight:600;text-decoration:none}
  #bar a:hover{text-decoration:underline}
</style></head>
<body><div id="wait">Generazione del PDF in corso&hellip;</div>
<div id="bar"><a id="save" download>Scarica il PDF</a></div></body></html>''';

String _escaped(String text)
{
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

PdfTab? openPdfTabImpl({required String title})
{
  final window = web.window.open('', '_blank');

  if (window == null)
  {
    return null;
  }

  final document = window.document;

  document.open();
  document.write(_waitingPage(title).toJS);
  document.close();

  return _WebPdfTab(window);
}

bool downloadPdfImpl(Uint8List bytes, {required String fileName})
{
  final url = web.URL.createObjectURL(_fileOf(bytes, fileName));
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));

  return true;
}

web.File _fileOf(Uint8List bytes, String fileName)
{
  return web.File(
    [bytes.toJS].toJS,
    fileName,
    web.FilePropertyBag(type: 'application/pdf'),
  );
}

class _WebPdfTab implements PdfTab
{
  _WebPdfTab(this.window);

  final web.Window window;

  @override
  void present(Uint8List bytes, {required String fileName})
  {
    // Handing the document to the worker gives it a readable address, and the
    // viewer's own download button names the file after it. A blob would only
    // ever be called after its UUID.
    unawaited(_serveFromWorker(bytes, fileName: fileName).then((served)
    {
      if (!served)
      {
        _presentBlob(bytes, fileName: fileName);
      }
    }));
  }

  Future<bool> _serveFromWorker(Uint8List bytes, {required String fileName}) async
  {
    try
    {
      final worker = await _activeWorker().timeout(_workerTimeout);

      if (worker == null)
      {
        return false;
      }

      // A folder of its own per document: two forms open at once must not
      // answer at the same address, and the browser reads the name from the
      // last segment either way.
      final String path = '$_scope${DateTime.now().microsecondsSinceEpoch}/'
          '${Uri.encodeComponent(fileName)}';

      await _handOver(worker, path: path, bytes: bytes, fileName: fileName)
          .timeout(_workerTimeout);

      // Absolute: the tab is still on about:blank, which is no base to resolve
      // a path against.
      window.location.replace('${web.window.location.origin}$path');

      return true;
    }
    on Object
    {
      return false;
    }
  }

  Future<void> _handOver(
    web.ServiceWorker worker, {
    required String path,
    required Uint8List bytes,
    required String fileName,
  }) async
  {
    final channel = web.MessageChannel();
    final answered = Completer<void>();

    channel.port1.onmessage = ((web.MessageEvent event)
    {
      if (!answered.isCompleted)
      {
        answered.complete();
      }
    }).toJS;
    channel.port1.start();

    final message = JSObject()
      ..setProperty('path'.toJS, path.toJS)
      ..setProperty('fileName'.toJS, fileName.toJS)
      ..setProperty('bytes'.toJS, bytes.toJS);

    // The port has to be transferred; the bytes are copied, because the blob
    // fallback still needs them on this side.
    worker.postMessage(message, <JSAny>[channel.port2].toJS);

    return answered.future;
  }

  void _presentBlob(Uint8List bytes, {required String fileName})
  {
    final url = web.URL.createObjectURL(_fileOf(bytes, fileName));
    final document = window.document;

    final embed = document.createElement('embed') as web.HTMLEmbedElement
      ..type = 'application/pdf'
      ..src = url;

    document.getElementById('wait')?.replaceWith(embed);

    final bar = document.getElementById('bar');
    final save = document.getElementById('save') as web.HTMLAnchorElement?;

    // Only here does the bar earn its place: without the worker this link is
    // the one way to save the file under its own name.
    if (bar != null && save != null)
    {
      save
        ..href = url
        ..download = fileName
        ..textContent = 'Scarica "$fileName"';

      bar.setAttribute('style', 'display:block');
    }

    window.addEventListener(
      'pagehide',
      ((web.Event event) => web.URL.revokeObjectURL(url)).toJS,
    );
  }

  @override
  void fail(String message)
  {
    final waiting = window.document.getElementById('wait');

    if (waiting == null)
    {
      return;
    }

    waiting.textContent = '$message\nPuoi chiudere questa scheda e riprovare.';
  }

  @override
  void close()
  {
    window.close();
  }
}

Future<web.ServiceWorker?> _activeWorker() async
{
  final container = web.window.navigator.serviceWorker;
  final registration = await container
      .register(_workerScript.toJS, web.RegistrationOptions(scope: _scope))
      .toDart;

  final web.ServiceWorker? active = registration.active;

  if (active != null)
  {
    return active;
  }

  final web.ServiceWorker? pending = registration.installing ?? registration.waiting;

  if (pending == null)
  {
    return null;
  }

  final ready = Completer<web.ServiceWorker?>();

  void settle()
  {
    if (pending.state == 'activated' && !ready.isCompleted)
    {
      ready.complete(registration.active ?? pending);
    }
  }

  pending.onstatechange = ((web.Event event) => settle()).toJS;
  settle();

  return ready.future;
}
