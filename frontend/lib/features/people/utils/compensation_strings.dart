import '../../../core/language/app_language.dart';
import '../../../core/utils/week_range.dart';
import '../../accounting/models/volunteering_rule.dart';

String get kCompensationSection => tr('Compensi', 'Pay');

// The teacher's section holding their pay and their fees.
String get kWalletSection => tr('Portafoglio', 'Wallet');

String get kEditCompensationLabel => tr('MODIFICA COMPENSO', 'EDIT PAY');
String get kCompensationEyebrow => tr('Compenso', 'Pay');
String get kEditCompensationTitle => tr('Modifica compenso', 'Edit pay');
String get kCompensationSaved => tr('Compenso aggiornato.', 'Pay updated.');

String get kGrossPayLabel => tr('Paga lorda', 'Gross pay');
String get kNetPayLabel => tr('Paga netta', 'Net pay');
String get kGrossRateLabel => tr('Compenso orario lordo', 'Gross hourly pay');
String get kNetRateLabel => tr('Compenso orario netto', 'Net hourly pay');
String get kWithholdingLabel => tr('Ritenuta', 'Withholding tax');

String get kCollaborationLabel => tr('Collaborazione', 'Collaboration');
String get kWorkedDaysLabel => tr('Giorni lavorati', 'Days worked');
String get kWorkedHoursLabel => tr('Ore lavorate', 'Hours worked');

String get kWorkGroup => tr('Lavoro', 'Work');
String get kVolunteerGroup => tr('Volontariato', 'Volunteering');
String get kPayGroup => tr('Paga', 'Pay');

String get kDayColumn => tr('Giorno', 'Day');
String get kStartColumn => tr('Inizio', 'Start');
String get kEndColumn => tr('Fine', 'End');
String get kHoursColumn => tr('Ore', 'Hours');
String get kGrossColumn => tr('Lorda', 'Gross');
String get kNetColumn => tr('Netta', 'Net');
String get kWithholdingColumn => tr('Ritenuta', 'Withholding tax');

// The teacher's own Compensi on the phone: five columns share a narrow row.
String get kVolunteerShortColumn => tr('Volont.', 'Volunt.');
String get kPaidHoursLabel => tr('Ore pagate', 'Paid hours');
// The bank transfer receipt, on the teacher's own Compensi.
String get kDownloadReceiptLabel => tr('Scarica ricevuta', 'Download receipt');
String get kReceiptSaved => tr('La ricevuta è stata scaricata.', 'The receipt has been downloaded.');
String get kReceiptSaveFailed => tr('Non è stato possibile salvare la ricevuta.', "Couldn't save the receipt.");
String get kReportIbanLabel => tr('Segnala IBAN mancante / errato', 'Report missing / wrong IBAN');
String get kCompensationLoadFailed => tr('Non è stato possibile caricare i compensi.', "Couldn't load your pay.");

const String kIbanLabel = 'IBAN';
String get kIbanHint => tr('Es. IT00A...', 'E.g. IT00A...');
String get kAddIbanLabel => tr('AGGIUNGI IBAN', 'ADD IBAN');
String get kEditIbanLabel => tr('MODIFICA IBAN', 'EDIT IBAN');
String get kDeleteIbanLabel => tr('ELIMINA IBAN', 'DELETE IBAN');
String get kAddIbanTitle => tr('Aggiungi IBAN', 'Add IBAN');
String get kEditIbanTitle => tr('Modifica IBAN', 'Edit IBAN');
String get kDeleteIbanQuestion => tr("L'IBAN verrà eliminato.", 'The IBAN will be deleted.');
String get kIbanAdded => tr('IBAN aggiunto.', 'IBAN added.');
String get kIbanSaved => tr('IBAN aggiornato.', 'IBAN updated.');
String get kIbanDeleted => tr('IBAN eliminato.', 'IBAN deleted.');

String get kRateHint => tr('Es. 10,00', 'E.g. 10.00');
String get kInvalidAmount => tr('Importo non valido', 'Invalid amount');

// English month names keep their capital.
String _monthText(DateTime month) => isEnglish ? formatMonthYear(month) : formatMonthYear(month).toLowerCase();

String compensationStartsNote(DateTime month) =>
    tr('Vale a partire dal mese di ${_monthText(month)}.', 'Applies from ${_monthText(month)}.');

// "ad agosto", "a ottobre".
String noHoursMessage(DateTime month)
{
  final String text = _monthText(month);

  return tr('Nessuna ora lavorata ${text.startsWith('a') ? 'ad' : 'a'} $text', 'No hours worked in $text');
}

String workedDaysText(int days) => days == 1 ? tr('giorno', 'day') : tr('giorni', 'days');

// Agrees with what is counted: «45m pagati», «1h pagata», «2h pagate».
String _doneText(int minutes, String stem)
{
  if (minutes < 60)
  {
    return '${stem}i';
  }

  return minutes == 60 ? '${stem}a' : '${stem}e';
}

String workedHoursText(int minutes) => isEnglish ? 'worked' : _doneText(minutes, 'lavorat');

String paidHoursText(int minutes) => isEnglish ? 'paid' : _doneText(minutes, 'pagat');

String get kVolunteerHoursText => tr('di volontariato', 'of volunteering');

String get kVolunteeringLabel => tr('Volontariato', 'Volunteering');
String get kEditVolunteeringTitle => tr('Modifica volontariato', 'Edit volunteering');
String get kVolunteeringSaved => tr('Volontariato aggiornato.', 'Volunteering updated.');

Map<VolunteeringRule, String> get kVolunteeringRuleNames => {
  VolunteeringRule.weekly: tr("Un'ora a settimana", 'One hour a week'),
  VolunteeringRule.daily: tr("Un'ora al giorno", 'One hour a day'),
  VolunteeringRule.none: tr('Nessun volontariato', 'No volunteering'),
};

// "solo per ottobre": chosen in the monthly summary for that month alone.
String volunteeringMonthOnlyNote(DateTime month) =>
    tr('solo per ${formatMonthName(month)}', 'for ${formatMonthName(month)} only');

String volunteeringPreviewTitle(DateTime month) =>
    tr('${formatMonthYear(month)} con questa scelta', '${formatMonthYear(month)} with this choice');

String get kPreviewVolunteer => tr('Volontariato', 'Volunteering');
String get kPreviewPaid => tr('Pagate', 'Paid');

// "per ottobre", "per ottobre e novembre", "per ottobre, novembre e dicembre".
String volunteeringReplacedNote(List<DateTime> months)
{
  final List<String> names = [for (final month in months) formatMonthName(month)];
  final String joined = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} ${tr('e', 'and')} ${names.last}';

  return names.length == 1
      ? tr(
          'Sostituisce la scelta fatta nel riepilogo mensile per $joined.',
          'Replaces the choice made in the monthly summary for $joined.',
        )
      : tr(
          'Sostituisce le scelte fatte nel riepilogo mensile per $joined.',
          'Replaces the choices made in the monthly summary for $joined.',
        );
}
