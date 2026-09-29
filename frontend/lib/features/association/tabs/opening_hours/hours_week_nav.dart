import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_calendar_button.dart';
import '../../../../shared/widgets/carousel_arrow_button.dart';
import '../../../calendar/utils/day_marks_loader.dart';
import 'calendar_bounds.dart';

String hoursWeekLabel(DateTime weekStart)
{
  final weekEnd = addDays(weekStart, 6);

  return '${formatDayMonthShort(weekStart)} – ${formatDayMonthShort(weekEnd)} ${weekEnd.year}';
}

// No loading state: disabling during a fast fetch flickers; the owning views guard double-clicks.
class HoursWeekNav extends StatelessWidget
{
  // Fixed so the arrows never shift as the week label's text changes length.
  static const double _weekLabelWidth = 210;

  final DateTime weekStart;

  final bool stacked;

  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  final ValueChanged<DateTime> onPickDay;

  const HoursWeekNav({
    super.key,
    required this.weekStart,
    required this.stacked,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickDay,
  });

  @override
  Widget build(BuildContext context)
  {
    final weekEnd = addDays(weekStart, 6);
    final isFirstWeek = isOldestKeptWeek(weekStart);
    final isLastWeek = isLastCalendarWeek(weekStart);

    final weekLabel = Text(
      hoursWeekLabel(weekStart),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    final back = CarouselArrowButton(
      icon: Icons.chevron_left_rounded,
      isDisabled: isFirstWeek,
      onTap: onPreviousWeek,
    );

    final forward = CarouselArrowButton(
      icon: Icons.chevron_right_rounded,
      isDisabled: isLastWeek,
      onTap: onNextWeek,
    );

    final calendar = AppCalendarButton(
      selected: weekStart,
      selectedEnd: weekEnd,
      first: oldestKeptDay(),
      last: calendarHorizon(),
      onPicked: onPickDay,
      loadMarks: (from, to) => loadDayMarks(from, to),
    );

    if (stacked)
    {
      return Row(
        children: [
          calendar,
          const SizedBox(width: 8),
          back,
          Expanded(child: Center(child: weekLabel)),
          forward,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        calendar,
        const SizedBox(width: 12),
        back,
        const SizedBox(width: 8),
        SizedBox(width: _weekLabelWidth, child: Center(child: weekLabel)),
        const SizedBox(width: 8),
        forward,
      ],
    );
  }
}
