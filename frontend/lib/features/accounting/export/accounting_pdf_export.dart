import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/accounting_strings.dart';

// Call it straight from the tap: the tab opens before the first await, or the browser blocks it.
Future<void> exportAccountingPdf(
  BuildContext context, {
  required String title,
  required String fileName,
  required Future<Uint8List> Function() bytes,
}) async
{
  final PdfTab? tab = openPdfTab(title: title);

  try
  {
    final bool downloaded = await presentPdfs([(tab: tab, label: title, fileName: fileName, bytes: bytes)]);

    if (downloaded && context.mounted)
    {
      CustomSnackBar.show(context: context, message: kPdfDownloaded, isError: false);
    }
  }
  catch (error)
  {
    tab?.fail(kPdfFailed);

    if (context.mounted)
    {
      CustomSnackBar.show(context: context, message: kPdfFailed, isError: true);
    }
  }
}
