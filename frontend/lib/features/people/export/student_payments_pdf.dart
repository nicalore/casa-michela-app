import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../core/utils/word_lists.dart';
import '../../accounting/export/accounting_pdf_look.dart';
import '../../accounting/utils/accounting_strings.dart' show exportedAt;
import '../../lessons/export/calendar_pdf_palette.dart';
import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart';

// Over this a payment's lessons may run on to the next page; under it they move there whole.
const int _wholeBlockLessons = 30;

AccountingGroup get _paymentGroup => AccountingGroup(
  parts: [(label: kPaymentColumn, width: 0)],
  flexible: true,
  leading: true,
);

AccountingGroup get _paymentFigures => AccountingGroup(
  parts: [
    (label: kHoursColumn, width: 50),
    (label: kAmountColumn, width: 62),
    (label: kPaidOnColumn, width: 118),
    (label: kMethodColumn, width: 96),
  ],
);

List<AccountingGroup> get _paymentGroups => [_paymentGroup, _paymentFigures];

AccountingGroup get _dayGroup => AccountingGroup(
  parts: [(label: kDayColumn, width: 0)],
  flexible: true,
  leading: true,
);

List<AccountingGroup> _lessonGroups(PaymentHistoryRow row)
{
  return [
    _dayGroup,
    AccountingGroup(
      parts: [
        (label: kHoursColumn, width: 64),
        if (row.countsDown) (label: kLeftColumn, width: 72),
        if (row.isHours) (label: kCostColumn, width: 72),
      ],
    ),
  ];
}

bool _within(DateTime day, DateTime from, DateTime to) => !day.isBefore(from) && !day.isAfter(to);

// Those paid between the two days, those to pay with a lesson between them, and fees owed when the
// period reaches today.
List<PaymentHistoryRow> paymentsBetween(List<PaymentHistoryRow> rows, DateTime from, DateTime to)
{
  final DateTime now = romeNow();
  final DateTime today = DateTime(now.year, now.month, now.day);

  bool included(PaymentHistoryRow row)
  {
    final DateTime? paid = row.paidOn;

    if (paid != null)
    {
      return _within(paid, from, to);
    }

    if (row.isFee)
    {
      return !to.isBefore(today);
    }

    return row.lessons.any((lesson) => _within(lesson.day, from, to));
  }

  return rows.where(included).toList();
}

String _method(PaymentHistoryRow row)
{
  final String? method = row.paymentMethod;

  return method == null ? '—' : kPaymentMethodLabels[method] ?? row.paymentMethodOther ?? '—';
}

// A pupil's payments between two days, as the Pagamenti tab shows them, each followed by its lessons.
Future<Uint8List> buildStudentPaymentsPdf({
  required String name,
  required StudentPaymentsItem payments,
  required DateTime from,
  required DateTime to,
}) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles();
  final String footer = paymentsPdfFooter(name, from, to);
  final pw.Document document = accountingPdfDocument(styles, footer);
  final List<PaymentHistoryRow> rows = paymentsBetween(payments.history, from, to);

  document.addPage(
    pw.MultiPage(
      pageFormat: kAccountingPortrait,
      maxPages: 50,
      footer: (context) => accountingFooter(context, styles, footer),
      build: (context) => [
        accountingPdfHeader(
          styles,
          title: paymentsPdfTitle(name),
          pills: [accountingPill(styles, paymentsSpan(from, to))],
          meta: [exportedAt(romeNow())],
        ),
        pw.SizedBox(height: 10),
        _figures(styles, payments, rows, to),
        pw.SizedBox(height: 12),
        _section(styles, kPdfPaymentsSection),
        accountingTable(_paymentGroups, [
          accountingHeadRow(styles, _paymentGroups),
          for (final PaymentHistoryRow row in rows) _paymentRow(styles, row),
        ], format: kAccountingPortrait),
        if (rows.any((row) => row.lessons.isNotEmpty)) ...[
          pw.SizedBox(height: 12),
          _section(styles, kPdfDetailSection),
          for (final (index, row) in rows.where((row) => row.lessons.isNotEmpty).indexed)
            ..._detail(styles, row, first: index == 0),
        ],
      ],
    ),
  );

  return document.save();
}

pw.Widget _section(AccountingPdfStyles styles, String label)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(label.toUpperCase(), style: styles.total),
  );
}

pw.Widget _toPay(AccountingPdfStyles styles)
{
  return accountingStatePill(styles, kToPayFlag.toUpperCase(), accent: kPdfOnline, surface: kPdfOnlineSurface);
}

pw.Widget _figure(AccountingPdfStyles styles, String label, String value, {pw.TextStyle? style})
{
  return pw.Padding(
    padding: const pw.EdgeInsets.only(right: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: styles.figureLabel),
        pw.SizedBox(height: 2),
        pw.Text(value, style: (style ?? styles.figure).copyWith(fontSize: 11)),
      ],
    ),
  );
}

// The box's state line speaks of the period: what is left to pay among its payments; renewing, and
// the line under it, only when the period reaches today.
({String title, String? line, bool ok}) periodState(
  StudentPaymentsItem payments,
  List<PaymentHistoryRow> rows,
  DateTime to,
  DateTime now,
)
{
  final int due = rows.where((row) => !row.isPaid).fold(0, (sum, row) => sum + row.amountCents);
  final bool today = !to.isBefore(DateTime(now.year, now.month, now.day));
  final bool renew = today && payments.state == PaymentState.renew;

  return (
    title: renew ? kToRenew : (due > 0 ? toPay(due) : kInOrder),
    line: today ? paymentStateLine(payments, now) : null,
    ok: !renew && due == 0,
  );
}

pw.Widget _figures(AccountingPdfStyles styles, StudentPaymentsItem payments, List<PaymentHistoryRow> rows, DateTime to)
{
  final StudentTariffItem? tariff = payments.tariff;
  final int paid = rows.where((row) => row.isPaid).fold(0, (sum, row) => sum + row.amountCents);
  final int due = rows.where((row) => !row.isPaid).fold(0, (sum, row) => sum + row.amountCents);
  final (:title, :line, :ok) = periodState(payments, rows, to, romeNow());

  final List<(pw.Widget, int)> figures = [
    (_figure(styles, kTariffFigure, tariff == null ? '—' : kTariffKindLabels[tariff.kind] ?? '—'), 4),
    (_figure(styles, kCostFigure, tariff == null ? '—' : tariffCost(tariff.kind, tariff.amountCents, tariff.packageHours)), 6),
  ];

  final List<(pw.Widget, int)> totals = [
    (_figure(styles, kPaidInSpanLabel, formatAmount(paid)), 5),
    if (due > 0) (_figure(styles, kToPayLabel, formatAmount(due), style: styles.figure.copyWith(color: kPdfOnline)), 3),
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
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final (figure, share) in figures) pw.Expanded(flex: share, child: figure),
            pw.Expanded(
              flex: 8,
              child: pw.Container(
                padding: const pw.EdgeInsets.only(left: 12),
                decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: kPdfLine, width: 0.8))),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [for (final (figure, share) in totals) pw.Expanded(flex: share, child: figure)],
                ),
              ),
            ),
          ],
        ),
        pw.Container(margin: const pw.EdgeInsets.only(top: 8, bottom: 6), height: 0.6, color: kPdfLine),
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: title,
                style: styles.figureLineStrong.copyWith(color: ok ? kPdfPresence : kPdfOnline),
              ),
              if (line != null) pw.TextSpan(text: ': ${lowerFirst(line)}', style: styles.figureLine),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _titled(AccountingPdfStyles styles, PaymentHistoryRow row)
{
  final String? line = historyLine(row);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(historyTitle(row), style: styles.name),
      if (line != null) pw.Text(line, style: styles.caption.copyWith(fontSize: 7.6)),
    ],
  );
}

pw.TableRow _paymentRow(AccountingPdfStyles styles, PaymentHistoryRow row)
{
  final DateTime? paidOn = row.paidOn;

  return accountingRow(_paymentGroups, [
    [_titled(styles, row)],
    [
      accountingText(styles, row.minutes == 0 ? null : hoursText(row.minutes)),
      pw.Text(formatAmount(row.amountCents), style: styles.strong.copyWith(color: row.isPaid ? kPdfPresence : kPdfOnline)),
      paidOn == null ? _toPay(styles) : accountingText(styles, formatWeekdayColumnLabel(paidOn)),
      paidOn == null ? accountingDash(styles) : accountingText(styles, _method(row)),
    ],
  ]);
}

// The title, «DA PAGARE» when it is, then its lessons; kept on one page while they fit.
List<pw.Widget> _detail(AccountingPdfStyles styles, PaymentHistoryRow row, {required bool first})
{
  final List<AccountingGroup> groups = _lessonGroups(row);

  // Clear of the table before it.
  final pw.Widget title = pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(2, first ? 6 : 20, 2, 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(child: pw.Text(historyTitle(row), style: styles.name)),
        if (!row.isPaid) _toPay(styles),
      ],
    ),
  );

  final pw.Widget table = accountingTable(groups, [
    accountingHeadRow(styles, groups),
    for (final PaymentHistoryLesson lesson in row.lessons) _lessonRow(styles, row, groups, lesson),
  ], format: kAccountingPortrait);

  if (row.lessons.length > _wholeBlockLessons)
  {
    return [title, table];
  }

  return [
    pw.Inseparable(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [title, table])),
  ];
}

pw.TableRow _lessonRow(
  AccountingPdfStyles styles,
  PaymentHistoryRow row,
  List<AccountingGroup> groups,
  PaymentHistoryLesson lesson,
)
{
  final pw.Widget hours = pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(hoursText(lesson.minutes), style: styles.cell),
      if (lesson.isPart) pw.Text(ofLesson(lesson.lessonMinutes), style: styles.caption.copyWith(fontSize: 7.4)),
    ],
  );

  return accountingRow(groups, [
    [
      pw.Row(
        children: [
          pw.Text(formatWeekdayColumnLabel(lesson.day), style: styles.cell),
          if (lesson.exhausted) ...[pw.SizedBox(width: 4), accountingTag(styles, exhaustedBadge(row).toUpperCase())],
          if (lesson.beforePayment) ...[pw.SizedBox(width: 4), accountingTag(styles, takenBadge(row).toUpperCase())],
        ],
      ),
    ],
    [
      hours,
      if (row.countsDown) accountingText(styles, hoursText(lesson.leftMinutes ?? 0)),
      if (row.isHours) accountingText(styles, formatAmount(lesson.cents ?? 0)),
    ],
  ]);
}
