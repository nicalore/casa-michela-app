import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// Who is building a part of a day right now, mirroring the backend's
// calendar_band_locks. Only the live ones ever arrive: an expired row is not a
// lock any more, and putting a banner on a calendar nobody is working on would
// be worse than saying nothing.
class CalendarLockItem
{
  final DateTime date;
  final TimeBucket band;

  final String holderTaxCode;

  final PersonOptionItem? holder;

  // When they started, which is the hour the banner says. The beat moves the
  // deadline below and leaves this where it is.
  final DateTime acquiredAt;

  // When the band comes free if nothing more is heard from them.
  final DateTime expiresAt;

  const CalendarLockItem({
    required this.date,
    required this.band,
    required this.holderTaxCode,
    required this.acquiredAt,
    required this.expiresAt,
    this.holder,
  });

  factory CalendarLockItem.fromJson(Map<String, dynamic> json)
  {
    final holder = json['holder'];

    return CalendarLockItem(
      date: DateTime.parse(json['date'] as String),
      band: LessonItem.parseBand(json['band']),
      holderTaxCode: json['holder_tax_code'] as String,
      holder: holder == null
          ? null
          : PersonOptionItem.fromJson(holder as Map<String, dynamic>),
      acquiredAt: parseInstant(json['acquired_at'])!,
      expiresAt: parseInstant(json['expires_at'])!,
    );
  }
}

// What the heartbeat answers: the band as it stands, and whether it is still
// ours. A lock present and [mine] false is how a window that was away learns
// somebody else has taken over.
class CalendarLockState
{
  final CalendarLockItem? lock;
  final bool mine;

  const CalendarLockState({this.lock, this.mine = false});

  factory CalendarLockState.fromJson(Map<String, dynamic> json)
  {
    final lock = json['lock'];

    return CalendarLockState(
      lock: lock == null
          ? null
          : CalendarLockItem.fromJson(lock as Map<String, dynamic>),
      mine: json['mine'] as bool? ?? false,
    );
  }
}

// The sentence the others read. Named where the name is known — a tax code is
// not something to show anybody — and the hour they started, not the hour they
// last beat: what matters is how long this has been going on.
String lockedSentence(CalendarLockItem lock)
{
  final at = lock.acquiredAt.toLocal();
  final who = lock.holder?.fullName ?? 'Un altro amministratore';

  return '$who sta costruendo questo calendario '
      'dalle ${formatTimeOfDayShort(TimeOfDay.fromDateTime(at))}';
}
