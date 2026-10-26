import '../../core/utils/week_range.dart';
import '../../services/api_service.dart';
import 'notification_board.dart';
import 'notification_item.dart';

const Set<NotificationKind> _bookingKinds = {
  NotificationKind.bookingAdded,
  NotificationKind.bookingCancelled,
  NotificationKind.bookingChanged,
};

// Being asked now: a page redrawn meanwhile does not ask twice.
final Set<String> _asked = {};

// Pupil's week on screen, from its Monday: others' bookings, changes and cancellations seen.
Future<void> markBookingsSeen(String pupilTaxCode, DateTime monday) async
{
  // The board is loaded by the home or by the opening tap; this does not fetch it.
  final NotificationBoard board = NotificationBoard.instance;
  final DateTime from = DateTime(monday.year, monday.month, monday.day);
  final DateTime to = addDays(from, 6);

  final bool announced = board.items?.any(
        (item) =>
            _bookingKinds.contains(item.kind) &&
            item.pupilTaxCode == pupilTaxCode &&
            item.calendarDate != null &&
            !item.calendarDate!.isBefore(from) &&
            !item.calendarDate!.isAfter(to),
      ) ??
      false;

  final String key = '$pupilTaxCode/${from.year}-${from.month}-${from.day}';

  if (!announced || !_asked.add(key))
  {
    return;
  }

  try
  {
    await ApiService().markBookingsSeen(pupilTaxCode, from, to);
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
