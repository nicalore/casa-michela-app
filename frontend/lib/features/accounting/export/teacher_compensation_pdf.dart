import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/export/calendar_pdf_palette.dart';
import '../../people/models/compensation_items.dart';
import '../../people/utils/compensation_strings.dart' as compensation;
import '../utils/accounting_strings.dart';
import 'accounting_pdf_look.dart';

const AccountingGroup _day = AccountingGroup(
  parts: [(label: compensation.kDayColumn, width: 0)],
  flexible: true,
  leading: true,
);

const List<AccountingGroup> _paidGroups = [
  _day,
  AccountingGroup(
    title: compensation.kWorkGroup,
    parts: [
      (label: compensation.kStartColumn, width: 46),
      (label: compensation.kEndColumn, width: 46),
      (label: compensation.kHoursColumn, width: 48),
    ],
  ),
  AccountingGroup(
    title: compensation.kVolunteerGroup,
    parts: [
      (label: compensation.kStartColumn, width: 42),
      (label: compensation.kEndColumn, width: 42),
      (label: compensation.kHoursColumn, width: 38),
    ],
  ),
  AccountingGroup(
    title: compensation.kPayGroup,
    parts: [
      (label: compensation.kGrossColumn, width: 58),
      (label: compensation.kWithholdingColumn, width: 58),
      (label: compensation.kNetColumn, width: 58),
    ],
  ),
];

// Those not paid have days and hours only, as on the tab.
const List<AccountingGroup> _plainGroups = [
  _day,
  AccountingGroup(
    parts: [
      (label: compensation.kStartColumn, width: 80),
      (label: compensation.kEndColumn, width: 80),
      (label: compensation.kHoursColumn, width: 80),
    ],
  ),
];

// One teacher's month as the Compensi tab shows it.
Future<Uint8List> buildTeacherCompensationPdf({
  required String name,
  required DateTime month,
  required CompensationMonth shown,
}) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles();
  final pw.Document document = accountingPdfDocument(styles, compensationPdfFooter(name, month));
  final List<AccountingGroup> groups = shown.isPaid ? _paidGroups : _plainGroups;

  document.addPage(
    pw.MultiPage(
      pageFormat: kAccountingPortrait,
      maxPages: 20,
      footer: (context) => accountingFooter(context, styles, compensationPdfFooter(name, month)),
      build: (context) => [
        accountingPdfHeader(
          styles,
          title: compensationPdfTitle(name),
          pills: [accountingPill(styles, formatMonthYear(month))],
          meta: [exportedAt(romeNow())],
        ),
        pw.SizedBox(height: 10),
        _figures(styles, shown),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [accountingModeLegend(styles)]),
        pw.SizedBox(height: 6),
        accountingTable(groups, [
          accountingHeadRow(styles, groups),
          for (final (index, day) in shown.days.indexed)
            _row(styles, shown, day, before: index == 0 ? null : shown.days[index - 1]),
          _totals(styles, shown),
        ], format: kAccountingPortrait),
      ],
    ),
  );

  return document.save();
}

String _money(int? cents) => cents == null ? '—' : formatAmount(cents);

String? _amount(int? cents) => cents == null ? null : formatAmount(cents);

pw.Widget _figure(AccountingPdfStyles styles, String label, String value, {bool net = false})
{
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label.toUpperCase(), style: styles.figureLabel),
      pw.SizedBox(height: 2),
      pw.Text(value, style: net ? styles.figureNet : styles.figure),
    ],
  );
}

pw.Widget _total(AccountingPdfStyles styles, String value, String text)
{
  return pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(text: value, style: styles.figureLineStrong),
        pw.TextSpan(text: ' $text', style: styles.figureLine),
      ],
    ),
  );
}

// Columns by shares, those from `split` on set apart by a rule; figures level at the foot,
// whatever lines their labels take.
pw.Widget _columns(List<pw.Widget> cells, {required List<int> shares, int? split})
{
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      for (final (index, cell) in cells.indexed)
        pw.Expanded(
          flex: shares[index],
          child: index == split
              ? pw.Container(
                  padding: const pw.EdgeInsets.only(left: 12),
                  decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: kPdfLine, width: 0.8))),
                  child: cell,
                )
              : cell,
        ),
    ],
  );
}

pw.Widget _figures(AccountingPdfStyles styles, CompensationMonth shown)
{
  final int days = shown.days.length;

  final List<pw.Widget> totals = [
    _total(styles, '$days', compensation.workedDaysText(days)),
    _total(styles, formatMinutes(shown.workedMinutes), compensation.workedHoursText(shown.workedMinutes)),
    if (shown.isPaid) ...[
      _total(styles, formatMinutes(shown.volunteerMinutes), compensation.kVolunteerHoursText),
      _total(styles, formatMinutes(shown.paidMinutes), compensation.paidHoursText(shown.paidMinutes)),
    ]
    else ...[pw.SizedBox(), pw.SizedBox()],
  ];

  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: kPdfLine, width: 0.6),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (shown.isPaid) ...[
          _columns(
            [
              _figure(styles, compensation.kGrossPayLabel, _money(shown.gross)),
              _figure(styles, compensation.kWithholdingLabel, _money(withholdingOf(shown.gross, shown.net))),
              _figure(styles, compensation.kNetPayLabel, _money(shown.net), net: true),
              _figure(styles, compensation.kGrossRateLabel, _money(shown.grossRate)),
              _figure(styles, compensation.kNetRateLabel, _money(shown.netRate)),
            ],
            shares: const [4, 4, 4, 5, 4],
            split: 3,
          ),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
            height: 0.6,
            color: kPdfLine,
          ),
        ],
        _columns(totals, shares: const [1, 1, 1, 1]),
      ],
    ),
  );
}

List<({String text, bool online})> _ends(List<CompensationSpan> spans, {required bool end})
{
  return [for (final span in spans) (text: end ? span.end : span.start, online: span.online)];
}

pw.TableRow _row(AccountingPdfStyles styles, CompensationMonth shown, CompensationDay day, {CompensationDay? before})
{
  final bool newWeek = before != null && startOfWeek(before.date) != startOfWeek(day.date);
  final String label = '${weekdayFullName(day.date.weekday)} ${day.date.day}';

  final List<List<pw.Widget>> cells = [
    [pw.Text(label, style: styles.name)],
    [
      accountingTimes(styles, _ends(day.worked, end: false)),
      accountingTimes(styles, _ends(day.worked, end: true)),
      accountingText(styles, formatMinutes(day.workedMinutes), strong: true),
    ],
    if (shown.isPaid) ...[
      [
        accountingTimes(styles, _ends(day.volunteer, end: false)),
        accountingTimes(styles, _ends(day.volunteer, end: true)),
        accountingText(styles, day.volunteerMinutes == 0 ? null : formatMinutes(day.volunteerMinutes), strong: true),
      ],
      [
        accountingText(styles, _amount(day.gross)),
        accountingText(styles, _amount(withholdingOf(day.gross, day.net))),
        accountingText(styles, _amount(day.net)),
      ],
    ],
  ];

  return accountingRow(
    shown.isPaid ? _paidGroups : _plainGroups,
    cells,
    rule: newWeek ? AccountingRule.week : AccountingRule.row,
  );
}

pw.TableRow _totals(AccountingPdfStyles styles, CompensationMonth shown)
{
  final int? gross = shown.gross;
  final int? net = shown.net;

  return accountingRow(
    shown.isPaid ? _paidGroups : _plainGroups,
    [
      [accountingTotalLabel(styles)],
      [pw.SizedBox(), pw.SizedBox(), accountingText(styles, formatMinutes(shown.workedMinutes), strong: true)],
      if (shown.isPaid) ...[
        [
          pw.SizedBox(),
          pw.SizedBox(),
          accountingText(
            styles,
            shown.volunteerMinutes == 0 ? null : formatMinutes(shown.volunteerMinutes),
            strong: true,
          ),
        ],
        [
          accountingText(styles, _amount(gross), strong: true),
          accountingText(styles, _amount(withholdingOf(gross, net)), strong: true),
          accountingText(styles, _amount(net), strong: true),
        ],
      ],
    ],
    rule: AccountingRule.total,
  );
}
