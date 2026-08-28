import 'dart:typed_data';

import 'pdf_tab_stub.dart' if (dart.library.js_interop) 'pdf_tab_web.dart';

abstract interface class PdfTab
{
  void present(Uint8List bytes, {required String fileName});

  void fail(String message);

  void close();
}

PdfTab? openPdfTab({required String title}) => openPdfTabImpl(title: title);

bool downloadPdf(Uint8List bytes, {required String fileName}) =>
    downloadPdfImpl(bytes, fileName: fileName);
