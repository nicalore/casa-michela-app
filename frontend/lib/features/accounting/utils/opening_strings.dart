import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../people/utils/payments_strings.dart' show hoursText;

// Contabilità › «Configurazione iniziale».

const String kOpeningGroup = 'Configurazione iniziale';
const String kOpeningEyebrow = 'Configurazione iniziale';

// "15 novembre".
String openingDay(DateTime day) => formatDayMonthFull(day);

// Bold pieces between plain ones, as the intro card writes them.
List<(String, bool)> teachersIntro(DateTime lastDay)
{
  return [
    ('Per ogni docente inserisci la ', false),
    ('paga oraria', true),
    (' e il ', false),
    ('compenso dall’1 al ${openingDay(lastDay)}', true),
    ('.', false),
  ];
}

List<(String, bool)> pupilsIntro(DateTime lastDay)
{
  return [
    ('Per ogni studente inserisci la ', false),
    ('tariffa in uso al ${openingDay(lastDay)}', true),
    (' e la sua situazione a quel giorno.', false),
  ];
}

String confirmedOf(int done, int all) => '$done di $all';
const String kConfirmedWord = 'confermati';

const String kToSetUpChoice = 'Da configurare';
const String kConfirmedChoice = 'Confermati';

const String kSearchTeacherHint = 'Cerca docente...';
const String kSearchPupilHint = 'Cerca studente...';

String teachersToSetUp(int count) => count == 1 ? '1 docente da configurare' : '$count docenti da configurare';
String teachersConfirmed(int count) => count == 1 ? '1 docente confermato' : '$count docenti confermati';
String pupilsToSetUp(int count) => count == 1 ? '1 studente da configurare' : '$count studenti da configurare';
String pupilsConfirmed(int count) => count == 1 ? '1 studente confermato' : '$count studenti confermati';

const String kAllTeachersSetUp = 'Tutti i docenti sono configurati';
const String kAllPupilsSetUp = 'Tutti gli studenti sono configurati';
const String kNoTeacherConfirmed = 'Ancora nessun docente confermato';
const String kNoPupilConfirmed = 'Ancora nessuno studente confermato';
const String kNoTeacherFound = 'Nessun docente trovato';
const String kNoPupilFound = 'Nessuno studente trovato';

const String kPayMissing = 'Paga da inserire';
const String kTariffMissing = 'Tariffa da inserire';

// «Retribuito · € 15,00 l’ora».
String paidTag(int cents) => 'Retribuito · ${formatAmount(cents)} l’ora';

// «Pacchetto · € 215,00 per 18 ore».
String tariffTag(String kind, int cents, int? hours)
{
  return switch (kind)
  {
    'HOURLY' => 'A ore · ${formatAmount(cents)} l’ora',
    'PACKAGE' => 'Pacchetto · ${formatAmount(cents)} per ${hours == 1 ? '1 ora' : '$hours ore'}',
    _ => 'Quota mensile · ${formatAmount(cents)}',
  };
}

const String kPayOnFile = 'Paga già inserita';
const String kTariffOnFile = 'Tariffa già inserita';

// «Retribuito – € 15,00 l’ora lordi».
String paidOnFile(int cents) => 'Retribuito – ${formatAmount(cents)} l’ora lordi';

const String kCollaborationLabel = 'Collaborazione';
const String kGrossRateLabel = 'Compenso orario lordo';
const String kNetRateLabel = 'Compenso orario netto';
const String kGrossLabel = 'Compenso lordo';
const String kNetLabel = 'Compenso netto';

// «Dall’1 al 15»: the day column of Compensi, before the days the app works out.
String openingRowLabel(DateTime lastDay) => 'Dall’1 al ${lastDay.day}';

// «Dall’1 al 15 novembre 2026».
String beforeAccounts(DateTime lastDay) => 'Dall’1 al ${openingDay(lastDay)} ${lastDay.year}';

String teacherAfterNote(DateTime lastDay)
{
  final DateTime first = lastDay.add(const Duration(days: 1));

  return 'Il compenso di ${formatMonthName(lastDay)} sarà questa cifra a cui si aggiungono le ore confermate dal ${first.day} novembre.';
}

const String kNothingToPay = 'Nessun compenso da inserire: basta confermare.';

String tariffInUse(DateTime lastDay) => 'Tariffa in uso al ${openingDay(lastDay)}';

// «Al 15 novembre 2026».
String atLastDay(DateTime lastDay) => 'Al ${openingDay(lastDay)} ${lastDay.year}';

const String kPackageState = 'Situazione del pacchetto';
const String kHoursLeftChoice = 'Ore rimaste';
const String kPackageEndedChoice = 'Pacchetto esaurito';
const String kOverPackageLabel = 'Ore oltre il pacchetto da saldare';

// «11h 30m usate su 18h».
String usedOf(int used, int hours) => '${hoursText(used)} ${used > 0 && used < 60 ? 'usati' : 'usate'} su ${hours}h';

const String kHoursState = 'Situazione delle ore';
const String kNoHoursChoice = 'Nessuna';
const String kDueChoice = 'Da saldare';
const String kAheadChoice = 'Pagate in anticipo';
const String kAheadLeftLabel = 'Ore pagate in anticipo rimaste';
const String kAheadRateLabel = 'Costo orario pagato';

// «€ 91,00 già pagati».
String alreadyPaid(int cents) => '${formatAmount(cents)} già pagati';

// «Da saldare € 42,00 (€ 14,00 l’ora)».
String toSettleAt(int cents, int centsPerHour) =>
    'Da saldare ${formatAmount(cents)} (${formatAmount(centsPerHour)} l’ora)';

String toSettle(int cents) => 'Da saldare ${formatAmount(cents)}';

const String kWeekendDueLabel = 'Ore online nel weekend da saldare';
const String kYesChoice = 'Sì';
const String kNoChoice = 'No';

const String kConfirmLabel = 'CONFERMA';
const String kTeacherConfirmed = 'Docente confermato.';
const String kPupilConfirmed = 'Studente confermato.';

const String kCloseOpeningLabel = 'CHIUDI CONFIGURAZIONE';
String closeOpeningMessage(DateTime lastDay) =>
    'La configurazione iniziale si chiuderà per sempre e sparirà dal menu: i dati al ${openingDay(lastDay)} non si potranno più modificare.';
const String kCloseLabel = 'CHIUDI';
const String kOpeningClosed = 'Configurazione iniziale chiusa.';

// Where nobody is set up yet: Pagamenti, «Da saldare», the summaries.
const String kOpeningPending = 'Da configurare';
const String kConfigureLabel = 'CONFIGURA';

String pendingPaymentsNote(DateTime lastDay) =>
    'La situazione al ${openingDay(lastDay)} non è ancora stata inserita: fino ad allora i pagamenti delle ore sono bloccati.';

const String kPendingReason = 'Prima configura lo studente in Contabilità › Configurazione iniziale.';

// The minutes the set-up carries, shown instead of a lesson's day.
String atDay(DateTime day) => 'Al ${openingDay(day)}';
