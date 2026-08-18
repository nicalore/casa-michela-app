import 'room_supervision_item.dart';
import 'teacher_room_assignment_item.dart';

// A day's rooms: who is in each, and who answers for each. The two together
// because a shift hangs off an assignment, so supervisions fetched a moment
// later could describe a room nobody has any more.
class RoomDayPlan
{
  final List<TeacherRoomAssignmentItem> assignments;
  final List<RoomSupervisionItem> supervisions;

  const RoomDayPlan({required this.assignments, required this.supervisions});
}
