import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../core/utils/rome_clock.dart';
import 'models/student_payments_item.dart';
import 'payments_tour_texts.dart';
import 'utils/payments_strings.dart' show paymentsByYear;

// Parents' and pupils' Pagamenti: the page, a payment's window, the «PAGA» window.
const String kTourFamilyChildren = 'payments.children';
const String kTourFamilyTariff = 'payments.tariff';
const String kTourFamilyStatus = 'payments.status';
const String kTourFamilyPay = 'payments.pay';
const String kTourFamilyHistory = 'payments.history';
const String kTourFamilyEmpty = 'payments.empty';
const String kTourFamilyRow = 'payments.row';
const String kTourFamilyToOwn = 'payments.tab.own';
const String kTourFamilyOwnHistory = 'payments.own.history';
const String kTourFamilyOwnEmpty = 'payments.own.empty';
const String kTourPaymentFacts = 'payments.window.facts';
const String kTourPaymentLessons = 'payments.window.lessons';
const String kTourPaymentClose = 'payments.window.close';
const String kTourPayOwed = 'payments.paying.owed';
const String kTourPayDays = 'payments.paying.days';
const String kTourPayOthers = 'payments.paying.others';
const String kTourPayTotal = 'payments.paying.total';
const String kTourPayButton = 'payments.paying.button';

// The member parent's «Personali» on show: the tour's click waits for it.
final ValueNotifier<bool> familyOwnShown = ValueNotifier(false);

// A payment's window open (its row), and the way to close it when the tour steps back.
final ValueNotifier<PaymentHistoryRow?> familyPaymentWindow = ValueNotifier(null);
VoidCallback? familyPaymentWindowCloser;

const String _parentRole = 'PARENT';
const String _studentRole = 'STUDENT';

// Bump a version on every change to that tour.
const (String, int) _parentSeen = ('payments.parent', 3);
const (String, int) _studentSeen = ('payments.student', 3);

// Parts told the first time they show, in the page's tour or alone later.
const (String, int) _tariffSeen = ('payments.mark.tariff', 2);
const (String, int) _statusSeen = ('payments.mark.status', 2);
const (String, int) _paySeen = ('payments.mark.pay', 2);
const (String, int) _historySeen = ('payments.mark.history', 2);
const (String, int) _emptySeen = ('payments.mark.empty', 1);
const (String, int) _factsSeen = ('payments.mark.facts', 1);
const (String, int) _lessonsSeen = ('payments.mark.lessons', 1);
const (String, int) _owedSeen = ('payments.mark.paying.owed', 2);
const (String, int) _daysSeen = ('payments.mark.paying.days', 1);
// 2: online hours at the weekend paid ahead.
const (String, int) _othersSeen = ('payments.mark.paying.others', 2);
const (String, int) _proceedSeen = ('payments.mark.paying.proceed', 1);

const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];
const List<DesktopTourSide> _leftFirst = [DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above];
const List<DesktopTourSide> _belowOrLeft = [DesktopTourSide.below, DesktopTourSide.left];

bool _shown(String id) => isDesktopTourTargetShown(id);

String? get _reader
{
  final identity = ApiService().lastKnownIdentity;

  return identity?.activeRole == _parentRole || identity?.activeRole == _studentRole ? identity?.taxCode : null;
}

bool get _self => ApiService().lastKnownIdentity?.activeRole == _studentRole;

void startFamilyPaymentsTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = _reader;

  if (taxCode == null)
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

Future<bool> _seen(String taxCode, (String, int) mark)
{
  final (String slug, int version) = mark;

  return isDesktopTourSeen(
    taxCode: taxCode,
    tour: DesktopTour(slug: slug, title: kPaymentsTourTitle, version: version, steps: const []),
  );
}

// The payment the tour opens: the table's first, paid or still to pay.
PaymentHistoryRow? familyTouredRow(List<PaymentHistoryRow> history)
{
  return paymentsByYear(history, romeNow().year).values.expand((rows) => rows).firstOrNull;
}

void _closeWindow() => familyPaymentWindowCloser?.call();

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
DesktopTourStep _tariffStep({required bool self, String? gender}) => DesktopTourStep(
  targets: const [kTourFamilyTariff],
  text: paymentsTourTariff(self: self, gender: gender),
  sides: _below,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourFamilyTariff),
  seen: _tariffSeen,
);

DesktopTourStep _statusStep({required bool self, String? gender}) => DesktopTourStep(
  targets: const [kTourFamilyStatus],
  text: paymentsTourStatus(self: self, gender: gender),
  sides: _below,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourFamilyStatus),
  seen: _statusSeen,
);

// Lit only: paying is the person's own choice.
DesktopTourStep _payStep(StudentTariffItem? tariff) => DesktopTourStep(
  targets: const [kTourFamilyPay],
  text: paymentsTourPay(tariff),
  sides: _leftFirst,
  pad: 6,
  radius: 17,
  reveal: true,
  present: () => _shown(kTourFamilyPay),
  seen: _paySeen,
);

DesktopTourStep _historyStep({required bool self, String? gender}) => DesktopTourStep(
  targets: const [kTourFamilyHistory],
  text: paymentsTourHistory(self: self, gender: gender),
  sides: _over,
  pad: 8,
  radius: 36,
  reveal: true,
  present: () => _shown(kTourFamilyHistory),
  seen: _historySeen,
);

DesktopTourStep _emptyStep({required bool self, String? gender}) => DesktopTourStep(
  targets: const [kTourFamilyEmpty],
  text: paymentsTourEmpty(self: self, gender: gender),
  sides: _beside,
  // AppEmptyCard's corner 28 + half the pad.
  pad: 8,
  radius: 32,
  reveal: true,
  present: () => _shown(kTourFamilyEmpty),
  seen: _emptySeen,
);

// The window's two cards; the first one back closes it.
DesktopTourStep _factsStep({VoidCallback? undo, bool Function()? coming}) => DesktopTourStep(
  targets: const [kTourPaymentFacts],
  text: kPaymentsTourFacts,
  sides: _beside,
  pad: 6,
  radius: 31,
  listen: familyPaymentWindow,
  gone: () => familyPaymentWindow.value == null,
  undo: undo,
  present: () => familyPaymentWindow.value != null && _shown(kTourPaymentFacts),
  coming: coming,
  seen: _factsSeen,
);

DesktopTourStep _lessonsStep(PaymentHistoryRow row, {bool Function()? coming}) => DesktopTourStep(
  targets: const [kTourPaymentLessons],
  text: paymentsTourLessons(row),
  sides: _beside,
  pad: 6,
  radius: 31,
  reveal: true,
  listen: familyPaymentWindow,
  gone: () => familyPaymentWindow.value == null,
  present: () => familyPaymentWindow.value != null && _shown(kTourPaymentLessons),
  coming: coming,
  seen: _lessonsSeen,
);

// [genders]: every child's; [gender]: the child shown; [tariff]: theirs.
// [row]: the payment the tour opens, [openRow] opens it again when the tour steps back into its window.
// [member]: the parent's own fees in «Personali», after the window; [showChild] turns the page back.
Future<DesktopTour?> familyPaymentsPageTour({
  required List<String?> genders,
  required String? gender,
  required StudentTariffItem? tariff,
  required PaymentHistoryRow? row,
  required VoidCallback openRow,
  required bool member,
  required VoidCallback showChild,
}) async
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return null;
  }

  final bool self = _self;
  final (String slug, int version) = self ? _studentSeen : _parentSeen;

  if (await _seen(taxCode, (slug, version)))
  {
    return null;
  }

  // Stepping back into the window closed by its ×: it opens again.
  void reopen()
  {
    if (familyPaymentWindow.value == null)
    {
      openRow();
    }
  }

  return DesktopTour(
    slug: slug,
    title: kPaymentsTourTitle,
    version: version,
    steps: [
      DesktopTourStep(text: kPaymentsTourIntro),
      if (!self && genders.length > 1)
        DesktopTourStep(
          targets: const [kTourFamilyChildren],
          text: paymentsTourChildren(genders),
          sides: _beside,
          pad: 6,
          radius: 31,
          present: () => _shown(kTourFamilyChildren),
        ),
      _tariffStep(self: self, gender: gender),
      _statusStep(self: self, gender: gender),
      _payStep(tariff),
      _historyStep(self: self, gender: gender),
      _emptyStep(self: self, gender: gender),
      // The child's first payment opens its window, told there; its × brings the page back.
      if (row != null) ...[
        DesktopTourStep(
          targets: const [kTourFamilyRow],
          text: kPaymentsTourOpenClick,
          sides: _beside,
          pad: 4,
          radius: 12,
          reveal: true,
          listen: familyPaymentWindow,
          reached: () => familyPaymentWindow.value != null,
          present: () => _shown(kTourFamilyRow),
        ),
        _factsStep(undo: _closeWindow, coming: () => true),
        if (row.lessons.isNotEmpty) _lessonsStep(row, coming: () => true),
        DesktopTourStep(
          targets: const [kTourPaymentClose],
          text: kPaymentsTourCloseClick,
          sides: _belowOrLeft,
          // The round × (44, dense 40): half its side + half the pad.
          pad: 4,
          radius: 24,
          listen: familyPaymentWindow,
          reached: () => familyPaymentWindow.value == null,
          present: () => familyPaymentWindow.value != null && _shown(kTourPaymentClose),
          coming: () => true,
        ),
      ],
      if (member) ...[
        DesktopTourStep(
          targets: const [kTourFamilyToOwn],
          text: kPaymentsTourToOwnClick,
          sides: _beside,
          // The entry spans the rail: the hole keeps inside its edges.
          pad: 0,
          radius: 12,
          listen: familyOwnShown,
          reached: () => familyOwnShown.value,
          undo: row == null ? null : reopen,
          present: () => _shown(kTourFamilyToOwn),
        ),
        DesktopTourStep(
          targets: const [kTourFamilyOwnHistory, kTourFamilyOwnEmpty],
          text: kPaymentsTourOwn,
          sides: _over,
          pad: 8,
          radius: 36,
          reveal: true,
          undo: showChild,
          present: () => familyOwnShown.value,
          coming: () => true,
        ),
      ],
    ],
  );
}

// Parts first shown after the page's tour: a «PAGA» come later, a status, the history.
Future<DesktopTour?> familyPaymentsLateTour({required String? gender, required StudentTariffItem? tariff}) async
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return null;
  }

  final bool self = _self;

  if (!await _seen(taxCode, self ? _studentSeen : _parentSeen))
  {
    return null;
  }

  return dueDesktopTour(
    taxCode: taxCode,
    title: kPaymentsTourTitle,
    steps: [
      _tariffStep(self: self, gender: gender),
      _statusStep(self: self, gender: gender),
      _payStep(tariff),
      _historyStep(self: self, gender: gender),
      _emptyStep(self: self, gender: gender),
    ],
  );
}

// A payment's window opened outside the page's tour: its cards never told.
Future<DesktopTour?> familyPaymentWindowTour(PaymentHistoryRow row) async
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return null;
  }

  return dueDesktopTour(
    taxCode: taxCode,
    title: kPaymentsTourTitle,
    steps: [_factsStep(), if (row.lessons.isNotEmpty) _lessonsStep(row)],
  );
}

// The «PAGA» window's parts, each told the first time it shows; [weekend] while online hours at the weekend can be
// paid ahead in it.
Future<DesktopTour?> familyPayWindowTour(StudentTariffItem? tariff, {bool weekend = false}) async
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return null;
  }

  return dueDesktopTour(
    taxCode: taxCode,
    title: kPaymentsTourTitle,
    steps: [
      DesktopTourStep(
        targets: const [kTourPayOwed],
        text: kPayTourOwed,
        sides: _beside,
        pad: 6,
        radius: 12,
        present: () => _shown(kTourPayOwed),
        seen: _owedSeen,
      ),
      DesktopTourStep(
        targets: const [kTourPayDays],
        text: kPayTourDaysClick,
        sides: _beside,
        pad: 4,
        radius: 10,
        present: () => _shown(kTourPayDays),
        seen: _daysSeen,
      ),
      if (tariff != null)
        DesktopTourStep(
          targets: const [kTourPayOthers],
          text: payTourOthers(tariff, weekend: weekend),
          sides: _beside,
          pad: 6,
          radius: 12,
          present: () => _shown(kTourPayOthers),
          seen: _othersSeen,
        ),
      DesktopTourStep(
        targets: const [kTourPayTotal, kTourPayButton],
        apart: true,
        radii: const [12, 17],
        text: kPayTourProceed,
        sides: _beside,
        pad: 6,
        radius: 12,
        present: () => _shown(kTourPayButton),
        seen: _proceedSeen,
      ),
    ],
  );
}
