import '../utils/opening_window.dart';
import 'calendar_day.dart';
import 'room_supervision_item.dart';
import 'teacher_room_assignment_item.dart';

class RoomDayPlan
{
  final List<TeacherRoomAssignmentItem> assignments;
  final List<RoomSupervisionItem> supervisions;

  const RoomDayPlan({required this.assignments, required this.supervisions});
}

typedef LaneRoomLabel = ({String? roomName, bool isSupervisor});

Map<String, LaneRoomLabel> laneRoomLabels({
  required List<TeacherLane> lanes,
  required RoomDayPlan? plan,
})
{
  final assigned = {
    for (final row in plan?.assignments ?? const <TeacherRoomAssignmentItem>[])
      row.teacherTaxCode: row.room,
  };

  final supervisions = plan?.supervisions ?? const <RoomSupervisionItem>[];

  final labels = <String, LaneRoomLabel>{};

  for (final lane in lanes)
  {
    final room = assigned[lane.teacherTaxCode] ??
        lane.lessons.map((lesson) => lesson.room).nonNulls.firstOrNull;

    if (room == null)
    {
      if (lane.lessons.isNotEmpty &&
          lane.lessons.every((lesson) => lesson.teacherMode == kOnlineMode))
      {
        labels[lane.teacherTaxCode] = (roomName: null, isSupervisor: false);
      }

      continue;
    }

    labels[lane.teacherTaxCode] = (
      roomName: room.name,
      isSupervisor: supervisions.any(
        (shift) => shift.teacherTaxCode == lane.teacherTaxCode && shift.room.id == room.id,
      ),
    );
  }

  return labels;
}

const String _lastOfAll = '\uffff';

List<TeacherLane> orderByRoom({
  required List<TeacherLane> lanes,
  required Map<String, LaneRoomLabel> rooms,
})
{
  String roomOf(TeacherLane lane) => rooms[lane.teacherTaxCode]?.roomName ?? _lastOfAll;

  int standingOf(TeacherLane lane) => rooms[lane.teacherTaxCode]?.isSupervisor == true ? 0 : 1;

  return [...lanes]..sort((a, b)
  {
    final byRoom = roomOf(a).toLowerCase().compareTo(roomOf(b).toLowerCase());

    if (byRoom != 0)
    {
      return byRoom;
    }

    final byStanding = standingOf(a).compareTo(standingOf(b));

    if (byStanding != 0)
    {
      return byStanding;
    }

    return a.teacher.fullName.toLowerCase().compareTo(b.teacher.fullName.toLowerCase());
  });
}
