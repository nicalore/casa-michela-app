import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

typedef CalendarPdfAssets = ({ByteData regular, ByteData semiBold, ByteData bold, Uint8List logo});

typedef CalendarPdfFonts = ({
  pw.Font regular,
  pw.Font semiBold,
  pw.Font bold,
  pw.ThemeData theme,
  pw.MemoryImage logo,
});

const String _fontsDirectory = 'assets/fonts';

Future<CalendarPdfAssets>? _pending;

Future<CalendarPdfAssets> calendarPdfAssets()
{
  return _pending ??= _read().catchError((Object error)
  {
    _pending = null;

    throw error;
  });
}

Future<CalendarPdfAssets> _read() async
{
  return (
    regular: await rootBundle.load('$_fontsDirectory/PlusJakartaSans-Regular.ttf'),
    semiBold: await rootBundle.load('$_fontsDirectory/PlusJakartaSans-SemiBold.ttf'),
    bold: await rootBundle.load('$_fontsDirectory/PlusJakartaSans-Bold.ttf'),
    logo: (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
  );
}

CalendarPdfFonts calendarPdfFonts(CalendarPdfAssets assets)
{
  final regular = pw.Font.ttf(assets.regular);
  final bold = pw.Font.ttf(assets.bold);

  return (
    regular: regular,
    semiBold: pw.Font.ttf(assets.semiBold),
    bold: bold,
    logo: pw.MemoryImage(assets.logo),
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
}
