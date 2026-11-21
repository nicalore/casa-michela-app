import '../../../core/language/app_language.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show kInsuranceFee, kMembershipFee;
import '../models/student_payments_item.dart';

String get kPaymentsSection => tr('Pagamenti', 'Payments');

String get kTariffFigure => tr('Tariffa', 'Rate');
String get kCostFigure => tr('Costo', 'Cost');
String get kPaymentMethodFigure => tr('Modalità di pagamento', 'Payment method');

String get kInOrder => tr('In regola', 'Up to date');
String get kToRenew => tr('Da rinnovare', 'To renew');

String toPay(int cents) => tr('Da pagare ${formatAmount(cents)}', 'To pay ${formatAmount(cents)}');

// "venerdì 6 novembre", inside a sentence.
String dayInSentence(DateTime day)
{
  final String label = formatWeekdayColumnLabel(day);

  // English weekdays keep their capital.
  return isEnglish ? label : '${label[0].toLowerCase()}${label.substring(1)}';
}

String packageEnded(DateTime day) =>
    tr('Pacchetto terminato ${dayInSentence(day)}', 'Package ended on ${dayInSentence(day)}');

String feeNotRenewed(DateTime month) =>
    tr('Quota di ${formatMonthName(month)} non ancora rinnovata', '${formatMonthName(month)} fee not renewed yet');

Map<String, String> get kTariffKindLabels => {
  'HOURLY': tr('A ore', 'Hourly'),
  'PACKAGE': tr('Pacchetto', 'Hours package'),
  'MONTHLY': tr('Quota mensile', 'Monthly fee'),
};

String tariffCost(String kind, int cents, int? packageHours)
{
  final String amount = formatAmount(cents);

  return switch (kind)
  {
    'HOURLY' => tr('$amount l’ora', '$amount an hour'),
    'PACKAGE' => packageHours == 1
        ? tr('$amount per 1 ora', '$amount for 1 hour')
        : tr('$amount per $packageHours ore', '$amount for $packageHours hours'),
    _ => tr('$amount al mese', '$amount a month'),
  };
}

Map<String, String> get kPaymentMethodLabels => {
  'CASH': tr('Contanti', 'Cash'),
  'BANK_TRANSFER': tr('Bonifico bancario', 'Bank transfer'),
};

// Minutes alone agree in the masculine: «30m usati», but «2h 30m usate» (his wording).
bool _onlyMinutes(int minutes) => minutes > 0 && minutes < 60;

// «0h», never «0m».
String hoursText(int minutes) => minutes == 0 ? '0h' : formatMinutes(minutes);

String usedLabel(int minutes) =>
    '${hoursText(minutes)} ${tr(_onlyMinutes(minutes) ? 'usati' : 'usate', 'used')}';

String leftLabel(int minutes) =>
    '${hoursText(minutes)} ${tr(_onlyMinutes(minutes) ? 'rimasti' : 'rimaste', 'left')}';

// After the hours of each line to settle.
String hoursLineUnit(String kind, int minutes)
{
  return switch (kind)
  {
    'HOURLY' => tr(_onlyMinutes(minutes) ? 'svolti' : 'svolte', 'done'),
    'OVER_PACKAGE' => tr('oltre il pacchetto', 'over the package'),
    'OVER_FEE' => tr('oltre la quota', 'over the fee'),
    _ => tr('online nel weekend da pagare', 'online at the weekend to pay'),
  };
}

String get kMonthPaid => tr('Pagata', 'Paid');
String get kMonthDue => tr('Da rinnovare', 'To renew');

// The buttons between the summary and the status.
String get kRenewLabel => tr('RINNOVA', 'RENEW');
String get kChangeTariffLabel => tr('CAMBIA TARIFFA', 'CHANGE RATE');
String get kGiveTariffLabel => tr('ASSEGNA TARIFFA', 'ASSIGN RATE');
String get kChangeRateLabel => tr('CAMBIA COSTO ORARIO', 'CHANGE HOURLY COST');
String get kSettleLabel => tr('SALDA', 'SETTLE');
String get kPayAheadLabel => tr('PAGA IN ANTICIPO', 'PAY IN ADVANCE');
String get kCancelPaymentLabel => tr('REVOCA PAGAMENTO', 'REVOKE PAYMENT');
String get kConfirmCancelLabel => tr('REVOCA', 'REVOKE');

// The confirm button of the change windows; the renewal's is «RINNOVA».
String get kChangeLabel => tr('CAMBIA', 'CHANGE');
String get kGiveLabel => tr('ASSEGNA', 'ASSIGN');
String get kPayLabel => tr('PAGA', 'PAY');

String get kPackageQueuedReason => tr(
  'Già rinnovato: il prossimo pacchetto parte alla fine di questo.',
  'Already renewed: the next package starts when this one ends.',
);
String get kMonthQueuedReason => tr('Prossimo mese già pagato.', 'Next month already paid.');

// [startsOn] null: the new one waits for the package, or the hours paid ahead, to end.
String changeQueuedReason(DateTime? startsOn, {bool ahead = false})
{
  final String end = ahead
      ? tr('alla fine delle ore in anticipo', 'when the hours paid in advance run out')
      : tr('alla fine di questo pacchetto', 'when this package ends');
  final String when = startsOn == null ? end : _from(startsOn);

  return tr('Tariffa già cambiata: parte $when.', 'Rate already changed: it starts $when.');
}

// "da dicembre" on the 1st, "da lunedì 15 giugno" otherwise.
String _from(DateTime day)
{
  return day.day == 1
      ? tr('da ${formatMonthName(day)}', 'from ${formatMonthName(day)}')
      : tr('da ${dayInSentence(day)}', 'from ${dayInSentence(day)}');
}

// Dialogs.
String get kPackageEyebrow => tr('Pacchetto', 'Hours package');
String get kMonthlyEyebrow => tr('Quota mensile', 'Monthly fee');
String get kTariffEyebrow => tr('Tariffa', 'Rate');
String get kPaymentEyebrow => tr('Pagamento', 'Payment');

String get kRenewPackageTitle => tr('Rinnova pacchetto', 'Renew package');
String get kRenewMonthTitle => tr('Rinnova quota', 'Renew fee');
String get kChangeTariffTitle => tr('Cambia tariffa', 'Change rate');
String get kGiveTariffTitle => tr('Assegna tariffa', 'Assign rate');
String get kChangeRateTitle => tr('Cambia costo orario', 'Change hourly cost');
String get kSettleTitle => tr('Salda le ore', 'Settle the hours');
String get kPayAheadTitle => tr('Paga in anticipo', 'Pay in advance');

String get kAheadHoursLabel => tr('Ore', 'Hours');
String get kAheadHoursHint => tr('Es. 10', 'E.g. 10');
String get kAheadMinutesLabel => tr('Minuti', 'Minutes');

// The minutes beside the hours: a lesson is booked by the quarter hour.
const List<int> kAheadMinuteChoices = [0, 15, 30, 45];

String get kCurrentTariffLabel => tr('Tariffa attuale', 'Current rate');

String currentTariff(String kind, int cents, int? packageHours)
{
  return '${kTariffKindLabels[kind] ?? ''} – ${tariffCost(kind, cents, packageHours)}';
}

String get kNewTariffLabel => tr('Nuova tariffa', 'New rate');
String get kFromDayLabel => tr('Dal giorno', 'From day');
String get kFromWhenLabel => tr('Da quando', 'Starting from');

String fromMonth(DateTime month) => tr('Da ${formatMonthName(month)}', 'From ${formatMonthName(month)}');

String get kPaymentBlock => tr('Pagamento', 'Payment');
String get kPackagePaymentBlock => tr('Pagamento del pacchetto', 'Package payment');
String get kFirstFeePaymentBlock => tr('Pagamento della prima quota', 'First fee payment');

String feePaymentBlock(DateTime month) =>
    tr('Pagamento della quota di ${formatMonthName(month)}', '${formatMonthName(month)} fee payment');

String get kPaidOnLabel => tr('Data del pagamento', 'Payment date');
String get kDateHint => tr('gg/mm/aaaa', 'dd/mm/yyyy');
String get kPaymentMethodLabel => tr('Modalità di pagamento', 'Payment method');
String get kCashChoice => tr('Contanti', 'Cash');
String get kBankTransferChoice => tr('Bonifico bancario', 'Bank transfer');
String get kOtherChoice => tr('Altro', 'Other');
List<String> get kPaymentMethodChoices => [kCashChoice, kBankTransferChoice, kOtherChoice];
String get kOtherMethodLabel => tr('Altra modalità', 'Other method');
String get kOtherMethodHint => tr('Es. Carta di credito', 'E.g. Credit card');

String get kAmountLabel => tr('Importo', 'Amount');

// When the renewal or the change starts.
String get kAtPackageEnd => tr('Parte alla fine di questo pacchetto', 'Starts when this package ends');
String get kAtAheadEnd => tr('Parte alla fine delle ore in anticipo', 'Starts when the hours paid in advance run out');

String startsFromMonth(DateTime month) =>
    tr('Parte da ${formatMonthName(month)}', 'Starts in ${formatMonthName(month)}');

String startsFromDay(DateTime day) => tr('Parte da ${dayInSentence(day)}', 'Starts on ${dayInSentence(day)}');

// «1h 30m» agrees as one: «La 1h 30m svolta», «Le 6h 30m svolte».
bool _one(int minutes) => minutes ~/ 60 == 1;

String stillLeft(int minutes)
{
  final String hours = hoursText(minutes);

  return _one(minutes)
      ? tr('Resta ancora $hours', 'Still $hours left')
      : tr('Restano ancora $hours', 'Still $hours left');
}

String doneBeforeToSettle(int minutes)
{
  final String hours = formatMinutes(minutes);

  if (_onlyMinutes(minutes))
  {
    return tr(
      'I $hours svolti prima devono essere saldati come pagamento a ore.',
      'The $hours done before must be settled as an hourly payment.',
    );
  }

  return _one(minutes)
      ? tr(
          'La $hours svolta prima deve essere saldata come pagamento a ore.',
          'The $hours done before must be settled as an hourly payment.',
        )
      : tr(
          'Le $hours svolte prima devono essere saldate come pagamento a ore.',
          'The $hours done before must be settled as an hourly payment.',
        );
}

String doneInMonthToSettle(int minutes, DateTime month)
{
  final String hours = formatMinutes(minutes);
  final String name = formatMonthName(month);

  if (_onlyMinutes(minutes))
  {
    return tr(
      'I $hours svolti a $name devono essere saldati come pagamento a ore.',
      'The $hours done in $name must be settled as an hourly payment.',
    );
  }

  return _one(minutes)
      ? tr(
          'La $hours svolta a $name deve essere saldata come pagamento a ore.',
          'The $hours done in $name must be settled as an hourly payment.',
        )
      : tr(
          'Le $hours svolte a $name devono essere saldate come pagamento a ore.',
          'The $hours done in $name must be settled as an hourly payment.',
        );
}

String coveredByFee(int minutes)
{
  final String hours = formatMinutes(minutes);

  if (_onlyMinutes(minutes))
  {
    return tr(
      'I $hours ancora da saldare verranno coperti dalla quota mensile.',
      'The $hours still due will be covered by the monthly fee.',
    );
  }

  return _one(minutes)
      ? tr(
          'La $hours ancora da saldare verrà coperta dalla quota mensile.',
          'The $hours still due will be covered by the monthly fee.',
        )
      : tr(
          'Le $hours ancora da saldare verranno coperte dalla quota mensile.',
          'The $hours still due will be covered by the monthly fee.',
        );
}

// The question before a payment is cancelled.
String cancelPaymentMessage(PaymentHistoryRow row)
{
  final String amount = formatAmount(row.amountCents);
  final String lead = tr('Il pagamento di $amount verrà revocato', 'The payment of $amount will be revoked');
  final int minutes = row.minutes;

  if (row.isFee)
  {
    return tr('$lead e la quota tornerà da saldare.', '$lead and the fee will be due again.');
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
      return tr('$lead e i $hours saldati torneranno da saldare.', '$lead and the $hours settled will be due again.');
    }

    return _one(minutes)
        ? tr('$lead e la $hours saldata tornerà da saldare.', '$lead and the $hours settled will be due again.')
        : tr('$lead e le $hours saldate torneranno da saldare.', '$lead and the $hours settled will be due again.');
  }

  if (_onlyMinutes(minutes))
  {
    return tr(
      '$lead e i $hours che copriva torneranno da saldare come pagamento a ore.',
      '$lead and the $hours it covered will be due again as an hourly payment.',
    );
  }

  return _one(minutes)
      ? tr(
          '$lead e la $hours che copriva tornerà da saldare come pagamento a ore.',
          '$lead and the $hours it covered will be due again as an hourly payment.',
        )
      : tr(
          '$lead e le $hours che copriva torneranno da saldare come pagamento a ore.',
          '$lead and the $hours it covered will be due again as an hourly payment.',
        );
}

String get kDoneStillToSettle =>
    tr('Le ore già svolte sono ancora da saldare.', 'The hours already done are still due.');
String get kDoneTakenByPackage => tr(
  'Le ore già svolte verranno scalate dal pacchetto.',
  'The hours already done will be deducted from the package.',
);
String get kUnsettledTakenNow =>
    tr('Le ore non saldate verranno scalate immediatamente.', 'The unsettled hours will be deducted straight away.');

String aheadKeepsItsPrice(int minutes)
{
  final String hours = formatMinutes(minutes);

  if (_onlyMinutes(minutes))
  {
    return tr(
      'I $hours pagati in anticipo restano al prezzo pagato.',
      'The $hours paid in advance keep the price paid.',
    );
  }

  return _one(minutes)
      ? tr('La $hours pagata in anticipo resta al prezzo pagato.', 'The $hours paid in advance keep the price paid.')
      : tr('Le $hours pagate in anticipo restano al prezzo pagato.', 'The $hours paid in advance keep the price paid.');
}

String rateFromDayNote(int newCents, int oldCents)
{
  final String newRate = formatAmount(newCents);
  final String oldRate = formatAmount(oldCents);

  return tr(
    'Le lezioni da questo giorno in poi costano $newRate l’ora; quelle prima restano a $oldRate.',
    'Lessons from this day on cost $newRate an hour; earlier ones stay at $oldRate.',
  );
}

// The history under the status card.
String get kHistoryHeading => tr('Storico', 'History');
String get kPaidThisYearLabel => tr('Pagato quest’anno', 'Paid this year');

String historyYearHeading(int year) => '$kHistoryHeading $year';

String paidInYear(int year) => tr('Pagato nel $year', 'Paid in $year');

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

String get kPaymentColumn => tr('Pagamento', 'Payment');
String get kHoursColumn => tr('Ore', 'Hours');
String get kAmountColumn => tr('Importo', 'Amount');
String get kPaidOnColumn => tr('Pagato il', 'Paid on');

// "in contanti", "con bonifico bancario"; null when not known.
String? paymentMethodPhrase(String? method, String? other)
{
  final String? typed = other?.trim();

  return switch (method)
  {
    null => null,
    'CASH' => tr('in contanti', 'in cash'),
    'BANK_TRANSFER' => tr('con bonifico bancario', 'by bank transfer'),
    _ => typed == null || typed.isEmpty ? null : tr('con $typed', 'by $typed'),
  };
}

// Minimal windows: "Pagato lunedì 2 novembre in contanti" under the payment.
String paidOnLine(String day, String? method)
{
  final String when = tr('Pagato ${day[0].toLowerCase()}${day.substring(1)}', 'Paid on $day');

  return method == null ? when : '$when $method';
}
String get kMethodColumn => tr('Modalità', 'Method');
String get kDayColumn => tr('Giorno', 'Day');
String get kLeftColumn => tr('Rimaste', 'Left');
String get kCostColumn => tr('Costo', 'Cost');

String packageTitle(int hours)
{
  return hours == 1
      ? tr('Pacchetto di 1 ora', 'Package of 1 hour')
      : tr('Pacchetto di $hours ore', 'Package of $hours hours');
}

// «10 ore» when whole, «7h 30m» otherwise.
String aheadHours(int minutes)
{
  if (minutes % 60 != 0)
  {
    return hoursText(minutes);
  }

  return minutes == 60 ? tr('1 ora', '1 hour') : tr('${minutes ~/ 60} ore', '${minutes ~/ 60} hours');
}

String aheadTitle(int minutes) => tr('Anticipo di ${aheadHours(minutes)}', 'Advance of ${aheadHours(minutes)}');

// Under the status, over the bar of the hours paid ahead.
String aheadPaidLine(int minutes)
{
  final String said = aheadHours(minutes);

  if (_onlyMinutes(minutes))
  {
    return tr('$said pagati in anticipo', '$said paid in advance');
  }

  return minutes ~/ 60 == 1
      ? tr('$said pagata in anticipo', '$said paid in advance')
      : tr('$said pagate in anticipo', '$said paid in advance');
}

String feeTitle(DateTime month) => tr('Quota di ${formatMonthName(month)}', '${formatMonthName(month)} fee');

// A fee that waits for a package to end, its month not known yet.
String get kWaitingFeeTitle => tr('Quota mensile', 'Monthly fee');

Map<String, String> get kHoursTitles => {
  'HOURLY': tr('Ore svolte', 'Hours done'),
  'OVER_PACKAGE': tr('Ore oltre il pacchetto', 'Hours over the package'),
  'OVER_FEE': tr('Ore oltre la quota', 'Hours over the fee'),
  'WEEKEND_ONLINE': tr('Ore online nel weekend', 'Online hours at the weekend'),
};

String runningSince(DateTime day) =>
    tr('In corso ${fromDayInSentence(day)}', 'Running since ${formatDayMonthFull(day)}');

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
String atOpeningDay(DateTime day) => tr('Al ${formatDayMonthFull(day)}', 'As of ${formatDayMonthFull(day)}');

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

String get kToPayFlag => tr('Da pagare', 'To pay');
String get kExhaustedBadge => tr('Pacchetto esaurito', 'Package used up');
String get kTakenBadge => tr('Scalate al rinnovo', 'Deducted at renewal');
String get kAheadExhaustedBadge => tr('Anticipo esaurito', 'Advance used up');
String get kTakenAtPaymentBadge => tr('Scalate al pagamento', 'Deducted at payment');

String exhaustedBadge(PaymentHistoryRow row) => row.isAhead ? kAheadExhaustedBadge : kExhaustedBadge;

String takenBadge(PaymentHistoryRow row) => row.isAhead ? kTakenAtPaymentBadge : kTakenBadge;

// Under the hours of a lesson another payment shares.
String ofLesson(int minutes) => tr('di ${formatMinutes(minutes)}', 'of ${formatMinutes(minutes)}');

// "30m di 18h".
String hoursOfPackage(int used, int hours) => tr('${hoursText(used)} di ${hours}h', '${hoursText(used)} of ${hours}h');

// "8h di 10h", "45m di 7h 30m".
String hoursOfAhead(int used, int minutes) =>
    tr('${hoursText(used)} di ${hoursText(minutes)}', '${hoursText(used)} of ${hoursText(minutes)}');

String get kNoPayments => tr('Ancora nessun pagamento.', 'No payments yet.');

// The PDF.
String get kPaymentsEyebrow => tr('Pagamenti', 'Payments');
String get kExportTitle => tr('Esporta PDF', 'Export PDF');
String get kToDayLabel => tr('Al giorno', 'Up to');
String get kFromStartLabel => tr('Dall’inizio', 'From the start');
String get kExportLabel => tr('ESPORTA', 'EXPORT');

String get kPaidInSpanLabel => tr('Pagato nel periodo', 'Paid in the period');
String get kToPayLabel => tr('Da pagare', 'To pay');
String get kPdfPaymentsSection => tr('Pagamenti', 'Payments');
String get kPdfDetailSection => tr('Dettaglio', 'Details');

String paymentsPdfTitle(String name) => tr('Pagamenti di $name', 'Payments for $name');

// "Dall'1 settembre al 12 novembre 2026"; the year on both ends when they differ.
String paymentsSpan(DateTime from, DateTime to)
{
  if (from.year == to.year)
  {
    return '${formatDateSpan(from, to)} ${to.year}';
  }

  if (isEnglish)
  {
    return 'From ${formatDayMonthFull(from)} ${from.year} to ${formatDayMonthFull(to)} ${to.year}';
  }

  final String start = fromDayInSentence(from);

  return '${start[0].toUpperCase()}${start.substring(1)} ${from.year} ${toDayInSentence(to)} ${to.year}';
}

String _inSentence(String said) => '${said[0].toLowerCase()}${said.substring(1)}';

String paymentsPdfFooter(String name, DateTime from, DateTime to) =>
    '${tr('Pagamenti', 'Payments')} – $name – ${_inSentence(paymentsSpan(from, to))}';

String paymentsPdfFile(String name, DateTime from, DateTime to) =>
    '${tr('Pagamenti', 'Payments')} $name ${_inSentence(paymentsSpan(from, to))}.pdf';

// Snackbars.
String get kPackageRenewed => tr('Pacchetto rinnovato.', 'Package renewed.');
String get kFeeRenewed => tr('Quota rinnovata.', 'Fee renewed.');
String get kTariffChanged => tr('Tariffa cambiata.', 'Rate changed.');
String get kTariffGiven => tr('Tariffa assegnata.', 'Rate assigned.');
String get kRateChanged => tr('Costo orario cambiato.', 'Hourly cost changed.');
String get kHoursSettled => tr('Ore saldate.', 'Hours settled.');
String get kHoursPaidAhead => tr('Ore pagate in anticipo.', 'Hours paid in advance.');
String get kFeeSettled => tr('Quota saldata.', 'Fee settled.');
String get kPaymentCancelled => tr('Pagamento revocato.', 'Payment revoked.');

String get kRequiredField => tr('Campo obbligatorio', 'Required field');
String get kInvalidAmountMessage => tr('Importo non valido', 'Invalid amount');
String get kInvalidNumber => tr('Numero non valido', 'Invalid number');
String get kInvalidDate => tr('Data non valida', 'Invalid date');
String get kEndBeforeStart => tr('Prima del giorno di inizio', 'Before the start day');
String get kDayTooEarly =>
    tr('Il giorno è prima dell’inizio della tariffa attuale.', 'The day is before the current rate started.');
String get kDayInFuture => tr('Il giorno è nel futuro.', 'The day is in the future.');
String get kDayTooFar => tr('Il giorno è troppo lontano.', 'The day is too far away.');
