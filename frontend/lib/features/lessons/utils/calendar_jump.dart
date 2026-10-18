import 'package:flutter/foundation.dart';

import '../../../core/utils/time_bucket.dart';

// A band a calendar is asked to show from outside the page, by a notification.
class CalendarJump
{
  final DateTime day;
  final TimeBucket band;

  const CalendarJump(this.day, this.band);
}

// One pending request: a page not built yet takes it when it starts, one already shown hears of it.
class CalendarJumpChannel
{
  CalendarJump? _pending;

  // The role whose page it is for: another role's, still open while the area switches, leaves it.
  String? _role;

  // Bumped on every request.
  final ValueNotifier<int> asked = ValueNotifier<int>(0);

  bool get isPending => _pending != null;

  void request(DateTime day, TimeBucket band, {String? role})
  {
    _pending = CalendarJump(DateTime(day.year, day.month, day.day), band);
    _role = role;
    asked.value++;
  }

  CalendarJump? take({String? role})
  {
    if (_role != null && role != null && role != _role)
    {
      return null;
    }

    final CalendarJump? jump = _pending;
    _pending = null;

    return jump;
  }
}

abstract final class CalendarJumps
{
  // The administrator's Lezioni calendar.
  static final CalendarJumpChannel admin = CalendarJumpChannel();

  // The teachers', parents' and students' calendars.
  static final CalendarJumpChannel role = CalendarJumpChannel();
}
