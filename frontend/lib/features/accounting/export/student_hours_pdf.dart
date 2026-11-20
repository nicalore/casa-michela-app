import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/export/calendar_pdf_palette.dart';
import '../../people/utils/payments_strings.dart'
    show hoursLineUnit, hoursText, kAheadExhaustedBadge, kCostColumn, kExhaustedBadge, kTariffKindLabels, leftLabel, tariffCost;
import '../models/student_hours_items.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_strings.dart';
import 'accounting_pdf_look.dart';
import '../utils/opening_strings.dart' show kOpeningPending;

typedef StudentHoursPdfBand = ({TimeBucket band, StudentHoursBand data});

List<AccountingGroup> get _groups => [
  AccountingGroup(parts: [(label: kStudentColumn, width: 0)], flexible: true, leading: true),
  AccountingGroup(
    title: kLessonsGroup,
    parts: [(label: kStartColumn, width: 46), (label: kEndColumn, width: 46), (label: kHoursColumn, width: 44)],
  ),
  AccountingGroup(
    title: kPaymentGroup,
    parts: [(label: kTariffColumn, width: 86), (label: kSituationColumn, width: 150), (label: kCostColumn, width: 50)],
    leadingParts: {0, 1},
  ),
];

const PdfColor _dueInk = PdfColor.fromInt(0xFF9A6B15);
const PdfColor _renewalInk = PdfColor.fromInt(0xFF1D5592);
const PdfColor _renewalSurface = PdfColor.fromInt(0xFFE2ECF8);
const PdfColor _aheadSurface = PdfColor.fromInt(0xFFE3F4F1);

// The marks of the page's situations, drawn: a filled circle with a tick, an outlined triangle.
const String _okSvg = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#17B3A3"/>'
    '<path d="M7.4 12.4l3.1 3.1 6.1-6.4" fill="none" stroke="#FFFFFF" stroke-width="2.4" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>';
const String _dueSvg = '<svg viewBox="0 0 24 24"><path d="M12 3.6 21.6 20.2H2.4Z" fill="none" stroke="#E3A83C" '
    'stroke-width="2.1" stroke-linejoin="round"/><path d="M12 9.6v4.6" stroke="#E3A83C" stroke-width="2.1" '
    'stroke-linecap="round"/><circle cx="12" cy="17.2" r="1.25" fill="#E3A83C"/></svg>';

// The whole day, each band with somebody in it on a page of its own.
Future<Uint8List> buildStudentHoursPdf(DateTime day, List<StudentHoursPdfBand> bands) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles();
  final pw.Document document = accountingPdfDocument(styles, dailyStudentsPdfTab(day));
  final String exported = exportedAt(romeNow());

  for (final band in bands)
  {
    if (band.data.rows.isEmpty)
    {
      continue;
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: kAccountingPortrait,
        maxPages: 20,
        footer: (context) => accountingFooter(context, styles, dailyStudentsPdfFooter(day)),
        build: (context) => [
          accountingPdfHeader(
            styles,
            title: dailyPdfTitle(day),
            pills: [accountingPill(styles, kDailySummaryGroup), accountingPill(styles, kStudentsEntry)],
            meta: [exported],
          ),
          pw.SizedBox(height: 14),
          _bandBar(styles, band),
          pw.SizedBox(height: 6),
          accountingTable(_groups, [
            accountingHeadRow(styles, _groups),
            for (final row in band.data.rows) _row(styles, row, band.data.date),
            _totals(styles, band.data.rows),
          ], format: kAccountingPortrait),
        ],
      ),
    );
  }

  return document.save();
}

// No state: a band's page says only its name and how many pupils it holds.
pw.Widget _bandBar(AccountingPdfStyles styles, StudentHoursPdfBand band)
{
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      // One line of text: name and count sit on the same baseline.
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '${bandLabel(band.band)}  ', style: styles.bandName),
            pw.TextSpan(text: studentsCount(band.data.rows.length), style: styles.bandCount),
          ],
        ),
      ),
      accountingModeLegend(styles),
    ],
  );
}

List<({String text, bool online})> _ends(List<HoursSpan> spans, {required bool online, required bool end})
{
  return [for (final span in spans) (text: clockOf(end ? span.end : span.start), online: online)];
}

pw.Widget _small(AccountingPdfStyles styles, String text)
{
  return pw.Text(text, style: styles.cell.copyWith(fontSize: 7.6, color: kPdfMuted));
}

pw.Widget _tariff(AccountingPdfStyles styles, StudentSituation situation)
{
  final String? kind = situation.tariffKind;
  final int? cents = situation.tariffCents;

  if (kind == null || cents == null)
  {
    return accountingDash(styles);
  }

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(kTariffKindLabels[kind] ?? '', style: styles.strong),
      pw.SizedBox(height: 1),
      _small(styles, tariffCost(kind, cents, situation.packageHours)),
    ],
  );
}

pw.Widget _chip(AccountingPdfStyles styles, String text, {required bool ahead})
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

// As on the page: the mark, the text, and the hours not covered under it.
pw.Widget _situation(AccountingPdfStyles styles, StudentSituation situation, DateTime day)
{
  final int minutes = situation.minutes;

  final ({String text, String? below, String? badge, bool ahead})? said = switch (situation.kind)
  {
    StudentSituationKind.packageLeft => (
        text: leftLabel(minutes),
        below: null,
        badge: situation.renewed ? kRenewalBadge : null,
        ahead: false,
      ),
    StudentSituationKind.packageEnded => (
        text: kExhaustedBadge,
        below: minutes == 0 ? null : '${hoursText(minutes)} ${hoursLineUnit('OVER_PACKAGE', minutes)}',
        badge: null,
        ahead: false,
      ),
    StudentSituationKind.monthPaid => (text: monthPaidSituation(day), below: null, badge: null, ahead: false),
    StudentSituationKind.monthUnpaid => (text: monthUnpaidSituation(day), below: null, badge: null, ahead: false),
    StudentSituationKind.settle => (text: kToSettleSituation, below: null, badge: null, ahead: false),
    StudentSituationKind.aheadLeft => (text: leftLabel(minutes), below: null, badge: kAheadBadge, ahead: true),
    StudentSituationKind.aheadEnded => (
        text: kAheadExhaustedBadge,
        below: minutes == 0 ? null : '${hoursText(minutes)} ${kToSettleSituation.toLowerCase()}',
        badge: null,
        ahead: false,
      ),
    StudentSituationKind.pending => (text: kOpeningPending, below: null, badge: null, ahead: false),
    StudentSituationKind.none => null,
  };

  if (said == null)
  {
    return accountingDash(styles);
  }

  final bool due = situation.isDue;
  final String? below = said.below;
  final String? badge = said.badge;

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SvgImage(svg: due ? _dueSvg : _okSvg, width: 8.4, height: 8.4),
          pw.SizedBox(width: 3),
          pw.Text(said.text, style: styles.strong.copyWith(fontSize: 8.6, color: due ? _dueInk : kPdfInk)),
          if (badge != null) _chip(styles, badge, ahead: said.ahead),
        ],
      ),
      if (below != null)
        pw.Padding(padding: const pw.EdgeInsets.only(left: 11.4, top: 1), child: _small(styles, below)),
    ],
  );
}

pw.TableRow _row(AccountingPdfStyles styles, StudentHoursRow row, DateTime day)
{
  final List<HoursSpan> work = row.absent ? const [] : row.work;
  final String? hours = row.absent || work.isEmpty ? null : formatMinutes(row.minutes);
  final int cost = row.situation.costCents;

  return accountingRow(_groups, [
    [
      pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(row.fullName, style: styles.name),
          if (row.absent) ...[pw.SizedBox(height: 1.5), accountingTag(styles, kAbsentBadge)],
        ],
      ),
    ],
    [
      accountingTimes(styles, _ends(work, online: row.isOnline, end: false)),
      accountingTimes(styles, _ends(work, online: row.isOnline, end: true)),
      accountingText(styles, hours, strong: true),
    ],
    [
      _tariff(styles, row.situation),
      row.absent ? accountingDash(styles) : _situation(styles, row.situation, day),
      accountingText(styles, cost == 0 ? null : formatAmount(cost)),
    ],
  ]);
}

pw.TableRow _totals(AccountingPdfStyles styles, List<StudentHoursRow> rows)
{
  final int minutes = rows.fold(0, (sum, row) => sum + (row.absent ? 0 : row.minutes));
  final int cost = rows.fold(0, (sum, row) => sum + row.situation.costCents);

  return accountingRow(
    _groups,
    [
      [accountingTotalLabel(styles)],
      [pw.SizedBox(), pw.SizedBox(), accountingText(styles, minutes == 0 ? null : formatMinutes(minutes), strong: true)],
      [pw.SizedBox(), pw.SizedBox(), accountingText(styles, formatAmount(cost), strong: true)],
    ],
    rule: AccountingRule.total,
  );
}
