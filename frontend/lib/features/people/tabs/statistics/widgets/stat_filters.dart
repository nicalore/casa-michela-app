import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_filter_pill.dart';
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
  );
}

// The months on offer depend on the year: the first year with data does not
// start in January.
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
  );
}

AppFilterPill<String> appreciationPeriodPill({
  required String value,
  required ValueChanged<String> onChanged,
})
{
  return AppFilterPill<String>.setting(
    prefix: 'Periodo',
    hint: 'Periodo',
    icon: Icons.event_note_rounded,
    value: value,
    options: appreciationPeriodOptions(),
    onChanged: onChanged,
    menuWidth: 200,
  );
}
