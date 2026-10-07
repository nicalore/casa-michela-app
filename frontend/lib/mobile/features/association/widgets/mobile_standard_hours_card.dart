import 'package:flutter/material.dart';

import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/opening_day_item.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/association/tabs/opening_hours/hours_strings.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_hours_table.dart';

const double _radius = 22;

class MobileStandardHoursCard extends StatelessWidget
{
  final StandardSchedule schedule;
  final bool tablet;

  const MobileStandardHoursCard({super.key, required this.schedule, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final MobileHoursTable table = MobileHoursTable(tablet: tablet);

    if (!hasStandardHours(schedule))
    {
      return MobileGlassPanel(
        padding: tablet ? const EdgeInsets.all(20) : const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(_radius),
        child: Text(kNoStandardHours, style: table.closedStyle().copyWith(fontWeight: FontWeight.w500)),
      );
    }

    final double labelWidth = table.labelWidth(context, [for (var weekday = 1; weekday <= 7; weekday++) weekdayFullName(weekday)]);

    return MobileGlassPanel(
      padding: table.padding,
      borderRadius: BorderRadius.circular(_radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          table.head(labelWidth),
          table.rule(strong: true),
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            if (weekday > 1) table.rule(),
            standardRow(table, schedule, weekday, labelWidth),
          ],
        ],
      ),
    );
  }
}

Widget standardRow(MobileHoursTable table, StandardSchedule schedule, int weekday, double labelWidth)
{
  final List<OpeningDayItem> presence = standardBands(schedule, kHoursModes.first, weekday);
  final List<OpeningDayItem> online = standardBands(schedule, kHoursModes.last, weekday);

  Widget cell(String mode, List<OpeningDayItem> bands) => bands.isEmpty ? table.closed() : table.bands(mode, bands);

  return table.row(
    labelWidth: labelWidth,
    label: table.label(weekdayFullName(weekday)),
    cells: presence.isEmpty && online.isEmpty
        ? [table.closed()]
        : [cell(kHoursModes.first, presence), cell(kHoursModes.last, online)],
  );
}
