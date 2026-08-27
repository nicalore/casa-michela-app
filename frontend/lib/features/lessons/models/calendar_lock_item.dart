import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

// Mirrors the backend's calendar_band_locks; only live locks ever arrive.
class CalendarLockItem
{
  final DateTime date;
  final TimeBucket band;

  final String holderTaxCode;

  final PersonOptionItem? holder;

  // Fixed at acquisition; the beat only moves expiresAt.
  final DateTime acquiredAt;

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

// Heartbeat answer. A lock present with [mine] false means somebody else took over.
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

String lockedSentence(CalendarLockItem lock)
{
  final at = lock.acquiredAt.toLocal();
  final who = lock.holder?.fullName ?? 'Un altro amministratore';

  return '$who sta costruendo questo calendario '
      'dalle ${formatTimeOfDayShort(TimeOfDay.fromDateTime(at))}';
}
