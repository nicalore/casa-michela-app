import 'availability_item.dart';
import 'person_option_item.dart';
import '../utils/booking_window.dart';

// One teacher's availability on one day. The backend keeps a row per stretch
// and mode; rows are gathered here into one group and split again on write.
class AvailabilityGroup
{
  final String teacherTaxCode;
  final PersonOptionItem teacher;
  final DateTime date;

  // Day-ordered, never empty: a group exists because its rows do.
  final List<AvailabilityItem> slots;

  const AvailabilityGroup({
    required this.teacherTaxCode,
    required this.teacher,
    required this.date,
    required this.slots,
  });

  AvailabilityItem get first => slots.first;

  int get startMinutes => first.startTime.hour * 60 + first.startTime.minute;

  List<AvailabilityItem> slotsFor(String mode)
  {
    return slots.where((slot) => slot.mode == mode).toList();
  }
}

// Groups come out in no particular order; callers sort.
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
