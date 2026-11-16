import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../lessons/export/calendar_pdf_fonts.dart';
import '../../lessons/export/calendar_pdf_palette.dart';
import '../../lessons/export/pdf_parts.dart';
import '../../lessons/utils/opening_window.dart';
import '../utils/accounting_strings.dart';

// The calendar list's margins.
final PdfPageFormat kAccountingPortrait = PdfPageFormat.a4.copyWith(
  marginLeft: 28,
  marginRight: 28,
  marginTop: 22,
  marginBottom: 22,
);

final PdfPageFormat kAccountingLandscape = PdfPageFormat.a4.landscape.copyWith(
  marginLeft: 28,
  marginRight: 28,
  marginTop: 22,
  marginBottom: 22,
);

const PdfColor _dashInk = PdfColor.fromInt(0xFFA9B6BF);
const PdfColor _groupRule = PdfColor.fromInt(0xFFC9D5DA);
const PdfColor _weekRule = PdfColor.fromInt(0xFFB9C6CD);
const PdfColor _signLine = PdfColor.fromInt(0xFF9FB0BB);

const double _tableRule = 1.1;
const double _rowRule = 0.6;

// Plus Jakarta Sans: a line runs from 1.038 em above the baseline to 0.222 below, capitals stand
// 0.745 high, so their middle sits 0.0355 em under the line's.
const double _capitalsDrop = 0.0355;

// The app's own glyph, Icons.check_rounded, cut to its ink.
const String _checkPath = 'M9 16.17 5.53 12.7C5.16 12.33 4.5 12.33 4.12 12.7C3.75 13.08 3.75 13.73 4.12 14.11'
    'L8.3 18.28C8.67 18.7 9.33 18.7 9.7 18.28L20.3 7.69C20.67 7.31 20.67 6.7 20.3 6.28C19.92 5.91 19.27 5.91 '
    '18.89 6.28L9 16.17Z';
const String _checkBox = '3.84 6 16.74 12.6';
const double _checkAspect = 16.74 / 12.6;


String _svg(String path, String box, PdfColor colour)
{
  return '<svg viewBox="$box"><path d="$path" fill="${colour.toHex().substring(0, 7)}"/></svg>';
}

PdfColor _mix(PdfColor from, PdfColor to, double share)
{
  return PdfColor(
    from.red + (to.red - from.red) * share,
    from.green + (to.green - from.green) * share,
    from.blue + (to.blue - from.blue) * share,
  );
}

class AccountingPdfStyles
{
  AccountingPdfStyles(this.fonts, {this.compact = false});

  final CalendarPdfFonts fonts;

  // The month's wide table sets its cells a step smaller.
  final bool compact;

  pw.TextStyle _style(double size, pw.Font font, PdfColor colour, {double? spacing}) => pw.TextStyle(
        font: font,
        fontSize: size,
        color: colour,
        letterSpacing: spacing,
      );

  double get cellSize => compact ? 8.8 : 9.4;

  late final pw.TextStyle eyebrow = _style(9.4, fonts.semiBold, kPdfMuted, spacing: 1.4);
  late final pw.TextStyle title = _style(18.75, fonts.bold, kPdfInk);
  late final pw.TextStyle meta = _style(10, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle pill = _style(10, fonts.bold, kPdfInk);
  late final pw.TextStyle caption = _style(8.75, fonts.semiBold, kPdfMuted);

  late final pw.TextStyle bandName = _style(11.5, fonts.bold, kPdfInk);
  late final pw.TextStyle bandCount = _style(9.4, fonts.semiBold, kPdfMuted);

  late final pw.TextStyle groupHead = _style(compact ? 7 : 7.2, fonts.bold, kPdfMuted, spacing: 1.1);
  late final pw.TextStyle columnHead = _style(compact ? 8 : 8.6, fonts.bold, kPdfInk);

  late final pw.TextStyle cell = _style(cellSize, fonts.semiBold, kPdfBody);
  late final pw.TextStyle strong = _style(cellSize, fonts.bold, kPdfInk);
  late final pw.TextStyle dash = _style(cellSize, fonts.regular, _dashInk);
  late final pw.TextStyle name = _style(compact ? 9.8 : 10.2, fonts.bold, kPdfInk);
  late final pw.TextStyle total = _style(7.4, fonts.bold, kPdfMuted, spacing: 1.1);
  late final pw.TextStyle tag = _style(7, fonts.bold, kPdfMuted, spacing: 0.3);

  late final pw.TextStyle figureLabel = _style(6.9, fonts.semiBold, kPdfMuted, spacing: 0.9);
  late final pw.TextStyle figure = _style(15, fonts.bold, kPdfInk);
  late final pw.TextStyle figureNet = _style(15, fonts.bold, kPdfPresence);
  late final pw.TextStyle figureLine = _style(10.5, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle figureLineStrong = _style(10.5, fonts.bold, kPdfInk);

  late final pw.TextStyle note = _style(9.4, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle noteStrong = _style(9.4, fonts.bold, kPdfPresence);

  pw.TextStyle state(PdfColor accent) => _style(7.6, fonts.bold, accent, spacing: 1);

  // Hours in their mode's colour, as on the calendar's PDF.
  pw.TextStyle hours({required bool online}) => _style(cellSize, fonts.bold, online ? kPdfOnline : kPdfPresence);
}

Future<AccountingPdfStyles> accountingPdfStyles({bool compact = false}) async
{
  return AccountingPdfStyles(calendarPdfFonts(await calendarPdfAssets()), compact: compact);
}

pw.Document accountingPdfDocument(AccountingPdfStyles styles, String title)
{
  return pw.Document(theme: styles.fonts.theme, title: title, author: kPdfAuthor, creator: kPdfAuthor);
}

pw.Widget accountingPill(AccountingPdfStyles styles, String label) => pdfPill(label, styles.pill);

pw.Widget accountingPdfHeader(
  AccountingPdfStyles styles, {
  required String title,
  required List<pw.Widget> pills,
  required List<String> meta,
})
{
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(kPdfAssociation, style: styles.eyebrow),
            pw.SizedBox(height: 3),
            pdfGradientTitle(title, styles.title),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                for (final (index, pill) in pills.indexed) ...[
                  if (index > 0) pw.SizedBox(width: 6),
                  pill,
                ],
              ],
            ),
            pw.SizedBox(height: 5),
            for (final line in meta) pw.Text(line, style: styles.meta),
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      pdfLogo(styles.fonts.logo),
    ],
  );
}

pw.Widget accountingFooter(pw.Context context, AccountingPdfStyles styles, String said)
{
  return pdfFooter(context, said, styles.caption);
}

pw.Widget accountingModeLegend(AccountingPdfStyles styles)
{
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pdfSwatch(modeLabel(kPresenceMode), kPdfPresence, kPdfPresenceSurface, styles.caption),
      pw.SizedBox(width: 12),
      pdfSwatch(modeLabel(kOnlineMode), kPdfOnline, kPdfOnlineSurface, styles.caption),
    ],
  );
}

// A glyph centred on the capitals of text set at `textSize` in the same row, not on its line.
pw.Widget _onCapitals(pw.Widget glyph, double textSize)
{
  return pw.Padding(padding: pw.EdgeInsets.only(top: 2 * _capitalsDrop * textSize), child: glyph);
}

pw.Widget accountingCheck({required double height, PdfColor? colour})
{
  return pw.SvgImage(
    svg: _svg(_checkPath, _checkBox, colour ?? kPdfPresence),
    width: height * _checkAspect,
    height: height,
  );
}

pw.Widget accountingStatePill(
  AccountingPdfStyles styles,
  String label, {
  required PdfColor accent,
  required PdfColor surface,
  bool tick = false,
})
{
  const double textSize = 7.6;

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: pw.BoxDecoration(
      color: surface,
      border: pw.Border.all(color: _mix(accent, surface, 0.7), width: 0.6),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (tick) _onCapitals(accountingCheck(height: 0.6 * textSize, colour: accent), textSize),
        pw.Padding(
          padding: pw.EdgeInsets.only(left: tick ? 2.5 : 0),
          child: pw.Text(label, style: styles.state(accent)),
        ),
      ],
    ),
  );
}

pw.Widget accountingConfirmedPill(AccountingPdfStyles styles, String label)
{
  return accountingStatePill(styles, label, accent: kPdfPresence, surface: kPdfPresenceSurface, tick: true);
}

pw.Widget accountingLivePill(AccountingPdfStyles styles, String label)
{
  return accountingStatePill(styles, label, accent: kPdfPresence, surface: kPdfWhite);
}

pw.Widget accountingDash(AccountingPdfStyles styles) => pw.Text('—', style: styles.dash);

pw.Widget accountingText(AccountingPdfStyles styles, String? text, {bool strong = false})
{
  return text == null ? accountingDash(styles) : pw.Text(text, style: strong ? styles.strong : styles.cell);
}

// Several stretches of a day stand one under the other.
pw.Widget accountingTimes(AccountingPdfStyles styles, List<({String text, bool online})> times)
{
  if (times.isEmpty)
  {
    return accountingDash(styles);
  }

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      for (final (index, time) in times.indexed) ...[
        if (index > 0) pw.SizedBox(height: 1.5),
        pw.Text(time.text, style: styles.hours(online: time.online)),
      ],
    ],
  );
}

pw.Widget accountingTag(AccountingPdfStyles styles, String label)
{
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: pw.BoxDecoration(color: kPdfHeaderGround, borderRadius: pw.BorderRadius.circular(2)),
    child: pw.Text(label, style: styles.tag),
  );
}

// An empty cell as tall as a row of `height`, with the line to sign on at its foot.
pw.Widget accountingSignature({required double height})
{
  return pw.Container(
    height: height - 10,
    alignment: pw.Alignment.bottomCenter,
    padding: const pw.EdgeInsets.fromLTRB(6, 0, 6, 1),
    child: pw.Container(height: 0.7, color: _signLine),
  );
}

// One column of a group; a group without a title is a single column with its label at the bottom.
typedef AccountingPart = ({String label, double width});

class AccountingGroup
{
  final String? title;
  final List<AccountingPart> parts;

  // Takes the width the others leave.
  final bool flexible;

  // A name reads from the left, figures from the middle.
  final bool leading;

  // Parts of a group of figures that read from the left all the same, by index.
  final Set<int> leadingParts;

  const AccountingGroup({
    this.title,
    required this.parts,
    this.flexible = false,
    this.leading = false,
    this.leadingParts = const {},
  });

  double get width => parts.fold(0, (sum, part) => sum + part.width);
}

const double _cellSide = 2;
const double _leadingInset = 6;

pw.Widget _part(AccountingGroup group, double? width, pw.Widget child, {required bool head, bool? leading})
{
  final bool left = leading ?? group.leading;

  final pw.Widget placed = pw.Padding(
    padding: left
        ? pw.EdgeInsets.fromLTRB(_leadingInset, head ? 0 : 5, 4, head ? 0 : 5)
        : pw.EdgeInsets.symmetric(horizontal: _cellSide, vertical: head ? 0 : 5),
    child: child,
  );

  final pw.Widget aligned = pw.Align(
    alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
    child: placed,
  );

  return width == null ? aligned : pw.SizedBox(width: width, child: aligned);
}

pw.Widget _groupCell(AccountingGroup group, List<pw.Widget> children, {required bool head})
{
  if (group.flexible)
  {
    return _part(group, null, children.single, head: head);
  }

  return pw.Row(
    crossAxisAlignment: head ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.center,
    children: [
      for (final (index, part) in group.parts.indexed)
        _part(
          group,
          part.width,
          children[index],
          head: head,
          leading: group.leading || group.leadingParts.contains(index),
        ),
    ],
  );
}

pw.TableRow accountingHeadRow(AccountingPdfStyles styles, List<AccountingGroup> groups)
{
  pw.Widget label(String text) => pw.Text(text, style: styles.columnHead, textAlign: pw.TextAlign.center);

  // Cells keep their own height, never stretched to the row's: stretched, a column that fills its
  // cell exactly loses its last line to rounding, as the pdf package cuts what overflows.
  return pw.TableRow(
    repeat: true,
    verticalAlignment: pw.TableCellVerticalAlignment.bottom,
    decoration: pw.BoxDecoration(color: kPdfHeaderGround),
    children: [
      for (final group in groups)
        if (group.title case final String title)
          pw.Column(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4.5, bottom: 1.5),
                child: pw.Text(title.toUpperCase(), style: styles.groupHead),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: _groupCell(group, [for (final part in group.parts) label(part.label)], head: true),
              ),
            ],
          )
        else
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4.5, bottom: 4),
            child: _groupCell(group, [for (final part in group.parts) label(part.label)], head: true),
          ),
    ],
  );
}

enum AccountingRule { row, week, total }

// A body row: one list of cells per group, the rule above it marking where it stands.
pw.TableRow accountingRow(
  List<AccountingGroup> groups,
  List<List<pw.Widget>> cells, {
  AccountingRule rule = AccountingRule.row,
  double minHeight = 0,
})
{
  final pw.BorderSide above = switch (rule)
  {
    AccountingRule.row => pw.BorderSide(color: kPdfLine, width: _rowRule),
    AccountingRule.week => const pw.BorderSide(color: _weekRule, width: _tableRule),
    AccountingRule.total => pw.BorderSide(color: kPdfMuted, width: _tableRule),
  };

  return pw.TableRow(
    verticalAlignment: pw.TableCellVerticalAlignment.middle,
    decoration: pw.BoxDecoration(
      color: rule == AccountingRule.total ? kPdfHeaderGround : null,
      border: pw.Border(top: above),
    ),
    children: [
      for (final (index, group) in groups.indexed)
        index == 0 && minHeight > 0
            ? pw.ConstrainedBox(
                constraints: pw.BoxConstraints(minHeight: minHeight),
                child: _groupCell(group, cells[index], head: false),
              )
            : _groupCell(group, cells[index], head: false),
    ],
  );
}

// Every column gets a fixed width, the flexible one what the page leaves.
pw.Widget accountingTable(List<AccountingGroup> groups, List<pw.TableRow> rows, {required PdfPageFormat format})
{
  final double fixed = groups.fold(0, (sum, group) => group.flexible ? sum : sum + group.width);
  final double rest = format.availableWidth - fixed;

  return pw.Table(
    columnWidths: {
      for (final (index, group) in groups.indexed) index: pw.FixedColumnWidth(group.flexible ? rest : group.width),
    },
    border: pw.TableBorder(
      top: pw.BorderSide(color: kPdfMuted, width: _tableRule),
      bottom: pw.BorderSide(color: kPdfMuted, width: _tableRule),
      verticalInside: const pw.BorderSide(color: _groupRule, width: 0.8),
    ),
    children: rows,
  );
}

pw.Widget accountingTotalLabel(AccountingPdfStyles styles) => pw.Text(kTotalRow.toUpperCase(), style: styles.total);
