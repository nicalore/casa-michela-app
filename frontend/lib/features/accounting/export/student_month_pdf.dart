import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/export/calendar_pdf_palette.dart';
import '../../people/utils/payments_strings.dart' show kTariffKindLabels, tariffCost;
import '../models/student_month_items.dart';
import '../utils/accounting_strings.dart';
import 'accounting_pdf_look.dart';
import 'teacher_month_pdf.dart' show accountingPendingNote;

// A tariff's line in a split row: every column keeps it, so the lines meet across.
const double _partHeight = 24;

const PdfColor _dueInk = PdfColor.fromInt(0xFF9A6B15);
const PdfColor _renewalInk = PdfColor.fromInt(0xFF1D5592);
const PdfColor _renewalSurface = PdfColor.fromInt(0xFFE2ECF8);
const PdfColor _aheadSurface = PdfColor.fromInt(0xFFE3F4F1);
const PdfColor _partRule = PdfColor.fromInt(0xFFC9D5DA);

// The page's marks, drawn: a filled circle with a tick, an outlined triangle.
const String _okSvg = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#17B3A3"/>'
    '<path d="M7.4 12.4l3.1 3.1 6.1-6.4" fill="none" stroke="#FFFFFF" stroke-width="2.4" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>';
const String _dueSvg = '<svg viewBox="0 0 24 24"><path d="M12 3.6 21.6 20.2H2.4Z" fill="none" stroke="#E3A83C" '
    'stroke-width="2.1" stroke-linejoin="round"/><path d="M12 9.6v4.6" stroke="#E3A83C" stroke-width="2.1" '
    'stroke-linecap="round"/><circle cx="12" cy="17.2" r="1.25" fill="#E3A83C"/></svg>';

const double _nameWidth = 112;
const List<double> _dayWidths = [32, 50, 38];
const List<double> _hourWidths = [48, 52, 44];
const double _tariffWidth = 150;

// With no situation column (a later month has a day confirmed) every column grows by the same share, so the
// table still fills the page instead of leaving the tariff alone in a wide empty one.
List<AccountingGroup> _groups(String? situation, double available)
{
  final double fixed =
      [_nameWidth, ..._dayWidths, ..._hourWidths, _tariffWidth].fold(0.0, (sum, width) => sum + width);
  final double grow = situation == null ? available / fixed : 1;

  AccountingGroup figures(String title, List<double> widths) => AccountingGroup(
        title: title,
        parts: [
          for (final (index, label) in const [kTotalColumn, kPresenceColumn, kOnlineColumn].indexed)
            (label: label, width: widths[index] * grow),
        ],
      );

  return [
    AccountingGroup(parts: [(label: kStudentColumn, width: _nameWidth * grow)], leading: true),
    figures(kDaysGroup, _dayWidths),
    figures(kHoursGroup, _hourWidths),
    AccountingGroup(parts: [(label: kTariffColumn, width: _tariffWidth * grow)], leading: true),
    if (situation != null) AccountingGroup(parts: [(label: situation, width: 0)], flexible: true, leading: true),
  ];
}

// The month as it was read, a row per pupil, split where the tariff changed.
Future<Uint8List> buildStudentMonthPdf(StudentMonth month) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles(compact: true);
  final pw.Document document = accountingPdfDocument(styles, monthlyStudentsPdfTab(month.month));
  final DateTime? on = month.situationOn;
  final List<AccountingGroup> groups = _groups(
    month.situationShown ? (on == null ? kSituationNow : situationAt(on)) : null,
    kAccountingLandscape.availableWidth,
  );

  final pw.Widget state = month.finished
      ? accountingConfirmedPill(styles, kMonthFinished)
      : accountingLivePill(styles, kLiveStatus);

  document.addPage(
    pw.MultiPage(
      pageFormat: kAccountingLandscape,
      maxPages: 20,
      footer: (context) => accountingFooter(context, styles, monthlyStudentsPdfFooter(month.month)),
      build: (context) => [
        accountingPdfHeader(
          styles,
          title: monthlyPdfTitle(month.month),
          pills: [accountingPill(styles, kMonthlySummaryGroup), accountingPill(styles, kStudentsEntry), state],
          meta: [exportedAt(romeNow()), studentsCount(month.rows.length)],
        ),
        pw.SizedBox(height: 6),
        accountingTable(groups, [
          accountingHeadRow(styles, groups),
          for (final row in month.rows) _row(styles, groups, row, month.month),
          _totals(styles, groups, month.rows),
        ], format: kAccountingLandscape),
        if (month.pending.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          accountingPendingNote(styles, month.pending),
        ],
      ],
    ),
  );

  return document.save();
}

String? _count(int value) => value == 0 ? null : '$value';

String? _minutes(int value) => value == 0 ? null : formatMinutes(value);

pw.Widget _small(AccountingPdfStyles styles, String text)
{
  return pw.Text(text, style: styles.cell.copyWith(fontSize: 7.4, color: kPdfMuted));
}

pw.Widget _tariff(AccountingPdfStyles styles, TariffPart part, String? span)
{
  final String? kind = part.tariffKind;
  final int? cents = part.amountCents;

  if (kind == null || cents == null)
  {
    return accountingDash(styles);
  }

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: kTariffKindLabels[kind] ?? '', style: styles.strong),
            if (span != null) pw.TextSpan(text: '  $span', style: styles.cell.copyWith(fontSize: 7.6, color: kPdfMuted)),
          ],
        ),
      ),
      pw.SizedBox(height: 1),
      _small(styles, tariffCost(kind, cents, part.packageHours)),
    ],
  );
}

pw.Widget _badge(AccountingPdfStyles styles, String text, {required bool ahead})
{
  return pw.Container(
    margin: const pw.EdgeInsets.only(left: 3),
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: pw.BoxDecoration(
      color: ahead ? _aheadSurface : _renewalSurface,
      borderRadius: pw.BorderRadius.circular(2),
    ),
    child: pw.Text(text, style: styles.tag.copyWith(color: ahead ? kPdfPresence : _renewalInk)),
  );
}

// As on the page: the mark, the words, and the line under them.
pw.Widget _situation(AccountingPdfStyles styles, StudentStanding situation, DateTime month)
{
  final StandingWords? said = situation.wordsIn(month);

  if (said == null)
  {
    return accountingDash(styles);
  }

  final String? below = said.below;
  final String? badge = said.badge;

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SvgImage(svg: said.due ? _dueSvg : _okSvg, width: 8.4, height: 8.4),
          pw.SizedBox(width: 3),
          pw.Text(said.text, style: styles.strong.copyWith(fontSize: 8.6, color: said.due ? _dueInk : kPdfInk)),
          if (badge != null) _badge(styles, badge, ahead: said.ahead),
        ],
      ),
      if (below != null)
        pw.Padding(padding: const pw.EdgeInsets.only(left: 11.4, top: 1), child: _small(styles, below)),
    ],
  );
}

// A split row stacks its tariffs: each line as tall in every column, a dashed rule between.
pw.Widget _stack(List<pw.Widget> lines, {required bool left})
{
  if (lines.length == 1)
  {
    return lines.single;
  }

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      for (final (index, line) in lines.indexed)
        pw.Container(
          height: _partHeight,
          alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
          decoration: index == 0
              ? null
              : const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: _partRule, width: 0.5, style: pw.BorderStyle.dashed)),
                ),
          child: line,
        ),
    ],
  );
}

pw.TableRow _row(AccountingPdfStyles styles, List<AccountingGroup> groups, StudentMonthRow row, DateTime month)
{
  final List<TariffPart> parts = row.parts;

  List<pw.Widget> each(pw.Widget Function(TariffPart part) cell) => [for (final part in parts) cell(part)];

  pw.Widget column(pw.Widget Function(TariffPart part) cell, {bool left = false}) =>
      _stack(each(cell), left: left);

  // Beside the kind, only where the row splits.
  String? span(TariffPart part)
  {
    final String text = row.split ? tariffSpan(month, part.startsOn, part.endsOn) : '';

    return text.isEmpty ? null : text;
  }

  return accountingRow(groups, [
    [pw.Text(row.fullName, style: styles.name)],
    [
      column((part) => accountingText(styles, _count(part.days), strong: true)),
      column((part) => accountingText(styles, _count(part.presenceDays))),
      column((part) => accountingText(styles, _count(part.onlineDays))),
    ],
    [
      column((part) => accountingText(styles, _minutes(part.minutes), strong: true)),
      column((part) => accountingText(styles, _minutes(part.presenceMinutes))),
      column((part) => accountingText(styles, _minutes(part.onlineMinutes))),
    ],
    [column((part) => _tariff(styles, part, span(part)), left: true)],
    if (row.situation case final StudentStanding standing when groups.length > 4)
      [_situation(styles, standing, month)],
  ]);
}

pw.TableRow _totals(AccountingPdfStyles styles, List<AccountingGroup> groups, List<StudentMonthRow> rows)
{
  var minutes = 0;
  var presence = 0;
  var online = 0;

  for (final row in rows)
  {
    for (final part in row.parts)
    {
      minutes += part.minutes;
      presence += part.presenceMinutes;
      online += part.onlineMinutes;
    }
  }

  return accountingRow(
    groups,
    [
      [accountingTotalLabel(styles)],
      [pw.SizedBox(), pw.SizedBox(), pw.SizedBox()],
      [
        accountingText(styles, _minutes(minutes), strong: true),
        accountingText(styles, _minutes(presence), strong: true),
        accountingText(styles, _minutes(online), strong: true),
      ],
      [pw.SizedBox()],
      if (groups.length > 4) [pw.SizedBox()],
    ],
    rule: AccountingRule.total,
  );
}
