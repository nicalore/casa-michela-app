import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_filter_pill.dart';
import '../../../../../shared/widgets/filter_menu.dart';
import '../../../../lessons/utils/opening_window.dart';
import '../../../models/student_presence_statistics_item.dart';
import 'daily_trend.dart';
import 'stats_data.dart';

const double _menuWidth = 160;

class StatFilterRow extends StatelessWidget
{
  final List<Widget> children;

  const StatFilterRow({super.key, required this.children});

  @override
  Widget build(BuildContext context)
  {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: children,
    );
  }
}

AppFilterPill<String> resolutionPill({
  required String prefix,
  required String value,
  required ValueChanged<String> onChanged,
})
{
  return AppFilterPill<String>.setting(
    prefix: prefix,
    hint: prefix,
    icon: Icons.calendar_view_month_rounded,
    value: value,
    options: resolutionOptions(),
    onChanged: onChanged,
    menuWidth: _menuWidth,
    bareWhenMinimal: true,
  );
}

AppFilterPill<String> trendResolutionPill({
  required String value,
  required ValueChanged<String> onChanged,
})
{
  return AppFilterPill<String>.setting(
    prefix: 'Vista',
    hint: 'Vista',
    icon: Icons.calendar_view_month_rounded,
    value: value,
    options: trendResolutionOptions(),
    onChanged: onChanged,
    menuWidth: 190,
    bareWhenMinimal: true,
  );
}

AppFilterPill<int> startYearPill({
  required int value,
  required ValueChanged<int> onChanged,
})
{
  return AppFilterPill<int>.setting(
    prefix: 'Da anno',
    hint: 'Da anno',
    icon: Icons.first_page_rounded,
    value: value,
    options: yearOptions(),
    onChanged: onChanged,
    menuWidth: _menuWidth,
    bareWhenMinimal: true,
  );
}

AppFilterPill<int> endYearPill({
  required int value,
  required ValueChanged<int> onChanged,
})
{
  return AppFilterPill<int>.setting(
    prefix: 'A anno',
    hint: 'A anno',
    icon: Icons.last_page_rounded,
    value: value,
    options: yearOptions(),
    onChanged: onChanged,
    menuWidth: _menuWidth,
    bareWhenMinimal: true,
  );
}

AppFilterPill<int> yearPill({
  required int value,
  required ValueChanged<int> onChanged,
})
{
  return AppFilterPill<int>.setting(
    prefix: 'Anno',
    hint: 'Anno',
    icon: Icons.date_range_rounded,
    value: value,
    options: yearOptions(),
    onChanged: onChanged,
    menuWidth: _menuWidth,
    bareWhenMinimal: true,
  );
}

// Months depend on the year: the first year with data may not start in January.
AppFilterPill<int> monthPill({
  required int year,
  required int value,
  required ValueChanged<int> onChanged,
})
{
  return AppFilterPill<int>.setting(
    prefix: 'Mese',
    hint: 'Mese',
    icon: Icons.today_rounded,
    value: value,
    options: monthOptions(year),
    onChanged: onChanged,
    menuWidth: _menuWidth,
    bareWhenMinimal: true,
  );
}

AppFilterPill<String> statsPeriodPill({
  required String value,
  required ValueChanged<String> onChanged,
})
{
  return AppFilterPill<String>.setting(
    prefix: 'Periodo',
    hint: 'Periodo',
    icon: Icons.event_note_rounded,
    value: value,
    options: statsPeriodOptions(),
    onChanged: onChanged,
    menuWidth: 200,
    bareWhenMinimal: true,
  );
}


AppFilterPill<String> statsModePill({
  required String value,
  required ValueChanged<String> onChanged,
})
{
  return AppFilterPill<String>.setting(
    prefix: 'Modalità',
    hint: 'Modalità',
    icon: Icons.devices_outlined,
    value: value,
    options: [
      for (final mode in const [kPresenceMode, kOnlineMode])
        FilterOption(value: mode, label: modeLabel(mode)),
    ],
    onChanged: onChanged,
    menuWidth: 190,
    bareWhenMinimal: true,
  );
}


AppFilterPill<RequestedSubjectKind> requestedKindPill({
  required RequestedSubjectKind value,
  required ValueChanged<RequestedSubjectKind> onChanged,
})
{
  return AppFilterPill<RequestedSubjectKind>.setting(
    prefix: 'Classifica',
    hint: 'Classifica',
    icon: Icons.leaderboard_rounded,
    value: value,
    options: [
      for (final kind in RequestedSubjectKind.values)
        FilterOption(value: kind, label: kind.label),
    ],
    onChanged: onChanged,
    menuWidth: 220,
    bareWhenMinimal: true,
    // Room for "Classifica: Discipline" in one piece.
    maxLabelWidth: 250,
  );
}
