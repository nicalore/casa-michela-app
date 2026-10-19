import 'package:flutter/foundation.dart';

// Pending week to show: a page not built yet takes it on start, a shown one listens.
class WeekJumpChannel
{
  DateTime? _pending;

  // Target role: another role's page, still open while the area switches, leaves it.
  String? _role;

  // The child to show, on a page that shows one at a time.
  String? _pupil;

  // Bumped on every request.
  final ValueNotifier<int> asked = ValueNotifier<int>(0);

  bool get isPending => _pending != null;

  void request(DateTime day, {String? role, String? pupil})
  {
    _pending = DateTime(day.year, day.month, day.day);
    _role = role;
    _pupil = pupil;
    asked.value++;
  }

  DateTime? take({String? role}) => takeFor(role: role)?.day;

  ({DateTime day, String? pupil})? takeFor({String? role})
  {
    final DateTime? day = _pending;

    if (day == null || _role != null && role != null && role != _role)
    {
      return null;
    }

    _pending = null;

    return (day: day, pupil: _pupil);
  }
}

abstract final class WeekJumps
{
  // The teachers' "Disponibilità".
  static final WeekJumpChannel availability = WeekJumpChannel();

  // The parents' and students' "Prenotazioni".
  static final WeekJumpChannel bookings = WeekJumpChannel();

  // The "Orari" of every role's "Associazione".
  static final WeekJumpChannel hours = WeekJumpChannel();
}
