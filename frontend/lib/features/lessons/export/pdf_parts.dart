import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/language/app_language.dart';
import 'calendar_pdf_palette.dart';

const String kPdfAssociation = 'ASSOCIAZIONE CASA MICHELA';
const String kPdfAuthor = 'Associazione Casa Michela';

const double kPdfTypeScale = 1.25;

const double kPdfLogoSize = 66 * kPdfTypeScale;

// The association's documents share one look: this title shading into violet, grey pills, the logo.
pw.Widget pdfGradientTitle(String text, pw.TextStyle style)
{
  final letters = text.split('');

  return pw.RichText(
    text: pw.TextSpan(
      children: [
        for (var i = 0; i < letters.length; i++)
          pw.TextSpan(
            text: letters[i],
            style: style.copyWith(color: _rampAt(letters.length == 1 ? 1 : i / (letters.length - 1))),
          ),
      ],
    ),
  );
}

PdfColor _rampAt(double t)
{
  const begin = 0.15;
  const end = 0.95;

  if (t <= begin)
  {
    return kPdfInk;
  }

  if (t >= end)
  {
    return kPdfViolet;
  }

  final travelled = (t - begin) / (end - begin);

  return PdfColor(
    kPdfInk.red + (kPdfViolet.red - kPdfInk.red) * travelled,
    kPdfInk.green + (kPdfViolet.green - kPdfInk.green) * travelled,
    kPdfInk.blue + (kPdfViolet.blue - kPdfInk.blue) * travelled,
  );
}

pw.Widget pdfPill(String label, pw.TextStyle style)
{
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(
      color: kPdfHeaderGround,
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Text(label, style: style),
  );
}

pw.Widget pdfLogo(pw.ImageProvider logo)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2),
    child: pw.Image(logo, width: kPdfLogoSize, height: kPdfLogoSize),
  );
}

pw.Widget pdfLegendEntry(pw.Widget mark, String label, pw.TextStyle style)
{
  return pw.Row(
    children: [
      mark,
      pw.SizedBox(width: 3),
      pw.Text(label, style: style),
    ],
  );
}

pw.Widget pdfSwatch(String label, PdfColor accent, PdfColor surface, pw.TextStyle style)
{
  return pdfLegendEntry(
    pw.Container(
      width: 7,
      height: 7,
      decoration: pw.BoxDecoration(
        color: surface,
        border: pw.Border.all(color: accent, width: 0.6),
        borderRadius: pw.BorderRadius.circular(1.5),
      ),
    ),
    label,
    style,
  );
}

pw.Widget pdfFooter(pw.Context context, String said, pw.TextStyle style)
{
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: kPdfLine, width: 0.4)),
    ),
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(said, style: style),
        pw.Text(tr('Pagina ${context.pageNumber} di ${context.pagesCount}', 'Page ${context.pageNumber} of ${context.pagesCount}'), style: style),
      ],
    ),
  );
}
