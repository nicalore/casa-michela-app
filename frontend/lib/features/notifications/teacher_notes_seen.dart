import '../../services/api_service.dart';
import 'notification_board.dart';
import 'notification_item.dart';

// Being asked now: a page redrawn meanwhile does not ask twice.
final Set<String> _asked = {};

// The pupil's Osservazioni on screen: the news of teachers' new notes about them goes.
Future<void> markTeacherNotesSeen(String pupilTaxCode) async
{
  // A board not read yet may still hold one: the server is asked all the same.
  final NotificationBoard board = NotificationBoard.instance;

  final bool announced = board.items?.any(
        (item) => item.kind == NotificationKind.teacherNoteAdded && item.pupilTaxCode == pupilTaxCode,
      ) ??
      true;

  if (!announced || !_asked.add(pupilTaxCode))
  {
    return;
  }

  try
  {
    await ApiService().markTeacherNotesSeen(pupilTaxCode);
    await board.load();
  }
  catch (_)
  {
    // Asked again the next time the section is opened.
  }
  finally
  {
    _asked.remove(pupilTaxCode);
  }
}
