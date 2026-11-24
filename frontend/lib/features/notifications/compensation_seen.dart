import '../../services/api_service.dart';
import 'notification_board.dart';
import 'notification_item.dart';

// Being asked now: a page redrawn meanwhile does not ask twice.
bool _asking = false;

// One's own Compensi on screen, on [month]: the news of a changed unpaid hour goes,
// and that of the month's receipt.
Future<void> markCompensationSeen(DateTime month) async
{
  // A board not read yet may still hold one: the server is asked all the same.
  final NotificationBoard board = NotificationBoard.instance;

  bool tells(NotificationItem item)
  {
    final DateTime? day = item.calendarDate;

    return item.kind == NotificationKind.volunteeringChanged ||
        (item.kind == NotificationKind.paymentReceiptAvailable &&
            day != null &&
            day.year == month.year &&
            day.month == month.month);
  }

  final bool announced = board.items?.any(tells) ?? true;

  if (!announced || _asking)
  {
    return;
  }

  _asking = true;

  try
  {
    await ApiService().markCompensationSeen(month);
    await board.load();
  }
  catch (_)
  {
    // Asked again the next time the month is shown.
  }
  finally
  {
    _asking = false;
  }
}
