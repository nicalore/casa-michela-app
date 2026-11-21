import '../../association/tabs/tariffs/tariffs_strings.dart' show kInsuranceFee, kMembershipFee;
import '../../people/utils/payments_strings.dart'
    show aheadTitle, feeTitle, hoursText, kHoursTitles, kPaymentMethodLabels, kWaitingFeeTitle, packageTitle;
import '../models/payments_month_items.dart';
import 'accounting_strings.dart';

// Riepilogo mensile › «Pagamenti»: what a row says, on the page and in its PDF.

// What was paid: "Pacchetto di 18 ore", "Quota di novembre", "Ore svolte: 3h 30m", "Iscrizione 2026".
String paymentWhat(MonthPayment row)
{
  if (row.isFee)
  {
    return '${row.kind == 'MEMBERSHIP_FEE' ? kMembershipFee : kInsuranceFee} ${row.year ?? ''}'.trim();
  }

  final DateTime? month = row.month;

  return switch (row.kind)
  {
    'PACKAGE' => packageTitle(row.packageHours ?? 0),
    'MONTH' => month == null ? kWaitingFeeTitle : feeTitle(month),
    'AHEAD' => aheadTitle(row.aheadMinutes ?? 0),
    _ => row.minutes == null
        ? kHoursTitles[row.kind] ?? ''
        : '${kHoursTitles[row.kind] ?? ''}: ${hoursText(row.minutes!).replaceAll(' ', ' ')}',
  };
}

String paymentMethodWords(MonthPayment row)
{
  final String? method = row.paymentMethod;

  return method == null ? '—' : kPaymentMethodLabels[method] ?? row.paymentMethodOther ?? '—';
}

// The filters set, for the PDF: "Ruolo: Docenti; Importo: da 20,00 euro"; null with none.
String? paymentFiltersSaid({String? role, String? tariff, int? least, int? most})
{
  final List<String> said = [
    if (role != null) '$kRoleFilterPrefix: ${kPaymentRoleFilters[role] ?? role}',
    if (tariff != null) '$kTariffFilterPrefix: ${kPaymentTariffFilters[tariff] ?? tariff}',
    if (amountRange(least, most) case final String range) '$kAmountFilterPrefix: $range',
  ];

  return said.isEmpty ? null : said.join('; ');
}
