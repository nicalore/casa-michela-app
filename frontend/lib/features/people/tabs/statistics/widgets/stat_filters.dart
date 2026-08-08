import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_filter_pill.dart';
import 'stats_data.dart';

// The controls above a statistics chart, as the pills the rest of the app
// filters with: a pill here and a pill over the list of people are the same
// object, and the statistics no longer carry a dropdown of their own.
//
// They are gathered in one file because the two tabs ask the same questions of
// different populations. An icon that drifted apart between them would be
// saying there is a difference where there is none.

// Wide enough for a month written out and for a year, which is all these menus
// ever hold.
const double _menuWidth = 160;

// The row a card puts its pills in. Wrapped, so a card that has lost width
// stacks them instead of pushing the last one over its edge.
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

// "Vista: Annuale" over a trend, "Tipo: Mensile" over a retention rate: the same
// question asked about two different things, which is why the word on the pill
// is the caller's.
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

// The two ends of a range wear the two ends of a page rather than a second and a
// third calendar. What tells them apart is which end they are, not that they are
// both about time — the lesson of the four identical calendars the opening hours
// used to show.
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

// The months on offer depend on the year beside it: the first year with data
// does not start in January.
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
