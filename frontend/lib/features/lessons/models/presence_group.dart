import 'booking_summary_item.dart';
import 'person_option_item.dart';
import 'presence_item.dart';
import '../../../core/utils/week_range.dart';

// One pupil's request for one day, however many stretches of hours and
// whichever way of being there it is made of.
//
// The backend keeps a row per stretch and per mode, because a row is what has a
// start, an end and a way. What the association means by "a request", though,
// is a pupil asking for a day — two hours in the building in the
// afternoon and one online in the evening are one answer to one question, and
// they belong on one card. So the rows are gathered here on the way out of the
// API and taken apart again on the way back in.
class PresenceGroup
{
  final String studentTaxCode;
  final PersonOptionItem student;
  final PersonOptionItem booker;
  final DateTime date;

  // Every stretch the pupil gave that day, both ways of being there, in the
  // order of the day. Never empty: a group exists because its rows do.
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

  /// The stretches given one way, in the order of the day. Empty where the
  /// pupil did not ask for that way at all.
  List<PresenceItem> slotsFor(String mode)
  {
    return slots.where((slot) => slot.mode == mode).toList();
  }

  /// And what was asked for inside them. A subject hangs off one of the
  /// stretches of its mode; which one is the timetable's business, not the
  /// reader's, so they are gathered.
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

  /// The same reckoning, discipline by discipline: an hour covering three of
  /// them is an hour of each and not a third apiece, because what it spends of
  /// a discipline is the whole lesson.
  ///
  /// [skip] leaves one row out — the one being rewritten in a window that counts
  /// its own duration itself. A service is on no discipline and adds to none.
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

  // And how much time there is to spend in that mode: the stretches the pupil
  // asked for, added up. It is the ceiling of what can be put inside, and
  // without it a duration is a number with nothing to be measured against.
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

/// The rows gathered by pupil and day, each group's slots in the order of the
/// day. The groups themselves come out in no particular order: the tab sorts
/// them by whatever it is showing them for.
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

/// Whether the pupil already asked for that day in that mode, whatever hours
/// they gave.
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
