import 'notification_board.dart';
import 'notification_item.dart';

// A notice opened is a notice read: the server has taken away what announced it, the card follows.
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
