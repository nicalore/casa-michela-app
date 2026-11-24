import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../features/people/utils/compensation_strings.dart' show kWalletSection;
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_fees_tab.dart';

const String kPayTourIban = 'compensation.iban';
const String kPayTourReport = 'compensation.report';
const String kPayTourMonth = 'compensation.month';
const String kPayTourPay = 'compensation.pay';
const String kPayTourVolunteering = 'compensation.volunteering';
const String kPayTourWork = 'compensation.work';
const String kPayTourDays = 'compensation.days';
const String kPayTourHours = 'compensation.hours';
const String kPayTourDay = 'compensation.day';
const String kPayTourDaySheet = 'compensation.day.details';
const String kPayTourReceipt = 'compensation.receipt';
const String kPayTourPickerMonths = 'compensation.picker.months';
const String kPayTourFeesStatus = 'compensation.fees.status';
const String kPayTourFeesList = 'compensation.fees.list';
const String kPayTourFee = 'compensation.fees.first';
const String kPayTourFeesEmpty = 'compensation.fees.empty';

// The strip's tabs: the pay, then the fees.
String compensationTourTab(int page) => 'compensation.tab.$page';

const int _feesPage = 1;
const Duration _pageBack = Duration(milliseconds: 320);
const double _settled = 0.001;

String get _title => kWalletSection;

// Bump a version on every change to that tour.
const String _slug = 'compensation';
const int _version = 2;
const String _pickerSlug = 'compensation.picker';
const int _pickerVersion = 1;

// Parts that may appear later: in the main tour if present, else toured alone when first shown.
enum PayTourMark { iban, report, pay, volunteering, work, days, hours, day, receipt, feesStatus, feesList, feesEmpty }

const Map<PayTourMark, int> _markVersions = {
  PayTourMark.iban: 1,
  PayTourMark.report: 1,
  PayTourMark.pay: 1,
  PayTourMark.volunteering: 1,
  PayTourMark.work: 1,
  PayTourMark.days: 1,
  PayTourMark.hours: 1,
  PayTourMark.day: 1,
  PayTourMark.receipt: 1,
  PayTourMark.feesStatus: 1,
  PayTourMark.feesList: 1,
  PayTourMark.feesEmpty: 1,
};

(String, int) _markSeen(PayTourMark mark) => ('$_slug.mark.${mark.name}', _markVersions[mark]!);

String get _iban => tr(
  "Qui trovi l'IBAN del conto corrente su cui ricevi i compensi. Toccando l'occhio puoi visualizzarlo.",
  'Here you find the IBAN of the bank account your pay is sent to. Tap the eye to see it.',
);
String get _report => tr(
  'Se il tuo IBAN è sbagliato o è cambiato, ti preghiamo di segnalarcelo.',
  'If your IBAN is wrong or has changed, please let us know.',
);
String get _month => tr(
  'Puoi scorrere tra i mesi con le frecce, o toccare il mese al centro per selezionarne uno qualsiasi.',
  'You can move between months with the arrows, or tap the month in the middle to choose any month.',
);
String get _pay => tr(
  'Qui trovi la paga lorda e netta del mese, la ritenuta e il tuo compenso orario, con il riepilogo dei giorni e '
      'delle ore lavorate.',
  "Here you find the month's gross and net pay, the withholding tax and your hourly pay, with a summary of the "
      'days and hours worked.',
);
String get _volunteering => tr(
  'Queste sono le ore di volontariato che ti sono state assegnate per il mese.',
  'These are the volunteering hours assigned to you for the month.',
);
String get _work => tr(
  'Qui trovi i giorni e le ore che hai lavorato nel mese.',
  'Here you find the days and hours you worked in the month.',
);
String get _days => tr(
  'La tabella riporta, giorno per giorno, gli orari in cui hai lavorato, le ore di volontariato e la paga accumulata.',
  'The table shows, day by day, the times you worked, the volunteering hours and the pay earned.',
);
String get _hours => tr(
  'La tabella riporta, giorno per giorno, gli orari in cui hai lavorato.',
  'The table shows, day by day, the times you worked.',
);
String get _toDay => tr('Tocca un giorno per vederne i dettagli.', 'Tap a day to see its details.');
String get _daySheet => tr(
  'Qui puoi leggere tutti i dettagli sulle ore lavorate.',
  'Here you can read all the details about the hours worked.',
);
String get _closeSheet => tr('Tocca la $kMobileTourGlyph per chiudere il menù.', 'Tap the $kMobileTourGlyph to close the menu.');
String get _receipt => tr(
  'Con «Scarica ricevuta» puoi ottenere la ricevuta del bonifico con cui ti è stato pagato il mese.',
  'With “Download receipt” you can get the receipt of the bank transfer that paid the month.',
);
String get _toFees => tr('Tocca «Pagamenti».', 'Tap “Payments”.');
String get _feesStatus => tr(
  'Qui vedi se sei in regola con i pagamenti o se hai qualcosa da saldare.',
  'Here you can see whether your payments are up to date or you have something to pay.',
);
String get _feesList => tr(
  "La tabella riporta, anno per anno, tutti i pagamenti che hai effettuato verso l'associazione, con la data e la "
      'modalità di pagamento.',
  'The table shows, year by year, all the payments you have made to the Association, with the date and method of '
      'payment.',
);
String get _toFee => tr('Tocca un pagamento per vederne i dettagli.', 'Tap a payment to see its details.');
String get _feesEmpty => tr(
  "Qui troverai, anno per anno, tutti i pagamenti che hai effettuato verso l'associazione, con la data e la "
      'modalità di pagamento.',
  "Here you'll find, year by year, all the payments you have made to the Association, with the date and method of "
      'payment.',
);
String get _picker => tr(
  'Il pallino sotto un mese indica la presenza di ore lavorate in quel mese.',
  'The dot under a month means there are hours worked in that month.',
);

// The day sheet tells the tour when it is up, and lets it close it again.
class PaySheetTourLink extends ChangeNotifier
{
  bool open = false;

  VoidCallback? _close;

  void rise({required VoidCallback close})
  {
    _close = close;
    open = true;
    notifyListeners();
  }

  void fall()
  {
    open = false;
    _close = null;
    notifyListeners();
  }

  void close() => _close?.call();
}

MobileTourStep _shownStep(PayTourMark mark, String text, String target)
{
  return MobileTourStep(
    text: text,
    shown: [target],
    present: () => isMobileTourTargetShown(target),
    seen: _markSeen(mark),
  );
}

// The touched day opens its sheet; its × closes it and the page goes on.
// Closed otherwise, the page's steps go on too; stepping back into it opens it again.
List<MobileTourStep> _daySteps({required PaySheetTourLink sheet, required VoidCallback openDay})
{
  void reopen()
  {
    if (!sheet.open)
    {
      openDay();
    }
  }

  return [
    MobileTourStep(
      text: _toDay,
      touched: const [kPayTourDay],
      reveal: kPayTourDay,
      watch: sheet,
      reached: () => sheet.open,
      undo: sheet.close,
      present: () => isMobileTourTargetShown(kPayTourDay),
      seen: _markSeen(PayTourMark.day),
    ),
    MobileTourStep(
      text: _daySheet,
      shown: const [kPayTourDaySheet],
      watch: sheet,
      acted: () => !sheet.open,
      undo: reopen,
      present: () => sheet.open,
      coming: () => isMobileTourTargetShown(kPayTourDay),
    ),
    MobileTourStep(
      text: _closeSheet,
      touched: const [kMobileTourSheetClose],
      glyph: MobileSheetCloseButton.glyph,
      watch: sheet,
      reached: () => !sheet.open,
      undo: reopen,
      present: () => sheet.open,
      coming: () => isMobileTourTargetShown(kPayTourDay),
    ),
  ];
}

// The fees' parts, read on their tab once it has come in; known ahead from the fees already loaded.
List<(PayTourMark, List<MobileTourStep>)> _feeParts({
  required bool tablet,
  required PageController pages,
  required MobileFeesSource fees,
})
{
  bool onFees() => pages.hasClients && ((pages.page ?? 0) - _feesPage).abs() < _settled;
  bool status() => fees.payments?.state != null;
  bool listed() => fees.payments?.history.isNotEmpty ?? false;
  bool empty() => fees.payments?.history.isEmpty ?? false;

  MobileTourStep read(PayTourMark mark, String text, String target, bool Function() holds)
  {
    return MobileTourStep(
      text: text,
      shown: [target],
      reveal: target,
      present: () => onFees() && holds(),
      coming: holds,
      seen: _markSeen(mark),
    );
  }

  return [
    (PayTourMark.feesStatus, [read(PayTourMark.feesStatus, _feesStatus, kPayTourFeesStatus, status)]),
    (
      PayTourMark.feesList,
      [
        read(PayTourMark.feesList, _feesList, kPayTourFeesList, listed),
        // The phone's fees open their sheet; the tablet's rows open nothing.
        if (!tablet)
          MobileTourStep(
            text: _toFee,
            touched: const [kPayTourFee],
            reveal: kPayTourFee,
            watch: MobileNavSheet.hidden,
            reached: () => MobileNavSheet.hidden.value,
            present: () => onFees() && listed(),
            coming: listed,
          ),
      ],
    ),
    (PayTourMark.feesEmpty, [read(PayTourMark.feesEmpty, _feesEmpty, kPayTourFeesEmpty, empty)]),
  ];
}

// Each part with what tells it; the day's touch takes its sheet's steps along.
List<(PayTourMark, List<MobileTourStep>)> _parts({
  required bool tablet,
  required PaySheetTourLink sheet,
  required VoidCallback openDay,
  required PageController pages,
  required MobileFeesSource fees,
})
{
  return [
    (PayTourMark.iban, [_shownStep(PayTourMark.iban, _iban, kPayTourIban)]),
    (PayTourMark.report, [_shownStep(PayTourMark.report, _report, kPayTourReport)]),
    (PayTourMark.pay, [_shownStep(PayTourMark.pay, _pay, kPayTourPay)]),
    (PayTourMark.volunteering, [_shownStep(PayTourMark.volunteering, _volunteering, kPayTourVolunteering)]),
    (PayTourMark.work, [_shownStep(PayTourMark.work, _work, kPayTourWork)]),
    (PayTourMark.days, [_shownStep(PayTourMark.days, _days, kPayTourDays)]),
    (PayTourMark.hours, [_shownStep(PayTourMark.hours, _hours, kPayTourHours)]),
    if (!tablet) (PayTourMark.day, _daySteps(sheet: sheet, openDay: openDay)),
    (PayTourMark.receipt, [_shownStep(PayTourMark.receipt, _receipt, kPayTourReceipt)]),
    ..._feeParts(tablet: tablet, pages: pages, fees: fees),
  ];
}

// The IBAN and its report first, then the page from the top; the tablet opens no day.
// Then the fees' tab, its strip's touch made by Avanti too.
MobileTour compensationTour({
  required bool tablet,
  required PaySheetTourLink sheet,
  required VoidCallback openDay,
  required PageController pages,
  required MobileFeesSource fees,
})
{
  final List<(PayTourMark, List<MobileTourStep>)> parts =
      _parts(tablet: tablet, sheet: sheet, openDay: openDay, pages: pages, fees: fees);

  List<MobileTourStep> of(PayTourMark mark) => parts.firstWhere((part) => part.$1 == mark).$2;

  return MobileTour(
    slug: _slug,
    title: _title,
    version: _version,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      ...of(PayTourMark.iban),
      ...of(PayTourMark.report),
      MobileTourStep(text: _month, shown: const [kPayTourMonth]),
      ...of(PayTourMark.pay),
      ...of(PayTourMark.volunteering),
      ...of(PayTourMark.work),
      ...of(PayTourMark.days),
      ...of(PayTourMark.hours),
      if (!tablet) ...of(PayTourMark.day),
      ...of(PayTourMark.receipt),
      // The page scrolled down by the steps before: the strip comes back in sight.
      MobileTourStep(
        text: _toFees,
        touched: [compensationTourTab(_feesPage)],
        reveal: compensationTourTab(_feesPage),
        watch: pages,
        reached: () => pages.hasClients && ((pages.page ?? 0) - _feesPage).abs() < _settled,
        undo: ()
        {
          if (pages.hasClients)
          {
            pages.animateToPage(0, duration: _pageBack, curve: Curves.easeInOutCubic);
          }
        },
      ),
      ...of(PayTourMark.feesStatus),
      ...of(PayTourMark.feesList),
      ...of(PayTourMark.feesEmpty),
    ],
    coversIfClosed: [for (final PayTourMark mark in PayTourMark.values) _markSeen(mark)],
  );
}

// Only to ask whether the main tour was seen: its steps do not matter there.
MobileTour get compensationMainTour => const MobileTour(slug: _slug, title: '', version: _version, steps: []);

MobileTour _seenMarker((String, int) seen) => MobileTour(slug: seen.$1, title: _title, version: seen.$2, steps: const []);

// The parts on show never told, as one tour slugged after the first; none due, nothing starts.
Future<void> startCompensationLateTour({
  required String taxCode,
  required bool tablet,
  required PaySheetTourLink sheet,
  required VoidCallback openDay,
  required PageController pages,
  required MobileFeesSource fees,
}) async
{
  final List<MobileTourStep> steps = [];
  (String, int)? first;

  for (final (mark, part) in _parts(tablet: tablet, sheet: sheet, openDay: openDay, pages: pages, fees: fees))
  {
    if (part.first.isPresent && !await isMobileTourSeen(taxCode: taxCode, tour: _seenMarker(_markSeen(mark))))
    {
      steps.addAll(part);
      first ??= _markSeen(mark);
    }
  }

  final (String, int)? due = first;

  if (due == null)
  {
    return;
  }

  await startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(slug: due.$1, title: _title, version: due.$2, steps: steps),
  );
}

// Over the month sheet, the first time it rises; closed under it, it comes again the next time.
MobileTour compensationPickerTour() => MobileTour(
  slug: _pickerSlug,
  title: _title,
  version: _pickerVersion,
  steps: [MobileTourStep(text: _picker, shown: const [kPayTourPickerMonths])],
  leave: MobileNavSheet.hidden,
  left: () => !MobileNavSheet.hidden.value,
);
