import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';

import '../../../core/theme/app_theme.dart';
import '../utils/opening_window.dart';

PdfColor _pdf(Color colour)
{
  return PdfColor(
    (colour.r * 255).round() / 255,
    (colour.g * 255).round() / 255,
    (colour.b * 255).round() / 255,
  );
}

final PdfColor kPdfInk = _pdf(AppTheme.trialOcean);

final PdfColor kPdfViolet = _pdf(AppTheme.trialViolet);

final PdfColor kPdfBody = _pdf(AppTheme.trialInk);

final PdfColor kPdfMuted = _pdf(AppTheme.trialMutedText);

final PdfColor kPdfPresence = _pdf(AppTheme.trialTealDeep);
final PdfColor kPdfPresenceSurface = _pdf(AppTheme.todaySurface);

final PdfColor kPdfOnline = _pdf(AppTheme.modifiedAccent);
final PdfColor kPdfOnlineSurface = _pdf(AppTheme.modifiedAccentSurface);

final PdfColor kPdfLine = _pdf(AppTheme.trialLine);
final PdfColor kPdfRule = _pdf(AppTheme.closedLine);

final PdfColor kPdfBand = _pdf(AppTheme.pageBackground);
final PdfColor kPdfHeaderGround = _pdf(AppTheme.trialPaper);

const PdfColor kPdfWhite = PdfColors.white;

PdfColor pdfLessonAccent(String mode) => mode == kOnlineMode ? kPdfOnline : kPdfPresence;

PdfColor pdfLessonSurface(String mode) => mode == kOnlineMode ? kPdfOnlineSurface : kPdfPresenceSurface;
