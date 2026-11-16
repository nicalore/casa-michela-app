import '../../../core/utils/week_range.dart';
import '../../accounting/models/volunteering_rule.dart';

const String kCompensationSection = 'Compensi';

const String kEditCompensationLabel = 'MODIFICA COMPENSO';
const String kCompensationEyebrow = 'Compenso';
const String kEditCompensationTitle = 'Modifica compenso';
const String kCompensationSaved = 'Compenso aggiornato.';

const String kGrossPayLabel = 'Paga lorda';
const String kNetPayLabel = 'Paga netta';
const String kGrossRateLabel = 'Compenso orario lordo';
const String kNetRateLabel = 'Compenso orario netto';
const String kWithholdingLabel = 'Ritenuta';

const String kCollaborationLabel = 'Collaborazione';
const String kWorkedDaysLabel = 'Giorni lavorati';
const String kWorkedHoursLabel = 'Ore lavorate';

const String kWorkGroup = 'Lavoro';
const String kVolunteerGroup = 'Volontariato';
const String kPayGroup = 'Paga';

const String kDayColumn = 'Giorno';
const String kStartColumn = 'Inizio';
const String kEndColumn = 'Fine';
const String kHoursColumn = 'Ore';
const String kGrossColumn = 'Lorda';
const String kNetColumn = 'Netta';
const String kWithholdingColumn = 'Ritenuta';

const String kIbanLabel = 'IBAN';
const String kIbanHint = 'Es. IT00A...';
const String kAddIbanLabel = 'AGGIUNGI IBAN';
const String kEditIbanLabel = 'MODIFICA IBAN';
const String kDeleteIbanLabel = 'ELIMINA IBAN';
const String kAddIbanTitle = 'Aggiungi IBAN';
const String kEditIbanTitle = 'Modifica IBAN';
const String kDeleteIbanQuestion = "L'IBAN verrà eliminato.";
const String kIbanAdded = 'IBAN aggiunto.';
const String kIbanSaved = 'IBAN aggiornato.';
const String kIbanDeleted = 'IBAN eliminato.';

const String kRateHint = 'Es. 10,00';
const String kInvalidAmount = 'Importo non valido';

String _monthText(DateTime month) => formatMonthYear(month).toLowerCase();

String compensationStartsNote(DateTime month) => 'Vale a partire dal mese di ${_monthText(month)}.';

// "ad agosto", "a ottobre".
String noHoursMessage(DateTime month)
{
  final String text = _monthText(month);

  return 'Nessuna ora lavorata ${text.startsWith('a') ? 'ad' : 'a'} $text';
}

String workedDaysText(int days) => days == 1 ? 'giorno' : 'giorni';

// Agrees with what is counted: «45m pagati», «1h pagata», «2h pagate».
String _doneText(int minutes, String stem)
{
  if (minutes < 60)
  {
    return '${stem}i';
  }

  return minutes == 60 ? '${stem}a' : '${stem}e';
}

String workedHoursText(int minutes) => _doneText(minutes, 'lavorat');

String paidHoursText(int minutes) => _doneText(minutes, 'pagat');

const String kVolunteerHoursText = 'di volontariato';

const String kVolunteeringLabel = 'Volontariato';
const String kEditVolunteeringTitle = 'Modifica volontariato';
const String kVolunteeringSaved = 'Volontariato aggiornato.';

const Map<VolunteeringRule, String> kVolunteeringRuleNames = {
  VolunteeringRule.weekly: "Un'ora a settimana",
  VolunteeringRule.daily: "Un'ora al giorno",
  VolunteeringRule.none: 'Nessun volontariato',
};

// "solo per ottobre": chosen in the monthly summary for that month alone.
String volunteeringMonthOnlyNote(DateTime month) => 'solo per ${formatMonthName(month)}';

String volunteeringPreviewTitle(DateTime month) => '${formatMonthYear(month)} con questa scelta';

const String kPreviewVolunteer = 'Volontariato';
const String kPreviewPaid = 'Pagate';

// "per ottobre", "per ottobre e novembre", "per ottobre, novembre e dicembre".
String volunteeringReplacedNote(List<DateTime> months)
{
  final List<String> names = [for (final month in months) formatMonthName(month)];
  final String joined = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';

  return names.length == 1
      ? 'Sostituisce la scelta fatta nel riepilogo mensile per $joined.'
      : 'Sostituisce le scelte fatte nel riepilogo mensile per $joined.';
}
