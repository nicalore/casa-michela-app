import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../lessons/models/presence_group.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/models/subject_request.dart';

// The server deletes only the rows named here and refuses the write if their version moved.
// Rows in [closed] bands are not the reader's to drop.
List<Map<String, dynamic>> withLeftOut(
  List<Map<String, dynamic>> modes,
  Iterable<PresenceItem> stored, {
  bool Function(TimeBucket band)? closed,
})
{
  return [for (final block in modes) _withLeftOut(block, stored, closed)];
}

Map<String, dynamic> _version(int id, DateTime updatedAt)
{
  return {'id': id, 'expected_updated_at': updatedAt.toIso8601String()};
}

Map<String, dynamic> _withLeftOut(
  Map<String, dynamic> block,
  Iterable<PresenceItem> stored,
  bool Function(TimeBucket band)? closed,
)
{
  final Set<Object?> slots = {for (final slot in block['slots'] as List) (slot as Map)['presence_id']};
  final Set<Object?> subjects = {for (final subject in block['subjects'] as List) (subject as Map)['booking_id']};
  bool isClosed(PresenceItem row)
  {
    final TimeBucket? band = bucketFor(row.startTime);

    return closed != null && band != null && closed(band);
  }

  final List<PresenceItem> rows = [
    for (final row in stored)
      if (row.mode == block['mode'] && !isClosed(row)) row,
  ];

  return {
    ...block,
    'dropped_presences': [
      for (final row in rows)
        if (!slots.contains(row.id)) _version(row.id, row.updatedAt),
    ],
    'dropped_bookings': [
      for (final row in rows)
        for (final booking in row.bookings)
          if (!subjects.contains(booking.id)) _version(booking.id, booking.updatedAt),
    ],
  };
}

// Rows in [closed] bands are left out: the server keeps them as they are.
Map<String, dynamic> modeReplacement(
  PresenceGroup group,
  String mode, {
  Set<TimeBucket> dropping = const {},
  bool Function(TimeBucket band)? closed,
})
{
  bool kept(TimeBucket? band) => band != null && !dropping.contains(band) && !(closed?.call(band) ?? false);

  final slots = [
    for (final slot in group.slotsFor(mode))
      if (kept(bucketFor(slot.startTime))) slot,
  ];

  final Map<String, dynamic> block = {
    'mode': mode,
    'slots': [
      for (final slot in slots)
        {
          'start_time': formatTimeOfDay(slot.startTime),
          'end_time': formatTimeOfDay(slot.endTime),
          'presence_id': slot.id,
          'expected_updated_at': slot.updatedAt.toIso8601String(),
        },
    ],
    'subjects': [
      for (final slot in slots)
        for (final booking in slot.bookings)
          SubjectRequestDraft.fromBooking(booking, band: bucketFor(slot.startTime)).toRequestJson(),
    ],
  };

  return _withLeftOut(block, group.slots, closed);
}
