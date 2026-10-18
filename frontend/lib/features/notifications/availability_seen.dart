import '../../services/api_service.dart';
import 'notification_board.dart';
import 'notification_item.dart';

const Set<NotificationKind> _availabilityKinds = {
  NotificationKind.availabilityAdded,
  NotificationKind.availabilityChanged,
  NotificationKind.availabilityCancelled,
};

// Being asked now: a page redrawn meanwhile does not ask twice.
final Set<String> _asked = {};

// A week of one's own availabilities on screen, from its Monday: what others wrote in it is seen.
Future<void> markAvailabilitySeen(DateTime monday) async
{
  // Read by the home, or by the tap that opened the app: not asked for here.
  final NotificationBoard board = NotificationBoard.instance;
  final DateTime from = DateTime(monday.year, monday.month, monday.day);
  final DateTime to = from.add(const Duration(days: 6));

  final bool announced = board.items?.any(
        (item) =>
            _availabilityKinds.contains(item.kind) &&
            item.calendarDate != null &&
            !item.calendarDate!.isBefore(from) &&
            !item.calendarDate!.isAfter(to),
      ) ??
      false;

  final String key = '${from.year}-${from.month}-${from.day}';

  if (!announced || !_asked.add(key))
  {
    return;
  }

  try
  {
    await ApiService().markAvailabilitySeen(from, to);
    await board.load();
  }
  catch (_)
  {
    // Asked again the next time the week is on screen.
  }
  finally
  {
    _asked.remove(key);
  }
}
