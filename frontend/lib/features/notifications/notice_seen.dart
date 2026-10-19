import 'notification_board.dart';
import 'notification_item.dart';

// Opening a notice reads it: the server drops its notification, so the board does too.
Future<void> noticeSeen(int id) async
{
  final NotificationBoard board = NotificationBoard.instance;

  final bool announced = board.items?.any(
        (item) => item.kind == NotificationKind.noticeReceived && item.noticeId == id,
      ) ??
      false;

  if (announced)
  {
    await board.load();
  }
}
