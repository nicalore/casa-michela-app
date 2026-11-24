import 'package:flutter/widgets.dart';

import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import 'utils/compensation_strings.dart' show kWalletSection;

const String kTourPayIban = 'compensation.iban';
const String kTourPayReport = 'compensation.report';
const String kTourPayVolunteering = 'compensation.volunteering';
const String kTourPayMonth = 'compensation.month';
const String kTourPayCard = 'compensation.pay';
const String kTourPayWork = 'compensation.work';
const String kTourPayDays = 'compensation.days';
const String kTourPayHours = 'compensation.hours';
const String kTourPayReceipt = 'compensation.receipt';
const String kTourPayPickerMonths = 'compensation.picker.months';
const String kTourWalletToFees = 'compensation.tab.fees';
const String kTourFeesStatus = 'compensation.fees.status';
const String kTourFeesHistory = 'compensation.fees.history';
const String kTourFeesEmpty = 'compensation.fees.empty';

// The Portafoglio's sections: the page sets it, the tour waits for it and turns it back.
const int kWalletPay = 0;
const int kWalletFees = 1;
final ValueNotifier<int> walletSection = ValueNotifier(kWalletPay);

// True while the month picker is open; its tour ends as it closes.
final ValueNotifier<bool> compensationPickerOpen = ValueNotifier(false);

String get _title => kWalletSection;

// Bump a version on every change to that tour.
const int _pageVersion = 2;
const int _pickerVersion = 1;

// Parts that may appear later: in the main tour if present, else toured alone when first shown.
const (String, int) _ibanSeen = ('compensation.mark.iban', 1);
const (String, int) _reportSeen = ('compensation.mark.report', 1);
const (String, int) _volunteeringSeen = ('compensation.mark.volunteering', 1);
const (String, int) _paySeen = ('compensation.mark.pay', 1);
const (String, int) _workSeen = ('compensation.mark.work', 1);
const (String, int) _daysSeen = ('compensation.mark.days', 1);
const (String, int) _hoursSeen = ('compensation.mark.hours', 1);
const (String, int) _receiptSeen = ('compensation.mark.receipt', 1);
const (String, int) _feesStatusSeen = ('compensation.mark.fees.status', 1);
const (String, int) _feesHistorySeen = ('compensation.mark.fees.history', 1);
const (String, int) _feesEmptySeen = ('compensation.mark.fees.empty', 1);

const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];
const List<DesktopTourSide> _leftFirst = [DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above];

bool _shown(String id) => isDesktopTourTargetShown(id);

// The teacher's own page only.
void startCompensationTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  if (taxCode == null || ApiService().lastKnownIdentity?.activeRole != 'TEACHER')
  {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_)
  {
    if (context.mounted)
    {
      startDesktopTourOnce(context, taxCode: taxCode, tour: tour);
    }
  });

  // Asked from another frame's callback, it still needs a frame to come.
  WidgetsBinding.instance.scheduleFrame();
}

// False when no identity is known.
Future<bool> compensationTourSeen(DesktopTour tour) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode != null && await isDesktopTourSeen(taxCode: taxCode, tour: tour);
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
DesktopTourStep get _ibanStep => DesktopTourStep(
  targets: const [kTourPayIban],
  text: tr(
    "Qui trovi l'IBAN del conto corrente su cui ricevi i compensi. Cliccando sull'occhio puoi visualizzarlo.",
    'Here you find the IBAN of the bank account your pay is sent to. Click the eye to see it.',
  ),
  sides: _below,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourPayIban),
  seen: _ibanSeen,
);

DesktopTourStep get _reportStep => DesktopTourStep(
  targets: const [kTourPayReport],
  text: tr(
    'Se il tuo IBAN è sbagliato o è cambiato, ti preghiamo di segnalarcelo.',
    'If your IBAN is wrong or has changed, please let us know.',
  ),
  sides: _over,
  pad: 6,
  radius: 17,
  reveal: true,
  present: () => _shown(kTourPayReport),
  seen: _reportSeen,
);

DesktopTourStep get _volunteeringStep => DesktopTourStep(
  targets: const [kTourPayVolunteering],
  text: tr(
    'Queste sono le ore di volontariato che ti sono state assegnate per il mese.',
    'These are the volunteering hours assigned to you for the month.',
  ),
  sides: _beside,
  pad: 6,
  radius: 31,
  reveal: true,
  present: () => _shown(kTourPayVolunteering),
  seen: _volunteeringSeen,
);

DesktopTourStep get _monthStep => DesktopTourStep(
  targets: const [kTourPayMonth],
  text: tr(
    'Puoi scorrere tra i mesi con le frecce, o cliccare il calendario per selezionare un mese qualsiasi.',
    'You can move between months with the arrows, or click the calendar to pick any month.',
  ),
  sides: _leftFirst,
  pad: 6,
  radius: 31,
  reveal: true,
);

DesktopTourStep get _payStep => DesktopTourStep(
  targets: const [kTourPayCard],
  text: tr(
    'Qui trovi la paga lorda e netta del mese, la ritenuta e il tuo compenso orario, con il riepilogo dei giorni e '
        'delle ore lavorate.',
    "Here you find the month's gross and net pay, the withholding tax and your hourly pay, with a summary of the "
        'days and hours worked.',
  ),
  sides: _below,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourPayCard),
  seen: _paySeen,
);

DesktopTourStep get _workStep => DesktopTourStep(
  targets: const [kTourPayWork],
  text: tr(
    'Qui trovi i giorni e le ore che hai lavorato nel mese.',
    'Here you find the days and hours you worked in the month.',
  ),
  sides: _below,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourPayWork),
  seen: _workSeen,
);

DesktopTourStep get _daysStep => DesktopTourStep(
  targets: const [kTourPayDays],
  text: tr(
    'La tabella riporta, giorno per giorno, gli orari in cui hai lavorato, le ore di volontariato e la paga '
        'accumulata.',
    'The table shows, day by day, the times you worked, the volunteering hours and the pay earned.',
  ),
  sides: _over,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourPayDays),
  seen: _daysSeen,
);

DesktopTourStep get _hoursStep => DesktopTourStep(
  targets: const [kTourPayHours],
  text: tr(
    'La tabella riporta, giorno per giorno, gli orari in cui hai lavorato.',
    'The table shows, day by day, the times you worked.',
  ),
  sides: _over,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourPayHours),
  seen: _hoursSeen,
);

DesktopTourStep get _receiptStep => DesktopTourStep(
  targets: const [kTourPayReceipt],
  text: tr(
    'Con «Scarica ricevuta» puoi ottenere la ricevuta del bonifico con cui ti è stato pagato il mese.',
    'With “Download receipt” you can get the receipt of the bank transfer that paid the month.',
  ),
  sides: _over,
  pad: 6,
  radius: 17,
  reveal: true,
  present: () => _shown(kTourPayReceipt),
  seen: _receiptSeen,
);

// The click Avanti makes too; the fees section comes in.
DesktopTourStep get _toFeesStep => DesktopTourStep(
  targets: const [kTourWalletToFees],
  text: tr('Clicca «Pagamenti».', 'Click “Payments”.'),
  sides: _beside,
  // The entry spans the rail: the hole keeps inside its edges.
  pad: 0,
  radius: 12,
  listen: walletSection,
  reached: () => walletSection.value == kWalletFees,
);

void _backToPay() => walletSection.value = kWalletPay;

DesktopTourStep get _feesStatusStep => DesktopTourStep(
  targets: const [kTourFeesStatus],
  text: tr(
    'Qui vedi se sei in regola con i pagamenti o se hai qualcosa da saldare.',
    'Here you can see whether your payments are up to date or you have something to pay.',
  ),
  sides: _below,
  pad: 8,
  radius: 36,
  reveal: true,
  undo: _backToPay,
  present: () => _shown(kTourFeesStatus),
  seen: _feesStatusSeen,
);

DesktopTourStep get _feesHistoryStep => DesktopTourStep(
  targets: const [kTourFeesHistory],
  text: tr(
    "La tabella riporta, anno per anno, tutti i pagamenti che hai effettuato verso l'associazione, con la data e la "
        'modalità di pagamento.',
    'The table shows, year by year, all the payments you have made to the Association, with the date and method of '
        'payment.',
  ),
  sides: _over,
  pad: 8,
  radius: 36,
  reveal: true,
  // With no status before it, a step back is a step back to the pay.
  undo: ()
  {
    if (!_shown(kTourFeesStatus))
    {
      _backToPay();
    }
  },
  present: () => _shown(kTourFeesHistory),
  seen: _feesHistorySeen,
);

DesktopTourStep get _feesEmptyStep => DesktopTourStep(
  targets: const [kTourFeesEmpty],
  text: tr(
    "Qui troverai, anno per anno, tutti i pagamenti che hai effettuato verso l'associazione, con la data e la "
        'modalità di pagamento.',
    "Here you'll find, year by year, all the payments you have made to the Association, with the date and method of "
        'payment.',
  ),
  sides: _beside,
  // AppEmptyCard's corner 28 + half the pad.
  pad: 8,
  radius: 32,
  reveal: true,
  undo: _backToPay,
  present: () => _shown(kTourFeesEmpty),
  seen: _feesEmptySeen,
);

// The IBAN and its report first, then the page from the top.
List<DesktopTourStep> get _marks => [
  _ibanStep,
  _reportStep,
  _volunteeringStep,
  _payStep,
  _workStep,
  _daysStep,
  _hoursStep,
  _receiptStep,
];

DesktopTour get compensationPageTour => DesktopTour(
  slug: 'compensation',
  title: _title,
  version: _pageVersion,
  steps: [
    _ibanStep,
    _reportStep,
    _volunteeringStep,
    _monthStep,
    _payStep,
    _workStep,
    _daysStep,
    _hoursStep,
    _receiptStep,
    _toFeesStep,
    _feesStatusStep,
    _feesHistoryStep,
    _feesEmptyStep,
  ],
);

// The parts on show not told yet, as one tour; null when none is due.
Future<DesktopTour?> compensationLateTour() async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode == null ? null : dueDesktopTour(taxCode: taxCode, title: _title, steps: _marks);
}

// The fees' parts on show not told yet, read in their own section; null when none is due.
Future<DesktopTour?> compensationFeesLateTour() async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode == null
      ? null
      : dueDesktopTour(taxCode: taxCode, title: _title, steps: [_feesStatusStep, _feesHistoryStep, _feesEmptyStep]);
}

// Over the picker; a click on a month picks it and ends the tour.
DesktopTour get compensationPickerTour => DesktopTour(
  slug: 'compensation.picker',
  title: _title,
  version: _pickerVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourPayPickerMonths],
      text: tr(
        'Il pallino sotto un mese indica la presenza di ore lavorate in quel mese.',
        'The dot under a month means there are hours worked in that month.',
      ),
      sides: _beside,
      pad: 6,
      radius: 22,
      interactive: true,
      listen: compensationPickerOpen,
      reached: () => !compensationPickerOpen.value,
    ),
  ],
);
