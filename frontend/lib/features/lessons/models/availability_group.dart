import 'availability_item.dart';
import 'person_option_item.dart';
import '../utils/booking_window.dart';

// One teacher's availability on one day, however many stretches of hours and
// whichever way of being there it is made of.
//
// The backend keeps a row per stretch and per mode, because a row is what has a
// start, an end and a way. What the association means by "an availability",
// though, is a teacher being there on a day — the two hours in the building in
// the morning and the two online in the evening are one answer to one question,
// and they belong on one card. So the rows are gathered here on the way out of
// the API and taken apart again on the way back in.
class AvailabilityGroup
{
  final String teacherTaxCode;
  final PersonOptionItem teacher;
  final DateTime date;

  // Every stretch the teacher gave that day, both ways of being there, in the
  // order of the day. Never empty: a group exists because its rows do.
  final List<AvailabilityItem> slots;

  const AvailabilityGroup({
    required this.teacherTaxCode,
    required this.teacher,
    required this.date,
    required this.slots,
  });

  AvailabilityItem get first => slots.first;

  int get startMinutes => first.startTime.hour * 60 + first.startTime.minute;

  // The stretches offered one way, in the order of the day. Empty where the
  // teacher did not offer that way at all.
  List<AvailabilityItem> slotsFor(String mode)
  {
    return slots.where((slot) => slot.mode == mode).toList();
  }
}

// The rows gathered by teacher and day, each group's slots in the order of the
// day. The groups themselves come out in no particular order: the tab sorts
// them by whatever it is showing them for.
List<AvailabilityGroup> groupAvailabilities(List<AvailabilityItem> availabilities)
{
  final byKey = <String, List<AvailabilityItem>>{};

  for (final availability in availabilities)
  {
    final key = '${availability.teacherTaxCode}|${availability.date.toIso8601String()}';

    byKey.putIfAbsent(key, () => <AvailabilityItem>[]).add(availability);
  }

  return byKey.values.map((slots)
  {
    final ordered = [...slots]..sort((a, b)
    {
      return (a.startTime.hour * 60 + a.startTime.minute)
          .compareTo(b.startTime.hour * 60 + b.startTime.minute);
    });

    return AvailabilityGroup(
      teacherTaxCode: ordered.first.teacherTaxCode,
      teacher: ordered.first.teacher,
      date: ordered.first.date,
      slots: ordered,
    );
  }).toList();
}

// Whether the teacher already stands on that day in that mode, whatever hours
// they gave.
bool hasAvailabilityOn(
  List<AvailabilityItem> availabilities,
  String teacherTaxCode,
  DateTime day,
  String mode,
)
{
  return availabilities.any((availability) =>
      availability.teacherTaxCode == teacherTaxCode &&
      availability.mode == mode &&
      isSameDate(availability.date, day));
}
