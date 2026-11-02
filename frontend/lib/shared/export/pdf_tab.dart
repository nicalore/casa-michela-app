import 'dart:typed_data';

import 'pdf_tab_stub.dart' if (dart.library.js_interop) 'pdf_tab_web.dart';

// One of several documents sharing a tab, named on the switch above them.
typedef PdfTabDocument = ({String label, Uint8List bytes, String fileName});

abstract interface class PdfTab
{
  void present(Uint8List bytes, {required String fileName});

  // Several documents in this one tab, a switch on top choosing which shows; no title keeps the tab's.
  void presentTogether(List<PdfTabDocument> documents, {String? title});

  void fail(String message);

  void close();
}

PdfTab? openPdfTab({required String title}) => openPdfTabImpl(title: title);

bool downloadPdf(Uint8List bytes, {required String fileName}) =>
    downloadPdfImpl(bytes, fileName: fileName);

// A document bound for the tab opened for it, if the browser let it open.
typedef PdfTabRequest = ({PdfTab? tab, String label, String fileName, Future<Uint8List> Function() bytes});

// A click opens one tab: documents whose tab was refused join the first tab that opened, with
// that tab's own, behind a switch. With no tab at all they are downloaded, and this says true.
Future<bool> presentPdfs(List<PdfTabRequest> requests, {String? title}) async
{
  final PdfTab? host = requests.map((request) => request.tab).nonNulls.firstOrNull;
  final bool sharing = requests.any((request) => request.tab == null);
  final List<PdfTabDocument> together = [];
  var downloaded = false;

  for (final request in requests)
  {
    final Uint8List bytes = await request.bytes();
    final PdfTab? tab = request.tab;

    if (host == null)
    {
      downloaded = downloadPdf(bytes, fileName: request.fileName) || downloaded;
    }
    else if (tab != null && (!sharing || tab != host))
    {
      tab.present(bytes, fileName: request.fileName);
    }
    else
    {
      together.add((label: request.label, bytes: bytes, fileName: request.fileName));
    }
  }

  if (host != null && together.isNotEmpty)
  {
    host.presentTogether(together, title: title);
  }

  return downloaded;
}
