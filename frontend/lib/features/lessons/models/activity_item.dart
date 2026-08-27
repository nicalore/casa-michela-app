import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

class ActivityPlacementItem
{
  final int availabilityId;

  final String teacherTaxCode;
  final PersonOptionItem teacher;

  // Comes from the availability the hours were taken out of.
  final String teacherMode;

  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const ActivityPlacementItem({
    required this.availabilityId,
    required this.teacherTaxCode,
    required this.teacher,
    required this.teacherMode,
    required this.startTime,
    required this.endTime,
  });

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  int get minutes => endMinutes - startMinutes;

  factory ActivityPlacementItem.fromJson(Map<String, dynamic> json)
  {
    return ActivityPlacementItem(
      availabilityId: json['availability_id'] as int,
      teacherTaxCode: json['teacher_tax_code'] as String,
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      teacherMode: json['teacher_mode'] as String,
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
    );
  }
}

class ActivityItem
{
  final int id;

  final DateTime date;
  final TimeBucket band;

  final String name;
  final String? description;

  final ActivityPlacementItem? placement;

  final bool isLocked;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityItem({
    required this.id,
    required this.date,
    required this.band,
    required this.name,
    this.description,
    this.placement,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAssigned => placement != null;

  String? get teacherTaxCode => placement?.teacherTaxCode;

  // Takes the whole editable state: an optional-parameter copy could not
  // express "placement cleared".
  ActivityItem asWritten({
    required String name,
    required String? description,
    required ActivityPlacementItem? placement,
  })
  {
    return ActivityItem(
      id: id,
      date: date,
      band: band,
      name: name,
      description: description,
      placement: placement,
      isLocked: isLocked,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json)
  {
    final placement = json['placement'];

    return ActivityItem(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      band: LessonItem.parseBand(json['band']),
      name: json['name'] as String,
      description: json['description'] as String?,
      placement: placement == null
          ? null
          : ActivityPlacementItem.fromJson(placement as Map<String, dynamic>),
      isLocked: json['is_locked'] as bool? ?? false,
      createdAt: parseInstant(json['created_at'])!,
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}

// An activity with a non-null placement, so downstream code need not re-check.
class ScheduledActivity
{
  final ActivityItem activity;
  final ActivityPlacementItem placement;

  const ScheduledActivity({required this.activity, required this.placement});

  static ScheduledActivity? of(ActivityItem activity)
  {
    final placement = activity.placement;

    return placement == null
        ? null
        : ScheduledActivity(activity: activity, placement: placement);
  }

  int get id => activity.id;

  String get name => activity.name;

  String? get description => activity.description;

  bool get isLocked => activity.isLocked;

  String get teacherTaxCode => placement.teacherTaxCode;

  PersonOptionItem get teacher => placement.teacher;

  int get startMinutes => placement.startMinutes;

  int get endMinutes => placement.endMinutes;

  int get minutes => placement.minutes;
}
