import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart';
import 'payment_dialog_parts.dart' show paymentToday;
import 'settle_items.dart';

// The tariff bought again as it stands: what, how much, from when; and the hours it takes over at once.
class FamilyRenewal
{
  final String title;
  final String detail;
  final String when;
  final String? note;
  // Starting when the running package or the paid month ends.
  final bool later;
  final int cents;

  // The line it pays for itself, and on which days: «Le ore non pagate verranno scalate immediatamente».
  final String? covers;
  final Set<DateTime> coveredDays;
  final String? coverNote;

  const FamilyRenewal({
    required this.title,
    required this.detail,
    required this.when,
    this.note,
    required this.later,
    required this.cents,
    this.covers,
    this.coveredDays = const {},
    this.coverNote,
  });
}

DateTime _dayOf(DateTime day) => DateTime(day.year, day.month, day.day);

// As the admin's renewal: a package or a month, never while the set-up waits or another is queued.
FamilyRenewal? familyRenewalOf(StudentPaymentsItem payments)
{
  final StudentTariffItem? tariff = payments.tariff;

  if (tariff == null || tariff.isHourly || payments.readOnly || payments.openingPending || payments.queued != null)
  {
    return null;
  }

  final DateTime today = paymentToday();

  if (tariff.isPackage)
  {
    final PackageStatusItem? package = payments.package;

    if (package != null && package.running)
    {
      return FamilyRenewal(
        title: kRenewPackageTitle,
        detail: packageTitle(tariff.packageHours ?? 0),
        when: kAtPackageEnd,
        note: stillLeft(package.leftMinutes),
        later: true,
        cents: tariff.amountCents,
      );
    }

    final List<LessonPartItem> over = [
      for (final LessonPartItem part in payments.line('OVER_PACKAGE')?.parts ?? const <LessonPartItem>[])
        if (part.current) part,
    ];

    return FamilyRenewal(
      title: kRenewPackageTitle,
      detail: packageTitle(tariff.packageHours ?? 0),
      when: startsFromDay(over.isEmpty ? today : over.first.day),
      later: false,
      cents: tariff.amountCents,
      covers: over.isEmpty ? null : 'OVER_PACKAGE',
      coveredDays: {for (final part in over) _dayOf(part.day)},
      coverNote: over.isEmpty ? null : kUnsettledTakenNow,
    );
  }

  final DateTime month = DateTime(today.year, today.month);
  final bool paid = payments.monthPaid(today);
  final DateTime bought = paid ? DateTime(month.year, month.month + 1) : month;

  // This month bought now: its hours over the fee are paid by it.
  final List<LessonPartItem> over = paid
      ? const []
      : [
          for (final LessonPartItem part in payments.line('OVER_FEE')?.parts ?? const <LessonPartItem>[])
            if (part.current && part.day.year == today.year && part.day.month == today.month) part,
        ];
  final int covered = over.fold(0, (sum, part) => sum + part.minutes);

  return FamilyRenewal(
    title: kRenewMonthTitle,
    detail: feeTitle(bought),
    when: startsFromMonth(bought),
    later: paid,
    cents: tariff.amountCents,
    covers: over.isEmpty ? null : 'OVER_FEE',
    coveredDays: {for (final part in over) _dayOf(part.day)},
    coverNote: covered > 0 ? coveredByFee(covered) : null,
  );
}

// Hours paid ahead: an hourly tariff, nothing waiting.
bool familyPaysAhead(StudentPaymentsItem payments)
{
  final StudentTariffItem? tariff = payments.tariff;

  return tariff != null && tariff.isHourly && !payments.readOnly && !payments.openingPending && payments.queued == null;
}

// Online at the weekend paid ahead: any tariff, at its own rate, whatever waits.
bool familyPaysWeekendAhead(StudentPaymentsItem payments)
{
  return payments.tariff != null &&
      payments.weekendOnlineCents != null &&
      !payments.readOnly &&
      !payments.openingPending;
}

// «PAGA» on the status card: anything owed, or the tariff to renew or pay ahead.
bool familyCanPay(StudentPaymentsItem payments)
{
  return hasSomethingToSettle(payments) ||
      familyRenewalOf(payments) != null ||
      familyPaysAhead(payments) ||
      familyPaysWeekendAhead(payments);
}

// What a family ticks before Stripe: owed items day by day, the renewal, hours ahead; the total as the server
// would price it. A ticked renewal or hours ahead take the hours they pay for out of what is owed.
class FamilyPayChoice
{
  final StudentPaymentsItem payments;

  final List<SettleItem> items;

  // For each item the indices of its ticked days; a fee has one.
  final List<Set<int>> ticked;

  final FamilyRenewal? renewal;
  bool renewalTicked;

  final bool ahead;
  bool aheadTicked = false;
  int aheadMinutes = 0;

  final bool weekendAhead;
  bool weekendAheadTicked = false;
  int weekendAheadMinutes = 0;

  // Hours ahead take the unsettled hourly lessons at once.
  late final Set<DateTime> _aheadCovers = {
    for (final LessonPartItem part in payments.line('HOURLY')?.parts ?? const <LessonPartItem>[])
      if (part.current) _dayOf(part.day),
  };

  // Online at the weekend, under no tariff: every unsettled one.
  late final Set<DateTime> _weekendCovers = {
    for (final LessonPartItem part in payments.line('WEEKEND_ONLINE')?.parts ?? const <LessonPartItem>[])
      _dayOf(part.day),
  };

  // What is owed starts ticked; the renewal too when it is due.
  FamilyPayChoice(this.payments)
      : items = settleItemsOf(payments),
        ticked = [
          for (final SettleItem item in settleItemsOf(payments)) {for (var i = 0; i < item.count; i++) i},
        ],
        renewal = familyRenewalOf(payments),
        renewalTicked = payments.state == PaymentState.renew && familyRenewalOf(payments) != null,
        ahead = familyPaysAhead(payments),
        weekendAhead = familyPaysWeekendAhead(payments);

  bool get anything => items.isNotEmpty || renewal != null || ahead || weekendAhead;

  // Paid by the ticked renewal or hours ahead: not ticked, not counted, not touchable.
  bool covered(int item, int day)
  {
    final SettleItem settle = items[item];
    final HoursLineItem? line = settle.line;

    if (line == null)
    {
      return false;
    }

    final DateTime date = settle.days[day].day;
    final FamilyRenewal? renewal = this.renewal;

    if (renewalTicked && renewal != null && renewal.covers == line.kind && renewal.coveredDays.contains(date))
    {
      return true;
    }

    if (weekendAheadTicked && line.kind == 'WEEKEND_ONLINE' && _weekendCovers.contains(date))
    {
      return true;
    }

    return aheadTicked && line.kind == 'HOURLY' && _aheadCovers.contains(date) && settle.days[day].current;
  }

  // Why the covered days of an item are not to tick.
  String coverNote(int item)
  {
    final FamilyRenewal? renewal = this.renewal;

    if (renewalTicked && renewal != null && renewal.covers == items[item].line?.kind)
    {
      return renewal.coverNote ?? kUnsettledTakenNow;
    }

    return kUnsettledTakenNow;
  }

  bool wholeCovered(int item) => [for (var i = 0; i < items[item].count; i++) covered(item, i)].every((each) => each);

  // The ticked days left once the covered ones are out.
  Set<int> chosen(int item) => {for (final i in ticked[item]) if (!covered(item, i)) i};

  int cents(int item)
  {
    final SettleItem settle = items[item];
    final Set<int> days = chosen(item);

    if (settle.fee != null)
    {
      return days.isEmpty ? 0 : settle.fee!.amountCents;
    }

    return [for (final i in days) settle.days[i].cents].fold(0, (a, b) => a + b);
  }

  int get aheadCents =>
      aheadTicked && aheadMinutes > 0 ? settleHourCents(aheadMinutes, payments.tariff!.amountCents) : 0;

  int get weekendAheadCents => weekendAheadTicked && weekendAheadMinutes > 0
      ? settleHourCents(weekendAheadMinutes, payments.weekendOnlineCents ?? 0)
      : 0;

  int get total =>
      [for (var i = 0; i < items.length; i++) cents(i)].fold(0, (a, b) => a + b) +
      (renewalTicked && renewal != null ? renewal!.cents : 0) +
      aheadCents +
      weekendAheadCents;

  String? get aheadNote => aheadTicked && _aheadCovers.isNotEmpty ? kUnsettledTakenNow : null;

  String? get weekendAheadNote => weekendAheadTicked && _weekendCovers.isNotEmpty ? kUnsettledTakenNow : null;

  void toggleItem(int item)
  {
    final List<int> free = [for (var i = 0; i < items[item].count; i++) if (!covered(item, i)) i];
    final bool all = free.every(ticked[item].contains);

    if (all)
    {
      ticked[item].removeAll(free);
    }
    else
    {
      ticked[item].addAll(free);
    }
  }

  void toggleDay(int item, int day)
  {
    if (covered(item, day))
    {
      return;
    }

    if (!ticked[item].remove(day))
    {
      ticked[item].add(day);
    }
  }
}
