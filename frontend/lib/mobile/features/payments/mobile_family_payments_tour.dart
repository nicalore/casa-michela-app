import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../features/people/models/student_payments_item.dart';
import '../../../features/people/payments_tour_texts.dart';
import '../../../features/people/utils/payments_strings.dart' show paymentsByYear;
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';

// The page's parts.
const String kFamilyTourChildren = 'payments.children';
const String kFamilyTourTariff = 'payments.tariff';
const String kFamilyTourStatus = 'payments.status';
const String kFamilyTourPay = 'payments.pay';
const String kFamilyTourHistory = 'payments.history';
const String kFamilyTourEmpty = 'payments.empty';
const String kFamilyTourRow = 'payments.row';
const String kFamilyTourOwnHistory = 'payments.own.history';

// «Figli» and «Personali».
String familyTourTab(int page) => 'payments.tab.$page';

// A payment's sheet: its card, its strip, its lessons.
const String kFamilyTourFacts = 'payments.sheet.facts';
const String kFamilyTourLessons = 'payments.sheet.lessons';
String familyTourSheetTab(int page) => 'payments.sheet.tab.$page';

// The «PAGA» sheet's parts.
const String kFamilyPayTourOwed = 'payments.pay.owed';
const String kFamilyPayTourDays = 'payments.pay.days';
const String kFamilyPayTourOthers = 'payments.pay.others';
const String kFamilyPayTourProceed = 'payments.pay.proceed';

const int _ownPage = 1;
const double _settled = 0.001;
const Duration _pageBack = Duration(milliseconds: 320);

// Bump a version on every change to that tour.
const String _parentSlug = 'payments.parent';
const String _studentSlug = 'payments.student';
const int _version = 4;

// The page's parts that may show later: told in the page's tour, or alone the first time they show.
enum FamilyPageMark { tariff, status, pay, history, empty }

const Map<FamilyPageMark, int> _pageVersions = {
  FamilyPageMark.tariff: 2,
  FamilyPageMark.status: 2,
  FamilyPageMark.pay: 2,
  FamilyPageMark.history: 2,
  FamilyPageMark.empty: 1,
};

(String, int) _pageSeen(FamilyPageMark mark) => ('payments.mark.${mark.name}', _pageVersions[mark]!);

// A payment's sheet parts, told in the page's tour or the first time a sheet shows them.
enum FamilySheetMark { facts, lessons }

const Map<FamilySheetMark, int> _sheetVersions = {
  FamilySheetMark.facts: 1,
  FamilySheetMark.lessons: 1,
};

(String, int) _sheetSeen(FamilySheetMark mark) => ('payments.mark.${mark.name}', _sheetVersions[mark]!);

// The «PAGA» sheet's parts, each told the first time it shows.
enum FamilyPayMark { owed, days, others, proceed }

const Map<FamilyPayMark, int> _payVersions = {
  FamilyPayMark.owed: 2,
  FamilyPayMark.days: 1,
  // 2: online hours at the weekend paid ahead.
  FamilyPayMark.others: 2,
  FamilyPayMark.proceed: 1,
};

(String, int) _paySeen(FamilyPayMark mark) => ('payments.pay.${mark.name}', _payVersions[mark]!);

// The payment the tour opens: the first one shown, paid or still to pay.
PaymentHistoryRow? familyTouredRow(StudentPaymentsItem payments)
{
  return paymentsByYear(payments.history, romeNow().year).values.expand((rows) => rows).firstOrNull;
}

// A payment's sheet tells the tour when it is up, which row it shows and its page; and lets it turn and close.
class PaymentSheetTourLink extends ChangeNotifier
{
  bool open = false;

  int page = 0;

  PaymentHistoryRow? row;

  VoidCallback? _toFirstPage;
  VoidCallback? _close;

  // The page may go before the sheet tells it it fell.
  bool _disposed = false;

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }

  void rise({required PaymentHistoryRow row, required VoidCallback toFirstPage, required VoidCallback close})
  {
    if (_disposed)
    {
      return;
    }

    this.row = row;
    _toFirstPage = toFirstPage;
    _close = close;
    open = true;
    page = 0;
    notifyListeners();
  }

  void turned(int page)
  {
    if (!_disposed && page != this.page)
    {
      this.page = page;
      notifyListeners();
    }
  }

  void fall()
  {
    if (_disposed)
    {
      return;
    }

    open = false;
    page = 0;
    row = null;
    _toFirstPage = null;
    _close = null;
    notifyListeners();
  }

  void toFirstPage() => _toFirstPage?.call();

  void close() => _close?.call();

  bool get lessons => row?.lessons.isNotEmpty ?? false;
}

String get _closeSheet => tr('Tocca la $kMobileTourGlyph per chiudere il menù.', 'Tap the $kMobileTourGlyph to close the menu.');

// The card, then the lessons' tab and card when the payment has lessons; [coming]: what the page's touch brings.
// [goesOn]: the page's steps follow, so a sheet closed under them moves the tour on.
List<MobileTourStep> _sheetSteps({
  required PaymentSheetTourLink sheet,
  required PaymentHistoryRow? row,
  bool Function()? coming,
  Set<FamilySheetMark> marks = const {FamilySheetMark.facts, FamilySheetMark.lessons},
  bool goesOn = false,
})
{
  final bool lessons = row?.lessons.isNotEmpty ?? false;
  final bool Function()? closed = goesOn ? () => !sheet.open : null;

  return [
    if (marks.contains(FamilySheetMark.facts))
      MobileTourStep(
        text: kPaymentsTourFacts,
        shown: const [kFamilyTourFacts],
        high: true,
        scrolls: false,
        watch: goesOn ? sheet : null,
        acted: closed,
        undo: sheet.toFirstPage,
        present: () => sheet.open,
        coming: coming,
        seen: _sheetSeen(FamilySheetMark.facts),
      ),
    if (marks.contains(FamilySheetMark.lessons) && row != null && lessons) ...[
      MobileTourStep(
        text: kPaymentsTourToLessons,
        touched: [familyTourSheetTab(1)],
        high: true,
        scrolls: false,
        watch: sheet,
        reached: () => sheet.page == 1,
        acted: closed,
        undo: sheet.toFirstPage,
        present: () => sheet.open && sheet.lessons,
        coming: coming,
      ),
      MobileTourStep(
        text: paymentsTourLessons(row),
        shown: const [kFamilyTourLessons],
        high: true,
        scrolls: false,
        watch: goesOn ? sheet : null,
        acted: closed,
        present: () => sheet.open && sheet.page == 1,
        coming: coming ?? () => sheet.open,
        seen: _sheetSeen(FamilySheetMark.lessons),
      ),
    ],
  ];
}

MobileTourStep _read(String text, String target, {(String, int)? seen})
{
  return MobileTourStep(
    text: text,
    shown: [target],
    reveal: target,
    present: () => isMobileTourTargetShown(target),
    seen: seen,
  );
}

// Tariff, status, «PAGA» (only read: the person pays when they choose), history or its empty card.
List<(FamilyPageMark, MobileTourStep)> _pageParts({
  required bool self,
  required String? gender,
  required StudentTariffItem? tariff,
})
{
  (FamilyPageMark, MobileTourStep) part(FamilyPageMark mark, String text, String target) =>
      (mark, _read(text, target, seen: _pageSeen(mark)));

  return [
    part(FamilyPageMark.tariff, paymentsTourTariff(self: self, gender: gender), kFamilyTourTariff),
    part(FamilyPageMark.status, paymentsTourStatus(self: self, gender: gender), kFamilyTourStatus),
    part(FamilyPageMark.pay, paymentsTourPay(tariff), kFamilyTourPay),
    part(FamilyPageMark.history, paymentsTourHistory(self: self, gender: gender, phone: true), kFamilyTourHistory),
    part(FamilyPageMark.empty, paymentsTourEmpty(self: self, gender: gender), kFamilyTourEmpty),
  ];
}

// [self]: a pupil reading their own. [genders]: every child's; [gender]: the child shown.
// [pages]: the «Figli» / «Personali» strip, a member parent's; [sheet]: the payment sheet the touch opens.
// [row]: the child's payment the tour opens, [openRow] opens its sheet again when the tour steps back into it.
MobileTour familyPaymentsTour({
  required bool self,
  required List<String?> genders,
  required String? gender,
  required StudentTariffItem? tariff,
  required bool member,
  required PageController pages,
  required PaymentSheetTourLink sheet,
  required PaymentHistoryRow? row,
  required VoidCallback openRow,
})
{
  bool onOwn() => pages.hasClients && ((pages.page ?? 0) - _ownPage).abs() < _settled;
  bool shown(String id) => isMobileTourTargetShown(id);

  void reopen()
  {
    if (!sheet.open)
    {
      openRow();
    }
  }

  return MobileTour(
    slug: self ? _studentSlug : _parentSlug,
    title: kPaymentsTourTitle,
    version: _version,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      MobileTourStep(text: kPaymentsTourIntro, lightsAll: true, high: true),
      // One frame round every child's tile, as in Prenotazioni and Calendario.
      if (!self && genders.length > 1)
        MobileTourStep(
          text: paymentsTourChildren(genders),
          shown: const [kFamilyTourChildren],
          reveal: kFamilyTourChildren,
          joined: true,
          present: () => shown(kFamilyTourChildren),
        ),
      for (final (_, MobileTourStep step) in _pageParts(self: self, gender: gender, tariff: tariff)) step,
      // The child's payment opens its sheet, told there; its × brings the page back, a drag too.
      if (row != null) ...[
        MobileTourStep(
          text: kPaymentsTourOpenTap,
          touched: const [kFamilyTourRow],
          reveal: kFamilyTourRow,
          watch: sheet,
          reached: () => sheet.open,
          undo: sheet.close,
          present: () => shown(kFamilyTourRow),
        ),
        ..._sheetSteps(sheet: sheet, row: row, coming: () => true, goesOn: true),
        MobileTourStep(
          text: _closeSheet,
          touched: const [kMobileTourSheetClose],
          glyph: MobileSheetCloseButton.glyph,
          scrolls: false,
          watch: sheet,
          reached: () => !sheet.open,
          undo: reopen,
          present: () => sheet.open,
          coming: () => true,
        ),
      ],
      if (member) ...[
        // The page scrolled down by the steps before: the strip comes back in sight.
        MobileTourStep(
          text: kPaymentsTourToOwnTap,
          touched: [familyTourTab(_ownPage)],
          reveal: familyTourTab(_ownPage),
          watch: pages,
          reached: onOwn,
          undo: ()
          {
            if (pages.hasClients)
            {
              pages.animateToPage(0, duration: _pageBack, curve: Curves.easeInOutCubic);
            }
          },
        ),
        MobileTourStep(
          text: kPaymentsTourOwn,
          shown: const [kFamilyTourOwnHistory],
          reveal: kFamilyTourOwnHistory,
          present: () => onOwn() && shown(kFamilyTourOwnHistory),
          coming: () => true,
        ),
      ],
    ],
    coversIfClosed: [
      for (final FamilyPageMark mark in FamilyPageMark.values) _pageSeen(mark),
      for (final FamilySheetMark mark in FamilySheetMark.values) _sheetSeen(mark),
    ],
  );
}

// After the page's tour: the parts on show never told (a «PAGA» come later, a first payment), as one tour.
Future<void> startFamilyPageLateTour({
  required String taxCode,
  required bool self,
  required String? gender,
  required StudentTariffItem? tariff,
}) async
{
  final List<MobileTourStep> steps = [];
  (String, int)? first;

  for (final (FamilyPageMark mark, MobileTourStep step) in _pageParts(self: self, gender: gender, tariff: tariff))
  {
    if (step.isPresent && !await isMobileTourSeen(taxCode: taxCode, tour: _marker(_pageSeen(mark))))
    {
      steps.add(step);
      first ??= _pageSeen(mark);
    }
  }

  final (String, int)? due = first;

  if (due == null)
  {
    return;
  }

  await startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(slug: due.$1, title: kPaymentsTourTitle, version: due.$2, steps: steps),
  );
}

MobileTour _marker((String, int) seen) =>
    MobileTour(slug: seen.$1, title: kPaymentsTourTitle, version: seen.$2, steps: const []);

// Only to ask whether the page's tour was seen.
MobileTour familyPaymentsMainTour({required bool self}) =>
    MobileTour(slug: self ? _studentSlug : _parentSlug, title: '', version: _version, steps: const []);

// A payment's sheet up outside the page's tour: its parts never told, the first time they show.
Future<void> startFamilySheetTour({required String taxCode, required PaymentSheetTourLink sheet}) async
{
  final Set<FamilySheetMark> marks = {
    for (final FamilySheetMark mark in FamilySheetMark.values)
      if (!await isMobileTourSeen(taxCode: taxCode, tour: _marker(_sheetSeen(mark)))) mark,
  };

  // The lessons come with the touch on their tab: counted ahead, not dropped.
  final List<MobileTourStep> steps = _sheetSteps(sheet: sheet, row: sheet.row, marks: marks);

  if (!steps.any((step) => step.isPresent) || !sheet.open)
  {
    return;
  }

  final (String, int) first = steps.firstWhere((step) => step.seen != null).seen!;

  await startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(
      slug: first.$1,
      title: kPaymentsTourTitle,
      version: first.$2,
      steps: steps,
      leave: sheet,
      left: () => !sheet.open,
    ),
  );
}

// The «PAGA» sheet's parts never told, the first time it has risen; closed under it, it stops.
// [days]: the first line of several days unfolded, by the touch Avanti makes too; [fold] puts it back.
// [weekend]: online hours at the weekend can be paid ahead in the sheet.
Future<void> startFamilyPayTour({
  required String taxCode,
  required StudentTariffItem? tariff,
  required ValueNotifier<bool> days,
  required VoidCallback fold,
  bool weekend = false,
}) async
{
  bool shown(String id) => isMobileTourTargetShown(id);

  final List<(FamilyPayMark, MobileTourStep)> parts = [
    (
      FamilyPayMark.owed,
      MobileTourStep(
        text: kPayTourOwed,
        shown: const [kFamilyPayTourOwed],
        reveal: kFamilyPayTourOwed,
        high: true,
        scrolls: false,
        present: () => shown(kFamilyPayTourOwed),
        seen: _paySeen(FamilyPayMark.owed),
      ),
    ),
    (
      FamilyPayMark.days,
      MobileTourStep(
        text: kPayTourDaysTap,
        touched: const [kFamilyPayTourDays],
        reveal: kFamilyPayTourDays,
        high: true,
        scrolls: false,
        watch: days,
        reached: () => days.value,
        undo: fold,
        present: () => shown(kFamilyPayTourDays),
        seen: _paySeen(FamilyPayMark.days),
      ),
    ),
    if (tariff != null)
      (
        FamilyPayMark.others,
        MobileTourStep(
          text: payTourOthers(tariff, weekend: weekend),
          shown: const [kFamilyPayTourOthers],
          reveal: kFamilyPayTourOthers,
          high: true,
          scrolls: false,
          present: () => shown(kFamilyPayTourOthers),
          seen: _paySeen(FamilyPayMark.others),
        ),
      ),
    (
      FamilyPayMark.proceed,
      MobileTourStep(
        text: kPayTourProceed,
        shown: const [kFamilyPayTourProceed],
        high: true,
        scrolls: false,
        present: () => shown(kFamilyPayTourProceed),
        seen: _paySeen(FamilyPayMark.proceed),
      ),
    ),
  ];

  final List<MobileTourStep> steps = [];
  (String, int)? first;

  for (final (FamilyPayMark mark, MobileTourStep step) in parts)
  {
    if (step.isPresent && !await isMobileTourSeen(taxCode: taxCode, tour: _marker(_paySeen(mark))))
    {
      steps.add(step);
      first ??= _paySeen(mark);
    }
  }

  final (String, int)? due = first;

  if (due == null)
  {
    return;
  }

  await startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(
      slug: due.$1,
      title: kPaymentsTourTitle,
      version: due.$2,
      steps: steps,
      leave: MobileNavSheet.hidden,
      left: () => !MobileNavSheet.hidden.value,
    ),
  );
}
