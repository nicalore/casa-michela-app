import 'dart:async';

import '../../core/utils/time_bucket.dart';
import '../../services/api_service.dart';
import 'notification_board.dart';
import 'notification_item.dart';

const Set<NotificationKind> _calendarKinds = {NotificationKind.calendarPublished, NotificationKind.convocation};

// Being asked now: a calendar redrawn meanwhile does not ask twice.
final Set<String> _asked = {};

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// A published band on screen has done the work of what announced it: that notice goes.
Future<void> markCalendarSeen(DateTime day, TimeBucket band) async
{
  // Read by the home, or by the tap that opened the app: not asked for here.
  final NotificationBoard board = NotificationBoard.instance;

  final bool announced = board.items?.any(
        (item) =>
            _calendarKinds.contains(item.kind) &&
            item.calendarBand == band &&
            item.calendarDate != null &&
            _sameDay(item.calendarDate!, day),
      ) ??
      false;

  final String key = '${day.year}-${day.month}-${day.day}/${band.name}';

  if (!announced || !_asked.add(key))
  {
    return;
  }

  try
  {
    await ApiService().markCalendarSeen(day, band);
    await board.load();
  }
  catch (_)
  {
    // Asked again the next time the band is on screen.
  }
  finally
  {
    _asked.remove(key);
  }
}
