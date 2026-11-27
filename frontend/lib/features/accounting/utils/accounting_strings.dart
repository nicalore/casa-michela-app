import '../../../core/language/app_language.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart'
    show kHourlyColumn, kInsuranceFee, kMembershipFee, kMonthlyColumn, kPackageColumn, kWeekendColumn;
import '../models/teacher_hours_items.dart';
import '../models/volunteering_rule.dart';

String get kAccountingTitle => tr('Contabilità', 'Accounting');
String get kDailySummaryGroup => tr('Riepilogo giornaliero', 'Daily summary');
String get kMonthlySummaryGroup => tr('Riepilogo mensile', 'Monthly summary');
String get kTeachersEntry => tr('Docenti', 'Teachers');
String get kStudentsEntry => tr('Studenti', 'Students');

String get kWorkGroup => tr('Lavoro', 'Work');
String get kVolunteerGroup => tr('Volontariato', 'Volunteering');
String get kPayGroup => tr('Paga', 'Pay');
String get kTeacherColumn => tr('Docente', 'Teacher');
String get kStartColumn => tr('Inizio', 'Start');
String get kEndColumn => tr('Fine', 'End');
String get kHoursColumn => tr('Ore', 'Hours');
String get kGrossColumn => tr('Lorda', 'Gross');
String get kNetColumn => tr('Netta', 'Net');
String get kWithholdingColumn => tr('Ritenuta', 'Withholding tax');
String get kTotalRow => tr('Totale', 'Total');

String get kLiveStatus => tr('IN CORSO', 'IN PROGRESS');
String get kReadyStatus => tr('DA CONFERMARE', 'TO CONFIRM');
String get kConfirmedStatus => tr('CONFERMATO', 'CONFIRMED');

String get kAbsentBadge => tr('Assente', 'Absent');
const String kOnlineBadge = 'Online';

String get kConfirmHours => tr('CONFERMA ORE', 'CONFIRM HOURS');
String get kEditHours => tr('MODIFICA ORE', 'EDIT HOURS');
String get kAddTeacher => tr('AGGIUNGI DOCENTE', 'ADD TEACHER');

String get kAddStretch => tr('Aggiungi orario', 'Add a time');
String get kDropLastStretch => tr('Togli l\'ultimo orario', 'Remove the last time');
String get kMarkAbsent => tr('Segna assente', 'Mark absent');
String get kMarkPresent => tr('Segna presente', 'Mark present');
String get kAlignToCalendar => tr('Allinea al calendario', 'Align with the calendar');
String get kTakeOut => tr('Togli dal riepilogo', 'Remove from the summary');

String get kNothingPlanned => tr('Nessuna lezione pianificata', 'No lessons planned');
String get kNoTeacherFinished => tr('Nessun docente ha ancora finito', 'No teacher has finished yet');
String get kNoStudentFinished => tr('Nessuno studente ha ancora finito', 'No student has finished yet');

String get kAddTeacherTitle => tr('Aggiungi docente', 'Add teacher');
String get kTeacherLabel => tr('Docente', 'Teacher');
String get kTeacherHint => tr('Cerca docente...', 'Search for a teacher...');
String get kAlreadyInSummary => tr('Già nel riepilogo', 'Already in the summary');
String get kModeLabel => tr('Modalità', 'Mode');
String get kNoneLabel => tr('Nessuno', 'None');
String get kAddStretchButton => tr('AGGIUNGI ORARIO', 'ADD A TIME');
String get kAddButton => tr('AGGIUNGI', 'ADD');

String get kChooseTeacher => tr('Scegli il docente.', 'Choose the teacher.');
String get kNoWork => tr('Indica almeno un orario di lavoro.', 'Enter at least one working time.');
String get kNoRoomForStretch => tr(
  'Non c\'è più spazio per un altro orario in questa fascia.',
  'There is no room left for another time in this time slot.',
);

String teachersCount(int count) => count == 1 ? tr('1 docente', '1 teacher') : tr('$count docenti', '$count teachers');

String firstFinishesAt(int minutes) => tr('Il primo finisce alle ${clockOf(minutes)}.', 'The first one finishes at ${clockOf(minutes)}.');

String confirmFrom(int minutes) => tr(
  'Si potrà confermare dalle ${clockOf(minutes)}, quando finirà l\'ultima lezione.',
  'It can be confirmed from ${clockOf(minutes)}, when the last lesson ends.',
);

// "Mancano ancora Anna Verdi e Marco Bianchi: l'ultima lezione finisce alle 18:30."
String stillToCome(List<String> names, int lastEnd)
{
  final String and = tr('e', 'and');
  final String joined = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} $and ${names.last}';

  final String verb = names.length == 1 ? 'Manca' : 'Mancano';

  return tr(
    '$verb ancora $joined: l\'ultima lezione finisce alle ${clockOf(lastEnd)}.',
    'Still waiting for $joined: the last lesson ends at ${clockOf(lastEnd)}.',
  );
}

// The monthly summary.
String get kDaysGroup => tr('Giorni', 'Days');
String get kHoursGroup => tr('Ore', 'Hours');
String get kAvailabilityGroup => tr('Disponibilità', 'Availability');
String get kRuleColumn => tr('Un\'ora di volontariato', 'One volunteering hour');
String get kTotalColumn => tr('Totale', 'Total');
String get kPresenceColumn => tr('In presenza', 'In person');
const String kOnlineColumn = 'Online';
String get kVolunteerColumn => tr('Volontariato', 'Volunteering');
String get kPaidColumn => tr('Pagate', 'Paid');
String get kMonthColumn => tr('Al mese', 'Per month');
String get kWeekColumn => tr('A settimana', 'Per week');
String get kWeeklyRule => tr('A settimana', 'Per week');
String get kDailyRule => tr('Al giorno', 'Per day');
String get kNoRule => tr('Nessuna', 'None');

Map<VolunteeringRule, String> get kMonthRuleNames => {
  VolunteeringRule.weekly: kWeeklyRule,
  VolunteeringRule.daily: kDailyRule,
  VolunteeringRule.none: kNoRule,
};

Map<VolunteeringRule, String> get _standingRuleNames => {
  VolunteeringRule.weekly: tr("un'ora a settimana", 'one hour a week'),
  VolunteeringRule.daily: tr("un'ora al giorno", 'one hour a day'),
  VolunteeringRule.none: tr('nessun volontariato', 'no volunteering'),
};

// On a rule chosen for the month alone: what the teacher's Compensi say instead.
String monthOnlyRuleTooltip(DateTime month, VolunteeringRule standing) => tr(
  'Solo per ${formatMonthName(month)}. Nei Compensi: ${_standingRuleNames[standing]}.',
  'Only for ${formatMonthName(month)}. Under Pay: ${_standingRuleNames[standing]}.',
);
String get kConfirmRule => tr('Conferma modifica', 'Confirm change');
String get kMonthFinished => tr('MESE TERMINATO', 'MONTH CLOSED');
String get kNoConfirmedHours => tr('Nessuna ora confermata', 'No confirmed hours');
String get kStillToConfirm => tr('Ancora da confermare: ', 'Still to confirm: ');

String availabilityShort(int given) => tr('$given su 9', '$given of 9');

String shortWeeks(int count) => count == 1
    ? tr('1 settimana', '1 week')
    : tr('$count settimane', '$count weeks');

String andOthers(int count) => tr('e altre $count', 'and $count more');

// The PDF exports.
String get kExportPdf => tr('ESPORTA PDF', 'EXPORT PDF');
String get kPdfFailed => tr('Non è stato possibile creare il PDF.', 'The PDF could not be created.');
String get kPdfDownloaded => tr(
  'Il browser ha bloccato la scheda: il PDF è stato scaricato.',
  'The browser blocked the tab: the PDF was downloaded.',
);
String get kSignatureColumn => tr('Firma del docente', 'Teacher\'s signature');
String get kCompensationPdfName => tr('Compensi', 'Pay');

String pdfDayOnItsOwn(DateTime day) => '${formatWeekdayColumnLabel(day)} ${day.year}';

// English keeps the capitals of weekdays and months.
String _inSentence(String said) => isEnglish ? said : '${said[0].toLowerCase()}${said.substring(1)}';

String _monthInSentence(DateTime month) => isEnglish ? formatMonthYear(month) : formatMonthYear(month).toLowerCase();

String exportedAt(DateTime moment)
{
  final String clock = clockOf(moment.hour * 60 + moment.minute);

  return tr(
    'Esportato ${_inSentence(pdfDayOnItsOwn(moment))} alle $clock',
    'Exported on ${_inSentence(pdfDayOnItsOwn(moment))} at $clock',
  );
}

String dailyPdfTitle(DateTime day) => tr(
  'Riepilogo di ${_inSentence(pdfDayOnItsOwn(day))}',
  'Summary of ${_inSentence(pdfDayOnItsOwn(day))}',
);

String dailyPdfFooter(DateTime day) => '$kDailySummaryGroup – $kTeachersEntry – ${pdfDayOnItsOwn(day)}';

String dailyPdfTab(DateTime day) => '$kDailySummaryGroup – ${pdfDayOnItsOwn(day)}';

String dailyPdfFile(DateTime day) => tr(
  'Riepilogo giornaliero docenti ${formatDayMonthFull(day)} ${day.year}.pdf',
  'Teachers daily summary ${formatDayMonthFull(day)} ${day.year}.pdf',
);

String monthlyPdfTitle(DateTime month) => tr(
  'Riepilogo di ${_monthInSentence(month)}',
  'Summary of ${_monthInSentence(month)}',
);

String monthlyPdfFooter(DateTime month) => '$kMonthlySummaryGroup – $kTeachersEntry – ${formatMonthYear(month)}';

String monthlyPdfTab(DateTime month) => '$kMonthlySummaryGroup – ${formatMonthYear(month)}';

String monthlyPdfFile(DateTime month) => tr(
  'Riepilogo mensile docenti ${_monthInSentence(month)}.pdf',
  'Teachers monthly summary ${_monthInSentence(month)}.pdf',
);

String compensationPdfTitle(String name) => tr('$kCompensationPdfName di $name', '$kCompensationPdfName for $name');

String compensationPdfFooter(String name, DateTime month) => '$kCompensationPdfName – $name – ${formatMonthYear(month)}';

String compensationPdfFile(String name, DateTime month) => '$kCompensationPdfName $name ${_monthInSentence(month)}.pdf';

// The bank transfer receipts of the monthly summary.
String get kReceiptColumn => tr('Ricevuta', 'Receipt');
String get kUploadReceipt => tr('Carica la ricevuta del bonifico', 'Upload the bank transfer receipt');
String get kOpenReceipt => tr('Apri', 'Open');
String get kReplaceReceipt => tr('Sostituisci', 'Replace');
String get kDeleteReceipt => tr('Elimina', 'Delete');
String get kDeleteReceiptQuestion => tr('La ricevuta verrà eliminata.', 'The receipt will be deleted.');
String get kReceiptUploaded => tr('Ricevuta caricata.', 'Receipt uploaded.');
String get kReceiptReplaced => tr('Ricevuta sostituita.', 'Receipt replaced.');
String get kReceiptDeleted => tr('Ricevuta eliminata.', 'Receipt deleted.');
String get kReceiptDownloaded => tr(
  'Il browser ha bloccato la scheda: la ricevuta è stata scaricata.',
  'The browser blocked the tab: the receipt was downloaded.',
);
String get kReceiptWaiting => tr('Apertura della ricevuta…', 'Opening the receipt…');
String get kReceiptTooLarge => tr('La ricevuta supera i 15 MB.', 'The receipt is larger than 15 MB.');
String get kReceiptNotRead => tr('Impossibile leggere il file.', 'The file could not be read.');

// Mirrored by the server's MAX_RECEIPT_BYTES.
const int kReceiptMaxBytes = 15 * 1024 * 1024;

const List<String> kReceiptExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

String receiptUploadedOn(DateTime when)
{
  final String day = _inSentence(formatWeekdayColumnLabel(when));

  return tr('Caricata $day', 'Uploaded on $day');
}

// "6 su 8": receipts in, of the teachers paid that month.
String receiptsCount(int done, int of) => tr('$done su $of', '$done of $of');

String dropReceiptFor(String name) => tr('Rilascia per caricare la ricevuta di $name', 'Drop to upload $name\'s receipt');

// "Ricevuta - Giulia Rossi - Ottobre 2026" (en dashes): the tab it opens in.
String receiptTabTitle(String name, DateTime month) => '$kReceiptColumn – $name – ${formatMonthYear(month)}';

// The daily summary of pupils.
String get kStudentColumn => tr('Studente', 'Student');
String get kLessonsGroup => tr('Lezioni', 'Lessons');
String get kPaymentGroup => tr('Pagamento', 'Payment');
String get kTariffColumn => tr('Tariffa', 'Rate');
String get kSituationColumn => tr('Situazione', 'Status');

String get kAddStudent => tr('AGGIUNGI STUDENTE', 'ADD STUDENT');
String get kAddStudentTitle => tr('Aggiungi studente', 'Add student');
String get kStudentLabel => tr('Studente', 'Student');
String get kStudentHint => tr('Cerca studente...', 'Search for a student...');
String get kTimesLabel => tr('Orario', 'Times');
String get kChooseStudent => tr('Scegli lo studente.', 'Choose the student.');
String get kNoTimes => tr('Indica almeno un orario.', 'Enter at least one time.');

// The fee of the month the summary speaks of: the band's, or the month's.
String monthPaidSituation(DateTime month) => tr(
  'Quota di ${formatMonthName(month)} pagata',
  '${formatMonthName(month)} fee paid',
);
String monthUnpaidSituation(DateTime month) => tr(
  'Quota di ${formatMonthName(month)} non pagata',
  '${formatMonthName(month)} fee not paid',
);
String get kToSettleSituation => tr('Da pagare', 'Due');
String get kPaidSituation => tr('Pagata', 'Paid');
String get kRenewalBadge => tr('Rinnovo', 'Renewal');
String get kAheadBadge => tr('Anticipo', 'Advance');

String studentsCount(int count) => count == 1 ? tr('1 studente', '1 student') : tr('$count studenti', '$count students');

String dailyStudentsPdfFooter(DateTime day) => '$kDailySummaryGroup – $kStudentsEntry – ${pdfDayOnItsOwn(day)}';

String dailyStudentsPdfTab(DateTime day) => '$kDailySummaryGroup – $kStudentsEntry – ${pdfDayOnItsOwn(day)}';

String dailyStudentsPdfFile(DateTime day) => tr(
  'Riepilogo giornaliero studenti ${formatDayMonthFull(day)} ${day.year}.pdf',
  'Students daily summary ${formatDayMonthFull(day)} ${day.year}.pdf',
);

// The monthly summary of pupils.
String get kSituationNow => tr('Situazione attuale', 'Current status');
String get kNothingToSettle => tr('Nulla da pagare', 'Nothing due');

// "Situazione al 31 ottobre": the month is over, the situation stands at its last day.
// The day keeps its month on its line.
String situationAt(DateTime day)
{
  if (isEnglish)
  {
    return 'Status at ${day.day} ${formatMonthName(day)}';
  }

  return 'Situazione ${toDayInSentence(day).replaceFirst(' ${formatMonthName(day)}', ' ${formatMonthName(day)}')}';
}

// "Da pagare € 78,00".
String toSettleAmount(int cents) => '$kToSettleSituation ${formatAmount(cents)}';

// Beside one of a month's tariffs: "fino all'11", "dal 12", "dall'1 dicembre" past the month.
String tariffSpan(DateTime month, DateTime? starts, DateTime? ends)
{
  bool inMonth(DateTime day) => day.year == month.year && day.month == month.month;

  if (isEnglish)
  {
    // "until 11", "from 12", "from 1 December", "from 12 to 20".
    final String? from = starts == null
        ? null
        : 'from ${inMonth(starts) ? '${starts.day}' : formatDayMonthFull(starts)}';
    final String? to = ends == null ? null : (inMonth(ends) ? '${ends.day}' : formatDayMonthFull(ends));

    if (from != null)
    {
      return to == null ? from : '$from to $to';
    }

    return to == null ? '' : 'until $to';
  }

  final String? from = starts == null
      ? null
      : (inMonth(starts) ? fromDayNumberInSentence(starts.day) : fromDayInSentence(starts));
  final String? to = ends == null
      ? null
      : (inMonth(ends) ? toDayNumberInSentence(ends.day) : toDayInSentence(ends));

  if (from != null)
  {
    return to == null ? from : '$from $to';
  }

  return to == null ? '' : 'fino $to';
}

String monthlyStudentsPdfFooter(DateTime month) => '$kMonthlySummaryGroup – $kStudentsEntry – ${formatMonthYear(month)}';

String monthlyStudentsPdfTab(DateTime month) => '$kMonthlySummaryGroup – $kStudentsEntry – ${formatMonthYear(month)}';

String monthlyStudentsPdfFile(DateTime month) => tr(
  'Riepilogo mensile studenti ${_monthInSentence(month)}.pdf',
  'Students monthly summary ${_monthInSentence(month)}.pdf',
);

// Every payment of a month, from anyone.
String get kPaymentsEntry => tr('Pagamenti', 'Payments');
String get kRoleFilterPrefix => tr('Ruolo', 'Role');
String get kAllRolesHint => tr('Tutti i ruoli', 'All roles');
String get kPersonHint => tr('Cerca persona...', 'Search person...');
String get kPaymentDayColumn => tr('Giorno', 'Day');
String get kPaymentWhatColumn => tr('Pagamento', 'Payment');
String get kPaymentMethodColumn => tr('Modalità', 'Method');
String get kNoPaymentsInMonth => tr('Nessun pagamento nel mese', 'No payments this month');
String get kNoPaymentsFiltered => tr('Nessun pagamento con questi filtri', 'No payments with these filters');
String get kTariffFilterPrefix => tr('Tariffa', 'Rate');
String get kAllTariffsHint => tr('Tutte le tariffe', 'All rates');
String get kAmountFilterPrefix => tr('Importo', 'Amount');
String get kAmountFilterTitle => tr('Filtra per importo', 'Filter by amount');
String get kLeastAmountLabel => tr('Minimo', 'Minimum');
String get kMostAmountLabel => tr('Massimo', 'Maximum');
String get kLeastAmountHint => tr('Es. 20,00', 'E.g. 20.00');
String get kMostAmountHint => tr('Es. 200,00', 'E.g. 200.00');

// The amount filter's window, worded as the other filter windows.
String get kFilterEyebrow => tr('Filtro', 'Filter');
String get kResetFilterLabel => tr('AZZERA', 'RESET');
String get kApplyFilterLabel => tr('APPLICA', 'APPLY');

// Refusals of «APPLICA».
String get kLeastAmountInvalid => tr('Il minimo non è un importo valido.', 'The minimum is not a valid amount.');
String get kMostAmountInvalid => tr('Il massimo non è un importo valido.', 'The maximum is not a valid amount.');
String get kAmountRangeReversed => tr('Il minimo supera il massimo.', 'The minimum is greater than the maximum.');

// The roles a payment can be filtered by, as the server names them.
Map<String, String> get kPaymentRoleFilters => {
  'STUDENTE': tr('Studenti', 'Students'),
  'DOCENTE': tr('Docenti', 'Teachers'),
  'CORSISTA': tr('Corsisti', 'Course participants'),
  'GENITORE': tr('Genitori', 'Parents'),
  'AMMINISTRATORE': tr('Amministratori', 'Administrators'),
  'PSICOLOGO': tr('Psicologi', 'Psychologists'),
};

// The tariffs a payment can be filtered by, as the Tariffe tab lists them.
Map<String, String> get kPaymentTariffFilters => {
  'HOURLY': kHourlyColumn,
  'PACKAGE': kPackageColumn,
  'MONTHLY': kMonthlyColumn,
  'WEEKEND_ONLINE': kWeekendColumn,
  'MEMBERSHIP_FEE': kMembershipFee,
  'INSURANCE_FEE': kInsuranceFee,
};

String paymentsCount(int count) => count == 1 ? tr('1 pagamento', '1 payment') : tr('$count pagamenti', '$count payments');

String monthlyPaymentsPdfFooter(DateTime month) => '$kMonthlySummaryGroup – $kPaymentsEntry – ${formatMonthYear(month)}';

String monthlyPaymentsPdfTab(DateTime month) => '$kMonthlySummaryGroup – $kPaymentsEntry – ${formatMonthYear(month)}';

String monthlyPaymentsPdfFile(DateTime month) => tr(
  'Riepilogo mensile pagamenti ${_monthInSentence(month)}.pdf',
  'Payments monthly summary ${_monthInSentence(month)}.pdf',
);

// «da € 20,00», «fino a € 200,00», «€ 20,00 – € 200,00»; null with no bound.
String? amountRange(int? least, int? most) => switch ((least, most))
{
  (final int from, final int to) => '${formatAmount(from)} – ${formatAmount(to)}',
  (final int from, null) => tr('da ${formatAmount(from)}', 'from ${formatAmount(from)}'),
  (null, final int to) => tr('fino a ${formatAmount(to)}', 'up to ${formatAmount(to)}'),
  _ => null,
};

// Whoever owes something today.
String get kToSettleEntry => tr('Da saldare', 'Due');
String get kDebtorColumn => tr('Nome', 'Name');
String get kPeriodColumn => tr('Periodo', 'Period');
String get kOwedColumn => tr('Da saldare', 'Due');
String get kOwedAmountColumn => tr('Importo', 'Amount');
String get kNotEnrolledNow => tr('Nessuna iscrizione in corso', 'No current enrolment');
String get kNothingOwed => tr('Nessuno deve pagare', 'Nobody has to pay');
String get kNoDebtorsFiltered => tr('Nessuna persona con questi filtri', 'No people with these filters');

String debtorsCount(int count) => count == 1 ? tr('1 persona', '1 person') : tr('$count persone', '$count people');

String get kOwedInAll => tr('Totale', 'Total');

// The statistics.
String get kStatisticsEntry => tr('Statistiche', 'Statistics');
String get kPeriodPrefix => tr('Periodo', 'Period');
String get kThisMonthPeriod => tr('Questo mese', 'This month');

String lastMonthsPeriod(int months) => tr('Ultimi $months mesi', 'Last $months months');

String yearPeriod(int year) => tr('Anno $year', 'Year $year');

String get kFlowsTitle => tr('Entrate e uscite', 'Income and expenses');
String get kIncomeInPeriod => tr('Incassi nel periodo', 'Income in the period');
String get kGrossInPeriod => tr('Compensi lordi nel periodo', 'Gross pay in the period');
String get kBalanceInPeriod => tr('Saldo del periodo', 'Balance for the period');
String get kFlowsChart => tr('Incassi e compensi lordi per mese', 'Income and gross pay by month');
String get kIncomeSeries => tr('Incassi', 'Income');
String get kGrossSeries => tr('Compensi lordi', 'Gross pay');
String get kBalanceSeries => tr('Saldo', 'Balance');
String get kBalanceChart => tr('Saldo per mese', 'Balance by month');

String get kPerHourTitle => tr('Costo e ricavo per ora', 'Cost and revenue per hour');
String get kIncomePerHour => tr('Incasso per ora di studente', 'Income per student hour');
String get kPayPerHour => tr('Compenso lordo per ora di docente', 'Gross pay per teacher hour');
String get kPayPerHourInfo => tr(
  'Compensi lordi divisi per le ore pagate ai docenti nel periodo.',
  'Gross pay divided by the hours paid to teachers in the period.',
);
String get kCostPerHour => tr('Costo per ora di studente', 'Cost per student hour');
String get kCostPerHourInfo => tr(
  'Compensi lordi divisi per le ore di lezione fatte dagli studenti nel periodo.',
  'Gross pay divided by the lesson hours students had in the period.',
);

String get kPayersTitle => tr('10 studenti che hanno pagato di più', 'Top 10 paying students');

String get kFeesTitle => tr('Quote mensili', 'Monthly fees');
String get kFeesPaidFigure => tr('Quote incassate', 'Fees collected');
String get kFeesCostFigure => tr('Costo delle ore con quota mensile', 'Cost of monthly-fee hours');
String get kFeesMarginFigure => tr('Margine', 'Margin');
String get kFeesLosingFigure => tr('Studenti in perdita', 'Students at a loss');
String get kBreakEvenTitle => tr('Pareggio per quota', 'Break-even by fee');
String get kMarginChart => tr(
  'Margine per studente: quote pagate meno il costo delle ore',
  'Margin per student: fees paid minus the cost of the hours',
);
String get kNoFeePupils => tr(
  'Nessuno studente con quota mensile nel periodo.',
  'No students with a monthly fee in the period.',
);
String get kNoLessonCost => tr(
  'Mancano ore di lezione confermate nel periodo per calcolare il costo.',
  'There are no confirmed lesson hours in the period to work out the cost.',
);

String losingOf(int losing, int all) => tr('$losing su $all', '$losing of $all');

String breakEvenLabel(String fee, String level) => tr('In pari con $fee ($level)', 'Break-even at $fee ($level)');

String perMonth(String hours) => tr('$hours al mese', '$hours a month');

// The tooltip of a pupil's margin bar: a figure, then what it is.
String get kFeeRow => tr('Quota al mese', 'Fee per month');
String get kPaidMonthsRow => tr('Mesi pagati', 'Months paid');
String get kPaidMonthRow => tr('Mese pagato', 'Month paid');
String get kLessonHoursRow => tr('Ore di lezione', 'Lesson hours');
String get kHoursPerMonthRow => tr('Ore al mese', 'Hours per month');
String get kFeesPaidRow => tr('Quote pagate', 'Fees paid');
String get kHoursCostRow => tr('Costo delle ore', 'Cost of the hours');
String get kMarginRow => tr('Margine', 'Margin');
String get kEvenRow => tr('Pareggio al mese', 'Break-even per month');

String get kPayTitle => tr('Compensi ai docenti', 'Teachers\' pay');
String get kGrossFigure => tr('Lordo nel periodo', 'Gross in the period');
String get kNetFigure => tr('Netto nel periodo', 'Net in the period');
String get kWithheldFigure => tr('Ritenute nel periodo', 'Withholding tax in the period');
List<String> get kPayViews => [tr('Lordo', 'Gross'), tr('Netto', 'Net'), tr('Ritenute', 'Withholding tax')];
List<String> get kPayCharts => [
  tr('Compensi lordi per mese', 'Gross pay by month'),
  tr('Compensi netti per mese', 'Net pay by month'),
  tr('Ritenute per mese', 'Withholding tax by month'),
];

String get kIncomeTitle => tr('Incassi dagli studenti', 'Income from students');
String get kCollectedFigure => tr('Incassato nel periodo', 'Collected in the period');
String get kMonthlyMeanFigure => tr('Media al mese', 'Monthly average');
String get kPayersFigure => tr('Studenti che hanno pagato', 'Students who paid');
String get kIncomeChart => tr('Incassi per mese', 'Income by month');

String get kKindsTitle => tr('Incassi per tipo', 'Income by type');
String get kKindsChart => tr('Incassi per mese, per tipo', 'Income by month and type');

Map<String, String> get kIncomeKindLabels => {
  'PACKAGE': tr('Pacchetti', 'Packages'),
  'MONTH': tr('Quote mensili', 'Monthly fees'),
  'HOURLY': tr('Pagamenti a ore', 'Hourly payments'),
  'AHEAD': tr('Ore in anticipo', 'Hours in advance'),
  'WEEKEND_ONLINE': tr('Online nel weekend', 'Weekend online'),
  'FEES': tr('Iscrizione e assicurazione', 'Enrolment and insurance'),
};

String get kVolunteerTitle => tr('Volontariato', 'Volunteering');
String get kVolunteerHoursFigure => tr('Ore di volontariato', 'Volunteering hours');
String get kVolunteerValueFigure => tr('Valore al compenso orario', 'Value at the hourly pay');
String get kVolunteersFigure => tr('Docenti', 'Teachers');
String get kVolunteerChart => tr('Ore di volontariato per mese', 'Volunteering hours by month');
