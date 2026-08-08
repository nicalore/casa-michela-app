import 'package:flutter/material.dart';

import '../models/weekly_template_item.dart';
import 'opening_hours/opening_hours_view.dart';

class OnlineHoursTab extends StatelessWidget
{
  final List<WeeklyTemplateItem> weeklyTemplates;
  final Future<void> Function() onWeeklyTemplatesChanged;

  const OnlineHoursTab({
    super.key,
    required this.weeklyTemplates,
    required this.onWeeklyTemplatesChanged,
  });

  @override
  Widget build(BuildContext context)
  {
    return OpeningHoursView(
      mode: 'online',
      weeklyTemplates: weeklyTemplates,
      onWeeklyTemplatesChanged: onWeeklyTemplatesChanged,
    );
  }
}
