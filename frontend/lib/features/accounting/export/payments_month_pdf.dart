import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../models/payments_month_items.dart';
import '../utils/accounting_strings.dart';
import '../utils/payments_month_words.dart';
import 'accounting_pdf_look.dart';

// Five columns: an upright page holds them, the payment taking what the others leave.
const List<AccountingGroup> _groups = [
  AccountingGroup(parts: [(label: kPaymentDayColumn, width: 78)], leading: true),
  AccountingGroup(parts: [(label: kDebtorColumn, width: 128)], leading: true),
  AccountingGroup(parts: [(label: kPaymentWhatColumn, width: 0)], flexible: true, leading: true),
  AccountingGroup(parts: [(label: kPaymentMethodColumn, width: 92)], leading: true),
  AccountingGroup(parts: [(label: kOwedAmountColumn, width: 68)]),
];

// The month's payments as the page shows them, filters and order included.
Future<Uint8List> buildPaymentsMonthPdf(DateTime month, List<MonthPayment> rows, {String? filters}) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles();
  final pw.Document document = accountingPdfDocument(styles, monthlyPaymentsPdfTab(month));
  final int total = rows.fold(0, (sum, row) => sum + row.amountCents);

  document.addPage(
    pw.MultiPage(
      pageFormat: kAccountingPortrait,
      maxPages: 40,
      footer: (context) => accountingFooter(context, styles, monthlyPaymentsPdfFooter(month)),
      build: (context) => [
        accountingPdfHeader(
          styles,
          title: monthlyPdfTitle(month),
          pills: [accountingPill(styles, kMonthlySummaryGroup), accountingPill(styles, kPaymentsEntry)],
          meta: [exportedAt(romeNow()), paymentsCount(rows.length), ?filters],
        ),
        pw.SizedBox(height: 6),
        accountingTable(_groups, [
          accountingHeadRow(styles, _groups),
          for (final row in rows) _row(styles, row),
          _totals(styles, total),
        ], format: kAccountingPortrait),
      ],
    ),
  );

  return document.save();
}

pw.TableRow _row(AccountingPdfStyles styles, MonthPayment row)
{
  return accountingRow(_groups, [
    // «4 novembre», as the narrow page: the weekday would wrap.
    [pw.Text(formatDayMonthFull(row.paidOn), style: styles.cell)],
    [pw.Text(row.fullName, style: styles.name)],
    [pw.Text(paymentWhat(row), style: styles.cell)],
    [pw.Text(paymentMethodWords(row), style: styles.cell)],
    [pw.Text(formatAmount(row.amountCents), style: styles.strong)],
  ]);
}

pw.TableRow _totals(AccountingPdfStyles styles, int total)
{
  return accountingRow(
    _groups,
    [
      [accountingTotalLabel(styles)],
      [pw.SizedBox()],
      [pw.SizedBox()],
      [pw.SizedBox()],
      [pw.Text(formatAmount(total), style: styles.strong)],
    ],
    rule: AccountingRule.total,
  );
}
