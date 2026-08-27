import 'booking_summary_item.dart';
import 'person_option_item.dart';
import 'presence_item.dart';
import '../../../core/utils/week_range.dart';

// One pupil's request for one day. The backend keeps a row per stretch and
// mode; rows are gathered here into one group and split again on write.
class PresenceGroup
{
  final String studentTaxCode;
  final PersonOptionItem student;
  final PersonOptionItem booker;
  final DateTime date;

  // Day-ordered, never empty: a group exists because its rows do.
  final List<PresenceItem> slots;

  const PresenceGroup({
    required this.studentTaxCode,
    required this.student,
    required this.booker,
    required this.date,
    required this.slots,
  });

  PresenceItem get first => slots.first;

  int get startMinutes => first.startTime.hour * 60 + first.startTime.minute;

  List<PresenceItem> slotsFor(String mode)
  {
    return slots.where((slot) => slot.mode == mode).toList();
  }

  List<BookingSummaryItem> requestsFor(String mode)
  {
    return [
      for (final slot in slotsFor(mode)) ...slot.bookings,
    ];
  }

  int minutesAskedFor(String mode)
  {
    var minutes = 0;

    for (final request in requestsFor(mode))
    {
      minutes += request.duration;
    }

    return minutes;
  }

  // An hour covering three disciplines counts as a full hour of each.
  // [skip] leaves out the row being rewritten by the caller.
  Map<int, int> minutesByDiscipline(String mode, {BookingSummaryItem? skip})
  {
    final minutes = <int, int>{};

    for (final request in requestsFor(mode))
    {
      if (skip != null && request.id == skip.id)
      {
        continue;
      }

      for (final discipline in request.disciplineIds)
      {
        minutes[discipline] = (minutes[discipline] ?? 0) + request.duration;
      }
    }

    return minutes;
  }

  int minutesOfferedIn(String mode)
  {
    var minutes = 0;

    for (final slot in slotsFor(mode))
    {
      minutes += minutesOfTimeOfDay(slot.endTime) - minutesOfTimeOfDay(slot.startTime);
    }

    return minutes;
  }
}

// Groups come out in no particular order; callers sort.
List<PresenceGroup> groupPresences(List<PresenceItem> presences)
{
  final byKey = <String, List<PresenceItem>>{};

  for (final presence in presences)
  {
    final key = '${presence.studentTaxCode}|${presence.date.toIso8601String()}';

    byKey.putIfAbsent(key, () => <PresenceItem>[]).add(presence);
  }

  return byKey.values.map((slots)
  {
    final ordered = [...slots]..sort((a, b)
    {
      return (a.startTime.hour * 60 + a.startTime.minute)
          .compareTo(b.startTime.hour * 60 + b.startTime.minute);
    });

    return PresenceGroup(
      studentTaxCode: ordered.first.studentTaxCode,
      student: ordered.first.student,
      booker: ordered.first.booker,
      date: ordered.first.date,
      slots: ordered,
    );
  }).toList();
}

bool hasPresenceOn(
  List<PresenceItem> presences,
  String studentTaxCode,
  DateTime day,
  String mode,
)
{
  return presences.any((presence) =>
      presence.studentTaxCode == studentTaxCode &&
      presence.mode == mode &&
      isSameDate(presence.date, day));
}
