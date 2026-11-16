import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show kInsuranceFee, kMembershipFee;
import '../models/student_payments_item.dart';

const String kPaymentsSection = 'Pagamenti';

const String kTariffFigure = 'Tariffa';
const String kCostFigure = 'Costo';
const String kPaymentMethodFigure = 'Modalità di pagamento';

const String kInOrder = 'In regola';
const String kToRenew = 'Da rinnovare';

String toPay(int cents) => 'Da pagare ${formatAmount(cents)}';

// "venerdì 6 novembre", inside a sentence.
String dayInSentence(DateTime day)
{
  final String label = formatWeekdayColumnLabel(day);

  return '${label[0].toLowerCase()}${label.substring(1)}';
}

String packageEnded(DateTime day) => 'Pacchetto terminato ${dayInSentence(day)}';

String feeNotRenewed(DateTime month) => 'Quota di ${formatMonthName(month)} non ancora rinnovata';

const Map<String, String> kTariffKindLabels = {
  'HOURLY': 'A ore',
  'PACKAGE': 'Pacchetto',
  'MONTHLY': 'Quota mensile',
};

String tariffCost(String kind, int cents, int? packageHours)
{
  final String amount = formatAmount(cents);

  return switch (kind)
  {
    'HOURLY' => '$amount l’ora',
    'PACKAGE' => '$amount per ${packageHours == 1 ? '1 ora' : '$packageHours ore'}',
    _ => '$amount al mese',
  };
}

const Map<String, String> kPaymentMethodLabels = {
  'CASH': 'Contanti',
  'BANK_TRANSFER': 'Bonifico bancario',
};

// Minutes alone agree in the masculine: «30m usati», but «2h 30m usate» (his wording).
bool _onlyMinutes(int minutes) => minutes > 0 && minutes < 60;

// «0h», never «0m».
String hoursText(int minutes) => minutes == 0 ? '0h' : formatMinutes(minutes);

String usedLabel(int minutes) => '${hoursText(minutes)} ${_onlyMinutes(minutes) ? 'usati' : 'usate'}';

String leftLabel(int minutes) => '${hoursText(minutes)} ${_onlyMinutes(minutes) ? 'rimasti' : 'rimaste'}';

// After the hours of each line to settle.
String hoursLineUnit(String kind, int minutes)
{
  return switch (kind)
  {
    'HOURLY' => _onlyMinutes(minutes) ? 'svolti' : 'svolte',
    'OVER_PACKAGE' => 'oltre il pacchetto',
    'OVER_FEE' => 'oltre la quota',
    _ => 'online nel weekend da pagare',
  };
}

const String kMonthPaid = 'Pagata';
const String kMonthDue = 'Da rinnovare';

// The buttons between the summary and the status.
const String kRenewLabel = 'RINNOVA';
const String kChangeTariffLabel = 'CAMBIA TARIFFA';
const String kGiveTariffLabel = 'ASSEGNA TARIFFA';
const String kChangeRateLabel = 'CAMBIA COSTO ORARIO';
const String kSettleLabel = 'SALDA';
const String kPayAheadLabel = 'PAGA IN ANTICIPO';
const String kCancelPaymentLabel = 'REVOCA PAGAMENTO';
const String kConfirmCancelLabel = 'REVOCA';

// The confirm button of the change windows; the renewal's is «RINNOVA».
const String kChangeLabel = 'CAMBIA';
const String kGiveLabel = 'ASSEGNA';
const String kPayLabel = 'PAGA';

const String kPackageQueuedReason = 'Già rinnovato: il prossimo pacchetto parte alla fine di questo.';
const String kMonthQueuedReason = 'Prossimo mese già pagato.';

// [startsOn] null: the new one waits for the package, or the hours paid ahead, to end.
String changeQueuedReason(DateTime? startsOn, {bool ahead = false})
{
  final String end = ahead ? 'alla fine delle ore in anticipo' : 'alla fine di questo pacchetto';

  return 'Tariffa già cambiata: parte ${startsOn == null ? end : _from(startsOn)}.';
}

// "da dicembre" on the 1st, "da lunedì 15 giugno" otherwise.
String _from(DateTime day) => day.day == 1 ? 'da ${formatMonthName(day)}' : 'da ${dayInSentence(day)}';

// Dialogs.
const String kPackageEyebrow = 'Pacchetto';
const String kMonthlyEyebrow = 'Quota mensile';
const String kTariffEyebrow = 'Tariffa';
const String kPaymentEyebrow = 'Pagamento';

const String kRenewPackageTitle = 'Rinnova pacchetto';
const String kRenewMonthTitle = 'Rinnova quota';
const String kChangeTariffTitle = 'Cambia tariffa';
const String kGiveTariffTitle = 'Assegna tariffa';
const String kChangeRateTitle = 'Cambia costo orario';
const String kSettleTitle = 'Salda le ore';
const String kPayAheadTitle = 'Paga in anticipo';

const String kAheadHoursLabel = 'Ore';
const String kAheadHoursHint = 'Es. 10';
const String kAheadMinutesLabel = 'Minuti';

// The minutes beside the hours: a lesson is booked by the quarter hour.
const List<int> kAheadMinuteChoices = [0, 15, 30, 45];

const String kCurrentTariffLabel = 'Tariffa attuale';

String currentTariff(String kind, int cents, int? packageHours)
{
  return '${kTariffKindLabels[kind] ?? ''} – ${tariffCost(kind, cents, packageHours)}';
}

const String kNewTariffLabel = 'Nuova tariffa';
const String kFromDayLabel = 'Dal giorno';
const String kFromWhenLabel = 'Da quando';

String fromMonth(DateTime month) => 'Da ${formatMonthName(month)}';

const String kPaymentBlock = 'Pagamento';
const String kPackagePaymentBlock = 'Pagamento del pacchetto';
const String kFirstFeePaymentBlock = 'Pagamento della prima quota';

String feePaymentBlock(DateTime month) => 'Pagamento della quota di ${formatMonthName(month)}';

const String kPaidOnLabel = 'Data del pagamento';
const String kDateHint = 'gg/mm/aaaa';
const String kPaymentMethodLabel = 'Modalità di pagamento';
const String kCashChoice = 'Contanti';
const String kBankTransferChoice = 'Bonifico bancario';
const String kOtherChoice = 'Altro';
const List<String> kPaymentMethodChoices = [kCashChoice, kBankTransferChoice, kOtherChoice];
const String kOtherMethodLabel = 'Altra modalità';
const String kOtherMethodHint = 'Es. Carta di credito';

const String kAmountLabel = 'Importo';

// When the renewal or the change starts.
const String kAtPackageEnd = 'Parte alla fine di questo pacchetto';
const String kAtAheadEnd = 'Parte alla fine delle ore in anticipo';

String startsFromMonth(DateTime month) => 'Parte da ${formatMonthName(month)}';

String startsFromDay(DateTime day) => 'Parte da ${dayInSentence(day)}';

// «1h 30m» agrees as one: «La 1h 30m svolta», «Le 6h 30m svolte».
bool _one(int minutes) => minutes ~/ 60 == 1;

String stillLeft(int minutes)
{
  return '${_one(minutes) ? 'Resta' : 'Restano'} ancora ${hoursText(minutes)}';
}

String doneBeforeToSettle(int minutes)
{
  final String hours = formatMinutes(minutes);

  if (_onlyMinutes(minutes))
  {
    return 'I $hours svolti prima devono essere saldati come pagamento a ore.';
  }

  return _one(minutes)
      ? 'La $hours svolta prima deve essere saldata come pagamento a ore.'
      : 'Le $hours svolte prima devono essere saldate come pagamento a ore.';
}

String doneInMonthToSettle(int minutes, DateTime month)
{
  final String hours = formatMinutes(minutes);
  final String name = formatMonthName(month);

  if (_onlyMinutes(minutes))
  {
    return 'I $hours svolti a $name devono essere saldati come pagamento a ore.';
  }

  return _one(minutes)
      ? 'La $hours svolta a $name deve essere saldata come pagamento a ore.'
      : 'Le $hours svolte a $name devono essere saldate come pagamento a ore.';
}

String coveredByFee(int minutes)
{
  final String hours = formatMinutes(minutes);

  if (_onlyMinutes(minutes))
  {
    return 'I $hours ancora da saldare verranno coperti dalla quota mensile.';
  }

  return _one(minutes)
      ? 'La $hours ancora da saldare verrà coperta dalla quota mensile.'
      : 'Le $hours ancora da saldare verranno coperte dalla quota mensile.';
}

// The question before a payment is cancelled.
String cancelPaymentMessage(PaymentHistoryRow row)
{
  final String lead = 'Il pagamento di ${formatAmount(row.amountCents)} verrà revocato';
  final int minutes = row.minutes;

  if (row.isFee)
  {
    return '$lead e la quota tornerà da saldare.';
  }

  if (minutes == 0)
  {
    return '$lead.';
  }

  final String hours = formatMinutes(minutes);

  if (row.isHours)
  {
    if (_onlyMinutes(minutes))
    {
      return '$lead e i $hours saldati torneranno da saldare.';
    }

    return _one(minutes)
        ? '$lead e la $hours saldata tornerà da saldare.'
        : '$lead e le $hours saldate torneranno da saldare.';
  }

  if (_onlyMinutes(minutes))
  {
    return '$lead e i $hours che copriva torneranno da saldare come pagamento a ore.';
  }

  return _one(minutes)
      ? '$lead e la $hours che copriva tornerà da saldare come pagamento a ore.'
      : '$lead e le $hours che copriva torneranno da saldare come pagamento a ore.';
}

const String kDoneStillToSettle = 'Le ore già svolte sono ancora da saldare.';
const String kDoneTakenByPackage = 'Le ore già svolte verranno scalate dal pacchetto.';
const String kUnsettledTakenNow = 'Le ore non saldate verranno scalate immediatamente.';

String aheadKeepsItsPrice(int minutes)
{
  final String hours = formatMinutes(minutes);

  if (_onlyMinutes(minutes))
  {
    return 'I $hours pagati in anticipo restano al prezzo pagato.';
  }

  return _one(minutes)
      ? 'La $hours pagata in anticipo resta al prezzo pagato.'
      : 'Le $hours pagate in anticipo restano al prezzo pagato.';
}

String rateFromDayNote(int newCents, int oldCents)
{
  return 'Le lezioni da questo giorno in poi costano ${formatAmount(newCents)} l’ora; '
      'quelle prima restano a ${formatAmount(oldCents)}.';
}

// The history under the status card.
const String kHistoryHeading = 'Storico';
const String kPaidThisYearLabel = 'Pagato quest’anno';

String historyYearHeading(int year) => '$kHistoryHeading $year';

String paidInYear(int year) => 'Pagato nel $year';

// By calendar year, the newest first: a payment by the day it was paid, one to pay by its last lesson.
Map<int, List<PaymentHistoryRow>> paymentsByYear(List<PaymentHistoryRow> rows, int thisYear)
{
  final Map<int, List<PaymentHistoryRow>> years = {};

  for (final PaymentHistoryRow row in rows)
  {
    final int year = row.paidOn?.year ?? row.lastDay?.year ?? thisYear;

    years.putIfAbsent(year, () => []).add(row);
  }

  final List<int> order = years.keys.toList()..sort((a, b) => b.compareTo(a));

  return {for (final int year in order) year: years[year]!};
}

const String kPaymentColumn = 'Pagamento';
const String kHoursColumn = 'Ore';
const String kAmountColumn = 'Importo';
const String kPaidOnColumn = 'Pagato il';
const String kMethodColumn = 'Modalità';
const String kDayColumn = 'Giorno';
const String kLeftColumn = 'Rimaste';
const String kCostColumn = 'Costo';

String packageTitle(int hours) => 'Pacchetto di ${hours == 1 ? '1 ora' : '$hours ore'}';

// «10 ore» when whole, «7h 30m» otherwise.
String aheadHours(int minutes)
{
  if (minutes % 60 != 0)
  {
    return hoursText(minutes);
  }

  return minutes == 60 ? '1 ora' : '${minutes ~/ 60} ore';
}

String aheadTitle(int minutes) => 'Anticipo di ${aheadHours(minutes)}';

// Under the status, over the bar of the hours paid ahead.
String aheadPaidLine(int minutes)
{
  final String said = aheadHours(minutes);

  if (_onlyMinutes(minutes))
  {
    return '$said pagati in anticipo';
  }

  return minutes ~/ 60 == 1 ? '$said pagata in anticipo' : '$said pagate in anticipo';
}

String feeTitle(DateTime month) => 'Quota di ${formatMonthName(month)}';

// A fee that waits for a package to end, its month not known yet.
const String kWaitingFeeTitle = 'Quota mensile';

const Map<String, String> kHoursTitles = {
  'HOURLY': 'Ore svolte',
  'OVER_PACKAGE': 'Ore oltre il pacchetto',
  'OVER_FEE': 'Ore oltre la quota',
  'WEEKEND_ONLINE': 'Ore online nel weekend',
};

String runningSince(DateTime day) => 'In corso ${fromDayInSentence(day)}';

// The first and the last lesson's days; one lesson alone says its weekday.
String lessonsSpan(DateTime first, DateTime last)
{
  final bool sameDay = first.year == last.year && first.month == last.month && first.day == last.day;

  return sameDay ? formatWeekdayColumnLabel(first) : formatDateSpan(first, last);
}

// An annual fee and its membership year, as the creation wizard names it.
String annualFeeTitle(PaymentHistoryRow row)
{
  final String name = row.kind == 'MEMBERSHIP_FEE' ? kMembershipFee : kInsuranceFee;

  return '$name ${row.year ?? ''}'.trim();
}

String historyTitle(PaymentHistoryRow row)
{
  final DateTime? month = row.month;

  if (row.isFee)
  {
    return annualFeeTitle(row);
  }

  if (row.isPackage)
  {
    return packageTitle(row.packageHours ?? 0);
  }

  if (row.isAhead)
  {
    return aheadTitle(row.aheadMinutes ?? 0);
  }

  if (row.isMonth)
  {
    return month == null ? kWaitingFeeTitle : feeTitle(month);
  }

  return kHoursTitles[row.kind] ?? '';
}

// Minutes the initial set-up carries, in place of a lesson's day: «Al 15 novembre».
String atOpeningDay(DateTime day) => 'Al ${formatDayMonthFull(day)}';

// The days of its lessons: a package running says since when, one paid ahead when it starts.
String? historyLine(PaymentHistoryRow row)
{
  final DateTime? first = row.firstDay;
  final DateTime? last = row.lastDay;

  if (first != null && row.lessons.isNotEmpty && row.lessons.every((lesson) => lesson.opening))
  {
    return atOpeningDay(first);
  }

  if (row.state == PaymentHistoryState.waiting)
  {
    return row.isAhead ? kAtAheadEnd : kAtPackageEnd;
  }

  if (row.isMonth || first == null || last == null)
  {
    return null;
  }

  return row.state == PaymentHistoryState.running ? runningSince(first) : lessonsSpan(first, last);
}

// The status card's title and the line under it; the PDF repeats them.
String paymentStateTitle(StudentPaymentsItem payments)
{
  return switch (payments.state)
  {
    PaymentState.renew => kToRenew,
    PaymentState.due => toPay(payments.dueCents),
    _ => kInOrder,
  };
}

String? paymentStateLine(StudentPaymentsItem payments, DateTime today)
{
  final AheadStatusItem? ahead = payments.ahead;

  if (ahead != null && payments.tariff?.isHourly == true)
  {
    return aheadPaidLine(ahead.totalMinutes);
  }

  if (payments.state != PaymentState.renew)
  {
    return null;
  }

  if (payments.tariff?.isMonthly == true)
  {
    return feeNotRenewed(today);
  }

  final DateTime? ended = payments.package?.endedOn;

  return ended == null ? null : packageEnded(ended);
}

const String kToPayFlag = 'Da pagare';
const String kExhaustedBadge = 'Pacchetto esaurito';
const String kTakenBadge = 'Scalate al rinnovo';
const String kAheadExhaustedBadge = 'Anticipo esaurito';
const String kTakenAtPaymentBadge = 'Scalate al pagamento';

String exhaustedBadge(PaymentHistoryRow row) => row.isAhead ? kAheadExhaustedBadge : kExhaustedBadge;

String takenBadge(PaymentHistoryRow row) => row.isAhead ? kTakenAtPaymentBadge : kTakenBadge;

// Under the hours of a lesson another payment shares.
String ofLesson(int minutes) => 'di ${formatMinutes(minutes)}';

// "30m di 18h".
String hoursOfPackage(int used, int hours) => '${hoursText(used)} di ${hours}h';

// "8h di 10h", "45m di 7h 30m".
String hoursOfAhead(int used, int minutes) => '${hoursText(used)} di ${hoursText(minutes)}';

const String kNoPayments = 'Ancora nessun pagamento.';

// The PDF.
const String kPaymentsEyebrow = 'Pagamenti';
const String kExportTitle = 'Esporta PDF';
const String kToDayLabel = 'Al giorno';
const String kFromStartLabel = 'Dall’inizio';
const String kExportLabel = 'ESPORTA';

const String kPaidInSpanLabel = 'Pagato nel periodo';
const String kToPayLabel = 'Da pagare';
const String kPdfPaymentsSection = 'Pagamenti';
const String kPdfDetailSection = 'Dettaglio';

String paymentsPdfTitle(String name) => 'Pagamenti di $name';

// "Dall'1 settembre al 12 novembre 2026"; the year on both ends when they differ.
String paymentsSpan(DateTime from, DateTime to)
{
  if (from.year == to.year)
  {
    return '${formatDateSpan(from, to)} ${to.year}';
  }

  final String start = fromDayInSentence(from);

  return '${start[0].toUpperCase()}${start.substring(1)} ${from.year} ${toDayInSentence(to)} ${to.year}';
}

String _inSentence(String said) => '${said[0].toLowerCase()}${said.substring(1)}';

String paymentsPdfFooter(String name, DateTime from, DateTime to) => 'Pagamenti · $name · ${_inSentence(paymentsSpan(from, to))}';

String paymentsPdfFile(String name, DateTime from, DateTime to) => 'Pagamenti $name ${_inSentence(paymentsSpan(from, to))}.pdf';

// Snackbars.
const String kPackageRenewed = 'Pacchetto rinnovato.';
const String kFeeRenewed = 'Quota rinnovata.';
const String kTariffChanged = 'Tariffa cambiata.';
const String kTariffGiven = 'Tariffa assegnata.';
const String kRateChanged = 'Costo orario cambiato.';
const String kHoursSettled = 'Ore saldate.';
const String kHoursPaidAhead = 'Ore pagate in anticipo.';
const String kFeeSettled = 'Quota saldata.';
const String kPaymentCancelled = 'Pagamento revocato.';

const String kRequiredField = 'Campo obbligatorio';
const String kInvalidAmountMessage = 'Importo non valido';
const String kInvalidNumber = 'Numero non valido';
const String kInvalidDate = 'Data non valida';
const String kEndBeforeStart = 'Prima del giorno di inizio';
const String kDayTooEarly = 'Il giorno è prima dell’inizio della tariffa attuale.';
const String kDayInFuture = 'Il giorno è nel futuro.';
const String kDayTooFar = 'Il giorno è troppo lontano.';
