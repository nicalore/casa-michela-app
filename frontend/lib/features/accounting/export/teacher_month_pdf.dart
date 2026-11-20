import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/language/app_language.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../models/teacher_month_items.dart';
import '../utils/accounting_strings.dart';
import '../widgets/teacher_month_table.dart';
import 'accounting_pdf_look.dart';

// Tall enough to sign on.
const double _rowHeight = 31;

List<AccountingGroup> get _groups => [
  AccountingGroup(parts: [(label: kTeacherColumn, width: 124)], leading: true),
  AccountingGroup(
    title: kDaysGroup,
    parts: [(label: kTotalColumn, width: 32), (label: kPresenceColumn, width: 50), (label: kOnlineColumn, width: 38)],
  ),
  AccountingGroup(
    title: kHoursGroup,
    parts: [(label: kTotalColumn, width: 50), (label: kVolunteerColumn, width: 62), (label: kPaidColumn, width: 50)],
  ),
  AccountingGroup(
    title: kPayGroup,
    parts: [(label: kGrossColumn, width: 58), (label: kWithholdingColumn, width: 58), (label: kNetColumn, width: 58)],
  ),
  AccountingGroup(parts: [(label: kRuleColumn, width: 70)]),
  AccountingGroup(parts: [(label: kSignatureColumn, width: 0)], flexible: true),
];

// The month as it was confirmed, each teacher with room to sign.
Future<Uint8List> buildTeacherMonthPdf(TeacherMonth month) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles(compact: true);
  final pw.Document document = accountingPdfDocument(styles, monthlyPdfTab(month.month));

  final pw.Widget state = month.finished
      ? accountingConfirmedPill(styles, kMonthFinished)
      : accountingLivePill(styles, kLiveStatus);

  document.addPage(
    pw.MultiPage(
      pageFormat: kAccountingLandscape,
      maxPages: 20,
      footer: (context) => accountingFooter(context, styles, monthlyPdfFooter(month.month)),
      build: (context) => [
        accountingPdfHeader(
          styles,
          title: monthlyPdfTitle(month.month),
          pills: [accountingPill(styles, kMonthlySummaryGroup), accountingPill(styles, kTeachersEntry), state],
          meta: [exportedAt(romeNow()), teachersCount(month.rows.length)],
        ),
        pw.SizedBox(height: 6),
        accountingTable(_groups, [
          accountingHeadRow(styles, _groups),
          for (final row in month.rows) _row(styles, row),
          _totals(styles, month.rows),
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

String? _minutes(int? value) => value == null || value == 0 ? null : formatMinutes(value);

String? _amount(int? cents) => cents == null ? null : formatAmount(cents);

pw.TableRow _row(AccountingPdfStyles styles, TeacherMonthRow row)
{
  final String? rule = row.isPaid ? kMonthRuleNames[row.volunteering] : null;

  return accountingRow(
    _groups,
    [
      [pw.Text(row.fullName, style: styles.name)],
      [
        accountingText(styles, _count(row.days), strong: true),
        accountingText(styles, _count(row.presenceDays)),
        accountingText(styles, _count(row.onlineDays)),
      ],
      [
        accountingText(styles, _minutes(row.workedMinutes), strong: true),
        accountingText(styles, _minutes(row.volunteerMinutes), strong: true),
        accountingText(styles, _minutes(row.paidMinutes), strong: true),
      ],
      [
        accountingText(styles, _amount(row.gross)),
        accountingText(styles, _amount(withholdingOf(row.gross, row.net))),
        accountingText(styles, _amount(row.net)),
      ],
      [accountingText(styles, rule)],
      [accountingSignature(height: _rowHeight)],
    ],
    minHeight: _rowHeight,
  );
}

pw.TableRow _totals(AccountingPdfStyles styles, List<TeacherMonthRow> rows)
{
  var worked = 0;
  var given = 0;
  var paid = 0;
  var gross = 0;
  var net = 0;

  for (final row in rows)
  {
    worked += row.workedMinutes;
    given += row.volunteerMinutes;
    paid += row.paidMinutes ?? 0;
    gross += row.gross ?? 0;
    net += row.net ?? 0;
  }

  return accountingRow(
    _groups,
    [
      [accountingTotalLabel(styles)],
      [pw.SizedBox(), pw.SizedBox(), pw.SizedBox()],
      [
        accountingText(styles, _minutes(worked), strong: true),
        accountingText(styles, _minutes(given), strong: true),
        accountingText(styles, _minutes(paid), strong: true),
      ],
      [
        accountingText(styles, formatAmount(gross), strong: true),
        accountingText(styles, formatAmount(gross - net), strong: true),
        accountingText(styles, formatAmount(net), strong: true),
      ],
      [pw.SizedBox()],
      [pw.SizedBox()],
    ],
    rule: AccountingRule.total,
  );
}

// As under the page's table: the first bands named, the rest counted.
pw.Widget accountingPendingNote(AccountingPdfStyles styles, List<PendingBand> pending)
{
  final List<PendingBand> named = pending.length <= kNamedPendingBands + 1
      ? pending
      : pending.sublist(0, kNamedPendingBands);
  final int others = pending.length - named.length;

  return pw.RichText(
    text: pw.TextSpan(
      style: styles.note,
      children: [
        pw.TextSpan(text: kStillToConfirm),
        for (final (index, band) in named.indexed) ...[
          if (index > 0) pw.TextSpan(text: index == named.length - 1 && others == 0 ? tr(' e ', ' and ') : ', '),
          pw.TextSpan(text: pendingBandLabel(band), style: styles.noteStrong),
        ],
        if (others > 0) pw.TextSpan(text: ' ${andOthers(others)}'),
        const pw.TextSpan(text: '.'),
      ],
    ),
  );
}
