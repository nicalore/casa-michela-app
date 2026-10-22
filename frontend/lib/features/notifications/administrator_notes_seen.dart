import '../../services/api_service.dart';
import 'notification_board.dart';
import 'notification_item.dart';

// Being asked now: a page redrawn meanwhile does not ask twice.
bool _asking = false;

// One's own Osservazioni on screen: the news of administrators' new notes goes.
Future<void> markAdministratorNotesSeen() async
{
  // A board not read yet may still hold one: the server is asked all the same.
  final NotificationBoard board = NotificationBoard.instance;

  final bool announced = board.items?.any((item) => item.kind == NotificationKind.administratorNoteAdded) ?? true;

  if (!announced || _asking)
  {
    return;
  }

  _asking = true;

  try
  {
    await ApiService().markAdministratorNotesSeen();
    await board.load();
  }
  catch (_)
  {
    // Asked again the next time the section is opened.
  }
  finally
  {
    _asking = false;
  }
}
