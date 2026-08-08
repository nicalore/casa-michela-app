import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';

class WeeklyTemplateItem
{
  final int id;
  final int weekday;
  final String mode;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final DateTime updatedAt;

  const WeeklyTemplateItem({
    required this.id,
    required this.weekday,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.updatedAt,
  });

  factory WeeklyTemplateItem.fromJson(Map<String, dynamic> json)
  {
    return WeeklyTemplateItem(
      id: json['id'] as int,
      weekday: json['weekday'] as int,
      mode: json['mode'] as String,
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
