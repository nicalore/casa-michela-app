import 'package:flutter/material.dart';

import '../models/weekly_template_item.dart';
import 'opening_hours/opening_hours_view.dart';

class PresenceHoursTab extends StatelessWidget
{
  final List<WeeklyTemplateItem> weeklyTemplates;
  final Future<void> Function() onWeeklyTemplatesChanged;

  const PresenceHoursTab({
    super.key,
    required this.weeklyTemplates,
    required this.onWeeklyTemplatesChanged,
  });

  @override
  Widget build(BuildContext context)
  {
    return OpeningHoursView(
      mode: 'presence',
      weeklyTemplates: weeklyTemplates,
      onWeeklyTemplatesChanged: onWeeklyTemplatesChanged,
    );
  }
}
