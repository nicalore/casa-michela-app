import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../core/language/app_language.dart';
import 'pdf_tab.dart';

// Scope of a documents worker browsers may still hold: they are told to let it go.
const String _formerScope = '/documenti/';

bool _formerWorkerGone = false;

String get _defaultWaiting => tr('Generazione del PDF in corso&hellip;', 'Generating the PDF&hellip;');

String _waitingPage(String title, String? waiting) => '''
<!doctype html><html lang="${AppLanguages.current.value.key}"><head><meta charset="utf-8">
<title>${_escaped(title)}</title>
<style>
  html,body{margin:0;height:100%;background:#EBEFF3;color:#5B7280;
    font-family:system-ui,-apple-system,"Segoe UI",sans-serif}
  body{display:flex;flex-direction:column}
  #wait{flex:1;display:flex;align-items:center;justify-content:center;
    font-size:15px;text-align:center;padding:0 24px}
  #docs{flex:1;position:relative;min-height:0}
  #docs embed{position:absolute;top:0;left:0;width:100%;height:100%;border:0;visibility:hidden}
  #docs img{position:absolute;top:0;right:0;bottom:0;left:0;margin:auto;max-width:calc(100% - 32px);
    max-height:calc(100% - 32px);object-fit:contain;box-shadow:0 6px 24px rgba(18,58,94,.12)}
  .pick{display:none}
  #switch{flex:0 0 auto;display:flex;gap:6px;padding:7px 16px;background:#EBEFF3;
    border-bottom:1px solid #DDE8E6}
  #switch label{padding:4px 14px;border-radius:999px;border:1px solid #CBD9D6;background:#fff;
    color:#0B6478;font-size:13px;font-weight:600;cursor:pointer}
  #bar{flex:0 0 auto;display:none;padding:7px 16px;background:#EBEFF3;
    border-top:1px solid #DDE8E6;font-size:13px}
  #bar a{display:none;color:#0B6478;font-weight:600;text-decoration:none}
  #bar a:hover{text-decoration:underline}
</style></head>
<body><div id="wait">${waiting == null ? _defaultWaiting : _escaped(waiting)}</div>
<div id="bar"></div></body></html>''';

// The switch is radio buttons and their labels: the tab keeps working with no script, even once
// the app that opened it is gone.
String _pickedRules(int count)
{
  return [
    for (var index = 0; index < count; index++) ...[
      '#pick$index:checked~#docs embed:nth-child(${index + 1}){visibility:visible}',
      '#pick$index:checked~#bar a:nth-child(${index + 1}){display:inline}',
      '#pick$index:checked~#switch label:nth-child(${index + 1})'
          '{background:#0B6478;border-color:#0B6478;color:#fff}',
    ],
  ].join('\n');
}

String _escaped(String text)
{
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

PdfTab? openPdfTabImpl({required String title, String? waiting})
{
  final window = web.window.open('', '_blank');

  if (window == null)
  {
    return null;
  }

  final document = window.document;

  document.open();
  document.write(_waitingPage(title, waiting).toJS);
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

web.File _fileOf(Uint8List bytes, String fileName, {String type = 'application/pdf'})
{
  return web.File(
    [bytes.toJS].toJS,
    fileName,
    web.FilePropertyBag(type: type),
  );
}

class _WebPdfTab implements PdfTab
{
  _WebPdfTab(this.window);

  final web.Window window;

  @override
  void present(Uint8List bytes, {required String fileName})
  {
    _show([(label: '', bytes: bytes, fileName: fileName)]);
  }

  @override
  void presentImage(Uint8List bytes, {required String fileName, required String mimeType})
  {
    _forgetFormerWorker();

    final document = window.document;
    final waiting = document.getElementById('wait');
    final bar = document.getElementById('bar');

    if (waiting == null || bar == null)
    {
      return;
    }

    final url = web.URL.createObjectURL(_fileOf(bytes, fileName, type: mimeType));
    final docs = document.createElement('div')..id = 'docs';

    docs.append(
      (document.createElement('img') as web.HTMLImageElement)
        ..src = url
        ..alt = fileName,
    );
    bar.append(
      (document.createElement('a') as web.HTMLAnchorElement)
        ..href = url
        ..download = fileName
        ..setAttribute('style', 'display:inline')
        ..textContent = tr('Scarica "$fileName"', 'Download "$fileName"'),
    );

    waiting.replaceWith(docs);
    bar.setAttribute('style', 'display:block');

    window.addEventListener(
      'pagehide',
      ((web.Event event) => web.URL.revokeObjectURL(url)).toJS,
    );
  }

  @override
  void presentTogether(List<PdfTabDocument> documents, {String? title})
  {
    if (title != null)
    {
      window.document.title = title;
    }

    _show(documents);
  }

  // Each document stays in this page, from a blob nobody has to ask the site for again, with a
  // link below that saves it under its own name.
  void _show(List<PdfTabDocument> documents)
  {
    _forgetFormerWorker();

    final document = window.document;
    final body = document.body;
    final waiting = document.getElementById('wait');
    final bar = document.getElementById('bar');

    if (body == null || waiting == null || bar == null)
    {
      return;
    }

    final urls = [for (final shown in documents) web.URL.createObjectURL(_fileOf(shown.bytes, shown.fileName))];
    final docs = document.createElement('div')..id = 'docs';
    final switcher = document.createElement('div')..id = 'switch';

    for (final (index, shown) in documents.indexed)
    {
      // In front of everything they pick, as the rules read them.
      body.insertBefore(
        (document.createElement('input') as web.HTMLInputElement)
          ..type = 'radio'
          ..name = 'pick'
          ..id = 'pick$index'
          ..className = 'pick'
          ..checked = index == 0,
        waiting,
      );

      switcher.append(
        (document.createElement('label') as web.HTMLLabelElement)
          ..htmlFor = 'pick$index'
          ..textContent = shown.label,
      );

      docs.append(
        (document.createElement('embed') as web.HTMLEmbedElement)
          ..type = 'application/pdf'
          ..src = urls[index],
      );

      bar.append(
        (document.createElement('a') as web.HTMLAnchorElement)
          ..href = urls[index]
          ..download = shown.fileName
          ..textContent = tr('Scarica "${shown.fileName}"', 'Download "${shown.fileName}"'),
      );
    }

    document.head?.append(document.createElement('style')..textContent = _pickedRules(documents.length));

    if (documents.length > 1)
    {
      body.insertBefore(switcher, waiting);
    }

    waiting.replaceWith(docs);
    bar.setAttribute('style', 'display:block');

    window.addEventListener(
      'pagehide',
      ((web.Event event)
      {
        for (final url in urls)
        {
          web.URL.revokeObjectURL(url);
        }
      }).toJS,
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

    waiting.textContent = tr('$message\nPuoi chiudere questa scheda e riprovare.', '$message\nYou can close this tab and try again.');
  }

  @override
  void close()
  {
    window.close();
  }
}

// Browsers that registered the old worker let it go.
void _forgetFormerWorker()
{
  if (_formerWorkerGone)
  {
    return;
  }

  _formerWorkerGone = true;

  unawaited(() async
  {
    try
    {
      final registration = await web.window.navigator.serviceWorker.getRegistration(_formerScope).toDart;

      await registration?.unregister().toDart;
    }
    on Object
    {
      // Nothing registered, or no workers here at all: nothing to let go.
    }
  }());
}
