import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart';

// Half a cent goes up, as the server works it out.
int settleHourCents(int minutes, int centsPerHour) => (minutes * centsPerHour * 2 + 60) ~/ 120;

// One day of a line of hours: its lessons together.
class SettleDay
{
  final DateTime day;
  final int minutes;
  // At the line's own rate.
  final int cents;
  final bool opening;
  // Under the tariff in force: what a renewal or hours ahead may take.
  final bool current;

  const SettleDay({
    required this.day,
    required this.minutes,
    required this.cents,
    required this.opening,
    required this.current,
  });
}

// A line of hours with its days, or an annual fee owed.
class SettleItem
{
  // «Ore online nel weekend», «Assicurazione 2026».
  final String name;
  // The name with the hours: «Ore online nel weekend: 3h».
  final String title;
  final String? period;
  final HoursLineItem? line;
  final List<SettleDay> days;
  final PaymentHistoryRow? fee;

  const SettleItem({
    required this.name,
    required this.title,
    this.period,
    this.line,
    this.days = const [],
    this.fee,
  });

  // Online at the weekend keeps its own rate.
  bool get rateEditable => line != null && !line!.isWeekendOnline;

  int get count => line == null ? 1 : days.length;

  int get cents => line?.cents ?? fee!.amountCents;
}

List<SettleItem> settleItemsOf(StudentPaymentsItem payments)
{
  return [
    // Hours wait for the initial set-up; fees are paid whatever it says.
    if (!payments.openingPending)
      for (final HoursLineItem line in payments.lines)
        if (line.cents > 0 && line.parts.isNotEmpty)
          SettleItem(
            name: kHoursTitles[line.kind] ?? '',
            title: '${kHoursTitles[line.kind] ?? ''}: ${hoursText(line.minutes).replaceAll(' ', ' ')}',
            period: lessonDaysText([for (final part in line.parts) part.day], interleaved: line.interleaved),
            line: line,
            days: _daysOf(line),
          ),
    for (final PaymentHistoryRow row in payments.history)
      if (row.isFee && !row.isPaid && row.feeId != null)
        SettleItem(
          name: annualFeeTitle(row),
          title: annualFeeTitle(row),
          period: row.recordedOn == null ? null : feeDueSince(row.recordedOn!),
          fee: row,
        ),
  ];
}

List<SettleDay> _daysOf(HoursLineItem line)
{
  final Map<DateTime, List<LessonPartItem>> byDay = {};

  for (final LessonPartItem part in line.parts)
  {
    byDay.putIfAbsent(DateTime(part.day.year, part.day.month, part.day.day), () => []).add(part);
  }

  final List<DateTime> days = byDay.keys.toList()..sort();

  return [
    for (final DateTime day in days)
      SettleDay(
        day: day,
        minutes: byDay[day]!.fold(0, (sum, part) => sum + part.minutes),
        cents: byDay[day]!.fold(0, (sum, part) => sum + part.cents),
        opening: byDay[day]!.every((part) => part.opening),
        current: byDay[day]!.every((part) => part.current),
      ),
  ];
}

// Something to settle: the status card shows «SALDA» only then.
bool hasSomethingToSettle(StudentPaymentsItem payments) => settleItemsOf(payments).isNotEmpty;
