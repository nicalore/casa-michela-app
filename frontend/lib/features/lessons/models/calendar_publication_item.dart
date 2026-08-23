import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import 'lesson_item.dart';
import 'person_option_item.dart';

class CalendarPublicationItem
{
  final DateTime date;
  final TimeBucket band;

  final DateTime publishedAt;

  final String? publishedBy;
  final PersonOptionItem? publisher;

  final bool isDraft;

  final bool hasChanges;

  final List<String> warnings;

  const CalendarPublicationItem({
    required this.date,
    required this.band,
    required this.publishedAt,
    this.publishedBy,
    this.publisher,
    this.isDraft = false,
    this.hasChanges = false,
    this.warnings = const [],
  });

  factory CalendarPublicationItem.fromJson(Map<String, dynamic> json)
  {
    final publisher = json['publisher'];

    return CalendarPublicationItem(
      date: DateTime.parse(json['date'] as String),
      band: LessonItem.parseBand(json['band']),
      publishedAt: parseInstant(json['published_at'])!,
      publishedBy: json['published_by'] as String?,
      isDraft: json['is_draft'] as bool? ?? false,
      hasChanges: json['has_changes'] as bool? ?? false,
      publisher: publisher == null
          ? null
          : PersonOptionItem.fromJson(publisher as Map<String, dynamic>),
      warnings: parseStringList(json['warnings']),
    );
  }
}

String publishedSentence(CalendarPublicationItem publication)
{
  final at = publication.publishedAt.toLocal();
  final said = formatWeekdayColumnLabel(at);
  final day = '${said[0].toLowerCase()}${said.substring(1)}';
  final by = publication.publisher;

  return 'Pubblicato $day alle ${formatTimeOfDayShort(TimeOfDay.fromDateTime(at))}'
      '${by == null ? '' : ' da ${by.fullName}'}';
}
