import '../../../core/language/app_language.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../people/utils/payments_strings.dart' show hoursText;

// Contabilità › «Configurazione iniziale».

String get kOpeningGroup => tr('Configurazione iniziale', 'Initial setup');
String get kOpeningEyebrow => tr('Configurazione iniziale', 'Initial setup');

// "15 novembre".
String openingDay(DateTime day) => formatDayMonthFull(day);

// Bold pieces between plain ones, as the intro card writes them.
List<(String, bool)> teachersIntro(DateTime lastDay)
{
  return [
    (tr('Per ogni docente inserisci la ', 'For each teacher enter the '), false),
    (tr('paga oraria', 'hourly pay'), true),
    (tr(' e il ', ' and the '), false),
    (tr('compenso dall’1 al ${openingDay(lastDay)}', 'pay from 1 to ${openingDay(lastDay)}'), true),
    ('.', false),
  ];
}

List<(String, bool)> pupilsIntro(DateTime lastDay)
{
  return [
    (tr('Per ogni studente inserisci la ', 'For each student enter the '), false),
    (tr('tariffa in uso al ${openingDay(lastDay)}', 'rate in use on ${openingDay(lastDay)}'), true),
    (tr(' e la sua situazione a quel giorno.', ' and their status on that day.'), false),
  ];
}

String confirmedOf(int done, int all) => tr('$done di $all', '$done of $all');
String get kConfirmedWord => tr('confermati', 'confirmed');

String get kToSetUpChoice => tr('Da configurare', 'To set up');
String get kConfirmedChoice => tr('Confermati', 'Confirmed');

String get kSearchTeacherHint => tr('Cerca docente...', 'Search for a teacher...');
String get kSearchPupilHint => tr('Cerca studente...', 'Search for a student...');

String teachersToSetUp(int count) => count == 1
    ? tr('1 docente da configurare', '1 teacher to set up')
    : tr('$count docenti da configurare', '$count teachers to set up');
String teachersConfirmed(int count) => count == 1
    ? tr('1 docente confermato', '1 teacher confirmed')
    : tr('$count docenti confermati', '$count teachers confirmed');
String pupilsToSetUp(int count) => count == 1
    ? tr('1 studente da configurare', '1 student to set up')
    : tr('$count studenti da configurare', '$count students to set up');
String pupilsConfirmed(int count) => count == 1
    ? tr('1 studente confermato', '1 student confirmed')
    : tr('$count studenti confermati', '$count students confirmed');

String get kAllTeachersSetUp => tr('Tutti i docenti sono configurati', 'All teachers are set up');
String get kAllPupilsSetUp => tr('Tutti gli studenti sono configurati', 'All students are set up');
String get kNoTeacherConfirmed => tr('Ancora nessun docente confermato', 'No teacher confirmed yet');
String get kNoPupilConfirmed => tr('Ancora nessuno studente confermato', 'No student confirmed yet');
String get kNoTeacherFound => tr('Nessun docente trovato', 'No teacher found');
String get kNoPupilFound => tr('Nessuno studente trovato', 'No student found');

String get kPayMissing => tr('Paga da inserire', 'Pay to enter');
String get kTariffMissing => tr('Tariffa da inserire', 'Rate to enter');

// "Retribuito: 15,00 euro l'ora".
String paidTag(int cents, {required bool feminine}) => tr(
  '${feminine ? 'Retribuita' : 'Retribuito'}: ${formatAmount(cents)} l’ora',
  'Paid: ${formatAmount(cents)} an hour',
);

// "Pacchetto: 215,00 euro per 18 ore".
String tariffTag(String kind, int cents, int? hours)
{
  return switch (kind)
  {
    'HOURLY' => tr('A ore: ${formatAmount(cents)} l’ora', 'Hourly: ${formatAmount(cents)} an hour'),
    'PACKAGE' => tr(
      'Pacchetto: ${formatAmount(cents)} per ${hours == 1 ? '1 ora' : '$hours ore'}',
      'Hours package: ${formatAmount(cents)} for ${hours == 1 ? '1 hour' : '$hours hours'}',
    ),
    _ => tr('Quota mensile: ${formatAmount(cents)}', 'Monthly fee: ${formatAmount(cents)}'),
  };
}

String get kPayOnFile => tr('Paga già inserita', 'Pay already entered');
String get kTariffOnFile => tr('Tariffa già inserita', 'Rate already entered');

// «Retribuito – € 15,00 l’ora lordi».
String paidOnFile(int cents, {required bool feminine}) => tr(
  '${feminine ? 'Retribuita' : 'Retribuito'} – ${formatAmount(cents)} l’ora lordi',
  'Paid – ${formatAmount(cents)} an hour gross',
);

String get kCollaborationLabel => tr('Collaborazione', 'Collaboration');
String get kGrossRateLabel => tr('Compenso orario lordo', 'Gross hourly pay');
String get kNetRateLabel => tr('Compenso orario netto', 'Net hourly pay');
String get kGrossLabel => tr('Compenso lordo', 'Gross pay');
String get kNetLabel => tr('Compenso netto', 'Net pay');

// «Dall’1 al 15»: the day column of Compensi, before the days the app works out.
String openingRowLabel(DateTime lastDay) => tr('Dall’1 al ${lastDay.day}', 'From 1 to ${lastDay.day}');

// «Dall’1 al 15 novembre 2026».
String beforeAccounts(DateTime lastDay) => tr(
  'Dall’1 al ${openingDay(lastDay)} ${lastDay.year}',
  'From 1 to ${openingDay(lastDay)} ${lastDay.year}',
);

String teacherAfterNote(DateTime lastDay)
{
  final DateTime first = lastDay.add(const Duration(days: 1));

  return tr(
    'Il compenso di ${formatMonthName(lastDay)} sarà questa cifra a cui si aggiungono le ore confermate dal ${first.day} novembre.',
    '${formatMonthName(lastDay)} pay will be this figure plus the hours confirmed from ${formatDayMonthFull(first)}.',
  );
}

String get kNothingToPay => tr('Nessun compenso da inserire: basta confermare.', 'No pay to enter: just confirm.');

String tariffInUse(DateTime lastDay) => tr('Tariffa in uso al ${openingDay(lastDay)}', 'Rate in use on ${openingDay(lastDay)}');

// «Al 15 novembre 2026».
String atLastDay(DateTime lastDay) => tr(
  'Al ${openingDay(lastDay)} ${lastDay.year}',
  'As of ${openingDay(lastDay)} ${lastDay.year}',
);

String get kPackageState => tr('Situazione del pacchetto', 'Package status');
String get kHoursLeftChoice => tr('Ore rimaste', 'Hours left');
String get kPackageEndedChoice => tr('Pacchetto esaurito', 'Package used up');
String get kOverPackageLabel => tr('Ore oltre il pacchetto da pagare', 'Hours beyond the package due');

// «11h 30m usate su 18h».
String usedOf(int used, int hours) => tr(
  '${hoursText(used)} ${used > 0 && used < 60 ? 'usati' : 'usate'} su ${hours}h',
  '${hoursText(used)} used of ${hours}h',
);

String get kHoursState => tr('Situazione delle ore', 'Hours status');
String get kNoHoursChoice => tr('Nessuna', 'None');
String get kDueChoice => tr('Da pagare', 'Due');
String get kAheadChoice => tr('Pagate in anticipo', 'Paid in advance');
String get kAheadLeftLabel => tr('Ore pagate in anticipo rimaste', 'Hours paid in advance left');
String get kAheadRateLabel => tr('Costo orario pagato', 'Hourly cost paid');

// «€ 91,00 già pagati».
String alreadyPaid(int cents) => tr('${formatAmount(cents)} già pagati', '${formatAmount(cents)} already paid');

// «Da pagare € 42,00 (€ 14,00 l’ora)».
String toSettleAt(int cents, int centsPerHour) => tr(
  'Da pagare ${formatAmount(cents)} (${formatAmount(centsPerHour)} l’ora)',
  'Due ${formatAmount(cents)} (${formatAmount(centsPerHour)} an hour)',
);

String toSettle(int cents) => tr('Da pagare ${formatAmount(cents)}', 'Due ${formatAmount(cents)}');

String get kWeekendDueLabel => tr('Ore online nel weekend da pagare', 'Weekend online hours due');
String get kYesChoice => tr('Sì', 'Yes');
const String kNoChoice = 'No';

String get kConfirmLabel => tr('CONFERMA', 'CONFIRM');
String teacherConfirmed({required bool feminine}) =>
    tr(feminine ? 'Docente confermata.' : 'Docente confermato.', 'Teacher confirmed.');
String pupilConfirmed({required bool feminine}) =>
    tr(feminine ? 'Studentessa confermata.' : 'Studente confermato.', 'Student confirmed.');

String get kCloseOpeningLabel => tr('CHIUDI CONFIGURAZIONE', 'CLOSE SETUP');
String closeOpeningMessage(DateTime lastDay) => tr(
  'La configurazione iniziale si chiuderà per sempre e sparirà dal menu: i dati al ${openingDay(lastDay)} non si potranno più modificare.',
  'The initial setup will close for good and disappear from the menu: the data as of ${openingDay(lastDay)} can no longer be changed.',
);
String get kCloseLabel => tr('CHIUDI', 'CLOSE');
String get kOpeningClosed => tr('Configurazione iniziale chiusa.', 'Initial setup closed.');

// Where nobody is set up yet: Pagamenti, «Da saldare», the summaries.
String get kOpeningPending => tr('Da configurare', 'To set up');
String get kConfigureLabel => tr('CONFIGURA', 'SET UP');

String pendingPaymentsNote(DateTime lastDay) => tr(
  'La situazione al ${openingDay(lastDay)} non è ancora stata inserita: fino ad allora i pagamenti delle ore sono bloccati.',
  'The status as of ${openingDay(lastDay)} has not been entered yet: until then, payments for hours are blocked.',
);

String pendingReason({required bool feminine}) => tr(
  'Prima configura ${feminine ? 'la studentessa' : 'lo studente'} in Contabilità › Configurazione iniziale.',
  'First set up the student in Accounting › Initial setup.',
);

// The minutes the set-up carries, shown instead of a lesson's day.
String atDay(DateTime day) => tr('Al ${openingDay(day)}', 'As of ${openingDay(day)}');
