import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> downloadFileImpl(Uint8List bytes, {required String fileName, required String mimeType}) async
{
  final file = web.File([bytes.toJS].toJS, fileName, web.FilePropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(file);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));

  return true;
}
