import 'dart:typed_data';

import 'calendar_pdf_tab_stub.dart' if (dart.library.js_interop) 'calendar_pdf_tab_web.dart';

abstract interface class CalendarPdfTab
{
  void present(Uint8List bytes, {required String fileName});

  void fail(String message);

  void close();
}

CalendarPdfTab? openPdfTab({required String title}) => openPdfTabImpl(title: title);

bool downloadPdf(Uint8List bytes, {required String fileName}) =>
    downloadPdfImpl(bytes, fileName: fileName);
