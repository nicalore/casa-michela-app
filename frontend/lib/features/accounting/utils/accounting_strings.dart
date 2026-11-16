import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart'
    show kHourlyColumn, kInsuranceFee, kMembershipFee, kMonthlyColumn, kPackageColumn, kWeekendColumn;
import '../models/teacher_hours_items.dart';
import '../models/volunteering_rule.dart';

const String kAccountingTitle = 'Contabilità';
const String kDailySummaryGroup = 'Riepilogo giornaliero';
const String kMonthlySummaryGroup = 'Riepilogo mensile';
const String kTeachersEntry = 'Docenti';
const String kStudentsEntry = 'Studenti';

const String kWorkGroup = 'Lavoro';
const String kVolunteerGroup = 'Volontariato';
const String kPayGroup = 'Paga';
const String kTeacherColumn = 'Docente';
const String kStartColumn = 'Inizio';
const String kEndColumn = 'Fine';
const String kHoursColumn = 'Ore';
const String kGrossColumn = 'Lorda';
const String kNetColumn = 'Netta';
const String kWithholdingColumn = 'Ritenuta';
const String kTotalRow = 'Totale';

const String kLiveStatus = 'IN CORSO';
const String kReadyStatus = 'DA CONFERMARE';
const String kConfirmedStatus = 'CONFERMATO';

const String kAbsentBadge = 'Assente';
const String kOnlineBadge = 'Online';

const String kConfirmHours = 'CONFERMA ORE';
const String kEditHours = 'MODIFICA ORE';
const String kAddTeacher = 'AGGIUNGI DOCENTE';

const String kAddStretch = 'Aggiungi orario';
const String kDropLastStretch = 'Togli l\'ultimo orario';
const String kMarkAbsent = 'Segna assente';
const String kMarkPresent = 'Segna presente';
const String kAlignToCalendar = 'Allinea al calendario';
const String kTakeOut = 'Togli dal riepilogo';

const String kNothingPlanned = 'Nessuna lezione pianificata';
const String kNothingOver = 'Nessuna lezione è ancora finita';

const String kAddTeacherTitle = 'Aggiungi docente';
const String kTeacherLabel = 'Docente';
const String kTeacherHint = 'Cerca docente...';
const String kAlreadyInSummary = 'Già nel riepilogo';
const String kModeLabel = 'Modalità';
const String kNoneLabel = 'Nessuno';
const String kAddStretchButton = 'AGGIUNGI ORARIO';
const String kAddButton = 'AGGIUNGI';

const String kChooseTeacher = 'Scegli il docente.';
const String kNoWork = 'Indica almeno un orario di lavoro.';
const String kNoRoomForStretch = 'Non c\'è più spazio per un altro orario in questa fascia.';

String teachersCount(int count) => count == 1 ? '1 docente' : '$count docenti';

String firstEndsAt(int minutes) => 'La prima finisce alle ${clockOf(minutes)}.';

String confirmFrom(int minutes) => 'Si potrà confermare dalle ${clockOf(minutes)}, quando finirà l\'ultima lezione.';

// "Mancano ancora Anna Verdi e Marco Bianchi: l'ultima lezione finisce alle 18:30."
String stillToCome(List<String> names, int lastEnd)
{
  final String joined = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';

  return 'Mancano ancora $joined: l\'ultima lezione finisce alle ${clockOf(lastEnd)}.';
}

// The monthly summary.
const String kDaysGroup = 'Giorni';
const String kHoursGroup = 'Ore';
const String kAvailabilityGroup = 'Disponibilità';
const String kRuleColumn = 'Un\'ora di volontariato';
const String kTotalColumn = 'Totale';
const String kPresenceColumn = 'In presenza';
const String kOnlineColumn = 'Online';
const String kVolunteerColumn = 'Volontariato';
const String kPaidColumn = 'Pagate';
const String kMonthColumn = 'Al mese';
const String kWeekColumn = 'A settimana';
const String kWeeklyRule = 'A settimana';
const String kDailyRule = 'Al giorno';
const String kNoRule = 'Nessuna';

const Map<VolunteeringRule, String> kMonthRuleNames = {
  VolunteeringRule.weekly: kWeeklyRule,
  VolunteeringRule.daily: kDailyRule,
  VolunteeringRule.none: kNoRule,
};

const Map<VolunteeringRule, String> _standingRuleNames = {
  VolunteeringRule.weekly: "un'ora a settimana",
  VolunteeringRule.daily: "un'ora al giorno",
  VolunteeringRule.none: 'nessun volontariato',
};

// On a rule chosen for the month alone: what the teacher's Compensi say instead.
String monthOnlyRuleTooltip(DateTime month, VolunteeringRule standing) =>
    'Solo per ${formatMonthName(month)}. Nei Compensi: ${_standingRuleNames[standing]}.';
const String kConfirmRule = 'Conferma modifica';
const String kMonthFinished = 'MESE TERMINATO';
const String kNoConfirmedHours = 'Nessuna ora confermata';
const String kStillToConfirm = 'Ancora da confermare: ';

String availabilityShort(int given) => '$given\u00a0su\u00a09';

String shortWeeks(int count) => count == 1 ? '1\u00a0settimana' : '$count\u00a0settimane';

String andOthers(int count) => 'e altre $count';

// The PDF exports.
const String kExportPdf = 'ESPORTA PDF';
const String kPdfFailed = 'Non è stato possibile creare il PDF.';
const String kPdfDownloaded = 'Il browser ha bloccato la scheda: il PDF è stato scaricato.';
const String kSignatureColumn = 'Firma del docente';
const String kCompensationPdfName = 'Compensi';

String pdfDayOnItsOwn(DateTime day) => '${formatWeekdayColumnLabel(day)} ${day.year}';

String _inSentence(String said) => '${said[0].toLowerCase()}${said.substring(1)}';

String _monthInSentence(DateTime month) => formatMonthYear(month).toLowerCase();

String exportedAt(DateTime moment)
{
  return 'Esportato ${_inSentence(pdfDayOnItsOwn(moment))} alle ${clockOf(moment.hour * 60 + moment.minute)}';
}

String dailyPdfTitle(DateTime day) => 'Riepilogo di ${_inSentence(pdfDayOnItsOwn(day))}';

String dailyPdfFooter(DateTime day) => '$kDailySummaryGroup · $kTeachersEntry · ${pdfDayOnItsOwn(day)}';

String dailyPdfTab(DateTime day) => '$kDailySummaryGroup · ${pdfDayOnItsOwn(day)}';

String dailyPdfFile(DateTime day) => 'Riepilogo giornaliero docenti ${formatDayMonthFull(day)} ${day.year}.pdf';

String monthlyPdfTitle(DateTime month) => 'Riepilogo di ${_monthInSentence(month)}';

String monthlyPdfFooter(DateTime month) => '$kMonthlySummaryGroup · $kTeachersEntry · ${formatMonthYear(month)}';

String monthlyPdfTab(DateTime month) => '$kMonthlySummaryGroup · ${formatMonthYear(month)}';

String monthlyPdfFile(DateTime month) => 'Riepilogo mensile docenti ${_monthInSentence(month)}.pdf';

String compensationPdfTitle(String name) => '$kCompensationPdfName di $name';

String compensationPdfFooter(String name, DateTime month) => '$kCompensationPdfName · $name · ${formatMonthYear(month)}';

String compensationPdfFile(String name, DateTime month) => '$kCompensationPdfName $name ${_monthInSentence(month)}.pdf';

// The bank transfer receipts of the monthly summary.
const String kReceiptColumn = 'Ricevuta';
const String kUploadReceipt = 'Carica la ricevuta del bonifico';
const String kOpenReceipt = 'Apri';
const String kReplaceReceipt = 'Sostituisci';
const String kDeleteReceipt = 'Elimina';
const String kDeleteReceiptQuestion = 'La ricevuta verrà eliminata.';
const String kReceiptUploaded = 'Ricevuta caricata.';
const String kReceiptReplaced = 'Ricevuta sostituita.';
const String kReceiptDeleted = 'Ricevuta eliminata.';
const String kReceiptDownloaded = 'Il browser ha bloccato la scheda: la ricevuta è stata scaricata.';
const String kReceiptWaiting = 'Apertura della ricevuta…';
const String kReceiptTooLarge = 'La ricevuta supera i 15 MB.';
const String kReceiptNotRead = 'Impossibile leggere il file.';

// Mirrored by the server's MAX_RECEIPT_BYTES.
const int kReceiptMaxBytes = 15 * 1024 * 1024;

const List<String> kReceiptExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

String receiptUploadedOn(DateTime when)
{
  final String day = formatWeekdayColumnLabel(when);

  return 'Caricata ${day[0].toLowerCase()}${day.substring(1)}';
}

// "6 su 8": receipts in, of the teachers paid that month.
String receiptsCount(int done, int of) => '$done su $of';

String dropReceiptFor(String name) => 'Rilascia per caricare la ricevuta di $name';

// "Ricevuta · Giulia Rossi · Ottobre 2026": the tab it opens in.
String receiptTabTitle(String name, DateTime month) => 'Ricevuta · $name · ${formatMonthYear(month)}';

// The daily summary of pupils.
const String kStudentColumn = 'Studente';
const String kLessonsGroup = 'Lezioni';
const String kPaymentGroup = 'Pagamento';
const String kTariffColumn = 'Tariffa';
const String kSituationColumn = 'Situazione';

const String kAddStudent = 'AGGIUNGI STUDENTE';
const String kAddStudentTitle = 'Aggiungi studente';
const String kStudentLabel = 'Studente';
const String kStudentHint = 'Cerca studente...';
const String kTimesLabel = 'Orario';
const String kChooseStudent = 'Scegli lo studente.';
const String kNoTimes = 'Indica almeno un orario.';

// The fee of the month the summary speaks of: the band's, or the month's.
String monthPaidSituation(DateTime month) => 'Quota di ${formatMonthName(month)} pagata';
String monthUnpaidSituation(DateTime month) => 'Quota di ${formatMonthName(month)} non pagata';
const String kToSettleSituation = 'Da saldare';
const String kRenewalBadge = 'Rinnovo';
const String kAheadBadge = 'Anticipo';

String studentsCount(int count) => count == 1 ? '1 studente' : '$count studenti';

String dailyStudentsPdfFooter(DateTime day) => '$kDailySummaryGroup · $kStudentsEntry · ${pdfDayOnItsOwn(day)}';

String dailyStudentsPdfTab(DateTime day) => '$kDailySummaryGroup · $kStudentsEntry · ${pdfDayOnItsOwn(day)}';

String dailyStudentsPdfFile(DateTime day) => 'Riepilogo giornaliero studenti ${formatDayMonthFull(day)} ${day.year}.pdf';

// The monthly summary of pupils.
const String kSituationNow = 'Situazione attuale';
const String kNothingToSettle = 'Nulla da saldare';

// "Situazione al 31 ottobre": the month is over, the situation stands at its last day.
// The day keeps its month on its line.
String situationAt(DateTime day) =>
    'Situazione ${toDayInSentence(day).replaceFirst(' ${formatMonthName(day)}', '\u00a0${formatMonthName(day)}')}';

// "Da saldare € 78,00".
String toSettleAmount(int cents) => '$kToSettleSituation ${formatAmount(cents)}';

// Beside one of a month's tariffs: "fino all'11", "dal 12", "dall'1 dicembre" past the month.
String tariffSpan(DateTime month, DateTime? starts, DateTime? ends)
{
  bool inMonth(DateTime day) => day.year == month.year && day.month == month.month;

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

String monthlyStudentsPdfFooter(DateTime month) => '$kMonthlySummaryGroup · $kStudentsEntry · ${formatMonthYear(month)}';

String monthlyStudentsPdfTab(DateTime month) => '$kMonthlySummaryGroup · $kStudentsEntry · ${formatMonthYear(month)}';

String monthlyStudentsPdfFile(DateTime month) => 'Riepilogo mensile studenti ${_monthInSentence(month)}.pdf';

// Every payment of a month, from anyone.
const String kPaymentsEntry = 'Pagamenti';
const String kRoleFilterPrefix = 'Ruolo';
const String kAllRolesHint = 'Tutti i ruoli';
const String kPaymentDayColumn = 'Giorno';
const String kPaymentWhatColumn = 'Pagamento';
const String kPaymentMethodColumn = 'Modalità';
const String kNoPaymentsInMonth = 'Nessun pagamento nel mese';
const String kNoPaymentsFiltered = 'Nessun pagamento con questi filtri';
const String kTariffFilterPrefix = 'Tariffa';
const String kAllTariffsHint = 'Tutte le tariffe';
const String kAmountFilterPrefix = 'Importo';
const String kAmountFilterTitle = 'Filtra per importo';
const String kLeastAmountLabel = 'Minimo';
const String kMostAmountLabel = 'Massimo';
const String kLeastAmountHint = 'Es. 20,00';
const String kMostAmountHint = 'Es. 200,00';

// The amount filter's window, worded as the other filter windows.
const String kFilterEyebrow = 'Filtro';
const String kResetFilterLabel = 'AZZERA';
const String kApplyFilterLabel = 'APPLICA';

// Refusals of «APPLICA».
const String kLeastAmountInvalid = 'Il minimo non è un importo valido.';
const String kMostAmountInvalid = 'Il massimo non è un importo valido.';
const String kAmountRangeReversed = 'Il minimo supera il massimo.';

// The roles a payment can be filtered by, as the server names them.
const Map<String, String> kPaymentRoleFilters = {
  'STUDENTE': 'Studenti',
  'DOCENTE': 'Docenti',
  'CORSISTA': 'Corsisti',
  'GENITORE': 'Genitori',
  'AMMINISTRATORE': 'Amministratori',
  'PSICOLOGO': 'Psicologi',
};

// The tariffs a payment can be filtered by, as the Tariffe tab lists them.
const Map<String, String> kPaymentTariffFilters = {
  'HOURLY': kHourlyColumn,
  'PACKAGE': kPackageColumn,
  'MONTHLY': kMonthlyColumn,
  'WEEKEND_ONLINE': kWeekendColumn,
  'MEMBERSHIP_FEE': kMembershipFee,
  'INSURANCE_FEE': kInsuranceFee,
};

String paymentsCount(int count) => count == 1 ? '1 pagamento' : '$count pagamenti';

String monthlyPaymentsPdfFooter(DateTime month) => '$kMonthlySummaryGroup · $kPaymentsEntry · ${formatMonthYear(month)}';

String monthlyPaymentsPdfTab(DateTime month) => '$kMonthlySummaryGroup · $kPaymentsEntry · ${formatMonthYear(month)}';

String monthlyPaymentsPdfFile(DateTime month) => 'Riepilogo mensile pagamenti ${_monthInSentence(month)}.pdf';

// «da € 20,00», «fino a € 200,00», «€ 20,00 – € 200,00»; null with no bound.
String? amountRange(int? least, int? most) => switch ((least, most))
{
  (final int from, final int to) => '${formatAmount(from)} – ${formatAmount(to)}',
  (final int from, null) => 'da ${formatAmount(from)}',
  (null, final int to) => 'fino a ${formatAmount(to)}',
  _ => null,
};

// Whoever owes something today.
const String kToSettleEntry = 'Da saldare';
const String kDebtorColumn = 'Persona';
const String kOwedColumn = 'Da saldare';
const String kSinceColumn = 'Dal';
const String kOwedAmountColumn = 'Importo';
const String kNotEnrolledNow = 'Nessuna iscrizione in corso';
const String kNothingOwed = 'Nessuno ha qualcosa da saldare';
const String kNoDebtorsFiltered = 'Nessuna persona con questi filtri';

String debtorsCount(int count) => count == 1 ? '1 persona' : '$count persone';

const String kOwedInAll = 'Totale';

// "3 novembre", with the year when it is not this one.
String owedSince(DateTime day, int thisYear) =>
    day.year == thisYear ? formatDayMonthFull(day) : '${formatDayMonthFull(day)} ${day.year}';

// The statistics.
const String kStatisticsEntry = 'Statistiche';
const String kPeriodPrefix = 'Periodo';
const String kThisMonthPeriod = 'Questo mese';

String lastMonthsPeriod(int months) => 'Ultimi $months mesi';

String yearPeriod(int year) => 'Anno $year';

const String kFlowsTitle = 'Entrate e uscite';
const String kIncomeInPeriod = 'Incassi nel periodo';
const String kGrossInPeriod = 'Compensi lordi nel periodo';
const String kBalanceInPeriod = 'Saldo del periodo';
const String kFlowsChart = 'Incassi e compensi lordi per mese';
const String kIncomeSeries = 'Incassi';
const String kGrossSeries = 'Compensi lordi';
const String kBalanceSeries = 'Saldo';
const String kBalanceChart = 'Saldo per mese';

const String kPerHourTitle = 'Costo e ricavo per ora';
const String kIncomePerHour = 'Incasso per ora di lezione';
const String kPayPerHour = 'Compenso lordo per ora di lezione';

const String kPayTitle = 'Compensi ai docenti';
const String kGrossFigure = 'Lordo nel periodo';
const String kNetFigure = 'Netto nel periodo';
const String kWithheldFigure = 'Ritenute nel periodo';
const List<String> kPayViews = ['Lordo', 'Netto', 'Ritenute'];
const List<String> kPayCharts = ['Compensi lordi per mese', 'Compensi netti per mese', 'Ritenute per mese'];

const String kIncomeTitle = 'Incassi dagli studenti';
const String kCollectedFigure = 'Incassato nel periodo';
const String kMonthlyMeanFigure = 'Media al mese';
const String kPayersFigure = 'Studenti che hanno pagato';
const String kIncomeChart = 'Incassi per mese';

const String kKindsTitle = 'Incassi per tipo';
const String kKindsChart = 'Incassi per mese, per tipo';

const Map<String, String> kIncomeKindLabels = {
  'PACKAGE': 'Pacchetti',
  'MONTH': 'Quote mensili',
  'HOURLY': 'Pagamenti a ore',
  'AHEAD': 'Ore in anticipo',
  'WEEKEND_ONLINE': 'Online nel weekend',
  'FEES': 'Iscrizione e assicurazione',
};

const String kVolunteerTitle = 'Volontariato';
const String kVolunteerHoursFigure = 'Ore di volontariato';
const String kVolunteerValueFigure = 'Valore al compenso orario';
const String kVolunteersFigure = 'Docenti';
const String kVolunteerChart = 'Ore di volontariato per mese';
