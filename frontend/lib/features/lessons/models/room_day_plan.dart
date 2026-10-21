import 'dart:math' as math;

import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import 'calendar_day.dart';
import 'lesson_item.dart';
import 'room_supervision_item.dart';
import 'teacher_room_assignment_item.dart';

class RoomDayPlan
{
  final List<TeacherRoomAssignmentItem> assignments;
  final List<RoomSupervisionItem> supervisions;

  const RoomDayPlan({required this.assignments, required this.supervisions});
}

// A teacher's rows of one day, in clock order.
Map<String, List<TeacherRoomAssignmentItem>> stretchesByTeacher(List<TeacherRoomAssignmentItem> rows)
{
  final sorted = [...rows]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  final grouped = <String, List<TeacherRoomAssignmentItem>>{};

  for (final row in sorted)
  {
    grouped.putIfAbsent(row.teacherTaxCode, () => []).add(row);
  }

  return grouped;
}

// Null before the first row or across a room change. Mirrors stretch_at in room_occupancy.py.
TeacherRoomAssignmentItem? stretchAt(List<TeacherRoomAssignmentItem> stretches, int start, int end)
{
  TeacherRoomAssignmentItem? found;

  for (final stretch in stretches)
  {
    if (stretch.startMinutes <= start)
    {
      found = stretch;
    }
    else if (stretch.startMinutes < end)
    {
      return null;
    }
    else
    {
      break;
    }
  }

  return found;
}

// Hours are those of the lane's own hours in the room, not the row's.
typedef LaneRoomStay = ({RoomOptionItem room, int startMinutes, int endMinutes, bool isSupervisor});

class LaneRoomLabel
{
  // Empty for a lane taught entirely from home.
  final List<LaneRoomStay> stays;

  const LaneRoomLabel(this.stays);

  String? get roomName => stays.isEmpty ? null : stays.first.room.name;

  bool get isSupervisor => stays.any((stay) => stay.isSupervisor);

  bool get changesRoom => stays.length > 1;

  RoomOptionItem? roomAt(int start, int end)
  {
    for (final stay in stays)
    {
      if (stay.startMinutes <= start && end <= stay.endMinutes)
      {
        return stay.room;
      }
    }

    return null;
  }
}

Map<String, LaneRoomLabel> laneRoomLabels({
  required List<TeacherLane> lanes,
  required RoomDayPlan? plan,
})
{
  final stretches = stretchesByTeacher(plan?.assignments ?? const <TeacherRoomAssignmentItem>[]);

  final supervisions = plan?.supervisions ?? const <RoomSupervisionItem>[];

  final labels = <String, LaneRoomLabel>{};

  for (final lane in lanes)
  {
    final own = stretches[lane.teacherTaxCode] ?? const <TeacherRoomAssignmentItem>[];

    // Room is by the hour, mode the band's: an online-only band gets no room here.
    final hours = <({int start, int end, RoomOptionItem? room})>[
      for (final lesson in lane.lessons)
        if (lesson.teacherMode == kPresenceMode)
          (
            start: lesson.startMinutes,
            end: lesson.endMinutes,
            room: plan == null ? lesson.room : stretchAt(own, lesson.startMinutes, lesson.endMinutes)?.room,
          ),
      for (final activity in lane.activities)
        if (activity.placement.teacherMode == kPresenceMode)
          (
            start: activity.startMinutes,
            end: activity.endMinutes,
            room: stretchAt(own, activity.startMinutes, activity.endMinutes)?.room,
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final anyMode = lane.lessons.isNotEmpty || lane.activities.isNotEmpty;

    if (hours.isEmpty && anyMode)
    {
      labels[lane.teacherTaxCode] = const LaneRoomLabel([]);

      continue;
    }

    final stays = <({RoomOptionItem room, int startMinutes, int endMinutes})>[];

    for (final hour in hours)
    {
      final room = hour.room;

      if (room == null)
      {
        continue;
      }

      final last = stays.isEmpty ? null : stays.last;

      if (last != null && last.room.id == room.id)
      {
        stays.last = (room: room, startMinutes: last.startMinutes, endMinutes: math.max(last.endMinutes, hour.end));

        continue;
      }

      stays.add((room: room, startMinutes: hour.start, endMinutes: hour.end));
    }

    if (stays.isEmpty)
    {
      continue;
    }

    labels[lane.teacherTaxCode] = LaneRoomLabel([
      for (final stay in stays)
        (
          room: stay.room,
          startMinutes: stay.startMinutes,
          endMinutes: stay.endMinutes,
          isSupervisor: supervisions.any(
            (shift) =>
                shift.teacherTaxCode == lane.teacherTaxCode &&
                shift.room.id == stay.room.id &&
                spansOverlap(shift.startMinutes, shift.endMinutes, stay.startMinutes, stay.endMinutes),
          ),
        ),
    ]);
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
