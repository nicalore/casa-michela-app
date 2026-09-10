import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';

class EarlyExitScheduleItem
{
  // 1=Monday .. 7=Sunday, per ISO 8601.
  final List<int> weekdays;

  final TimeOfDay exitTime;
  final String reason;

  const EarlyExitScheduleItem({
    required this.weekdays,
    required this.exitTime,
    required this.reason,
  });

  factory EarlyExitScheduleItem.fromJson(Map<String, dynamic> json)
  {
    return EarlyExitScheduleItem(
      weekdays: (json['weekdays'] as List?)?.map((day) => day as int).toList() ?? const [],
      exitTime: parseTimeOfDay(json['exit_time']),
      reason: json['reason'] ?? '',
    );
  }
}
