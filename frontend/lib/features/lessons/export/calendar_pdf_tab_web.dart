import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'calendar_pdf_tab.dart';

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

CalendarPdfTab? openPdfTabImpl({required String title})
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

class _WebPdfTab implements CalendarPdfTab
{
  _WebPdfTab(this.window);

  final web.Window window;

  @override
  void present(Uint8List bytes, {required String fileName})
  {
    final url = web.URL.createObjectURL(_fileOf(bytes, fileName));
    final document = window.document;

    final embed = document.createElement('embed') as web.HTMLEmbedElement
      ..type = 'application/pdf'
      ..src = url;

    document.getElementById('wait')?.replaceWith(embed);

    final bar = document.getElementById('bar');
    final save = document.getElementById('save') as web.HTMLAnchorElement?;

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
