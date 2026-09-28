import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_today_button.dart';
import '../../../../shared/widgets/carousel_arrow_button.dart';
import 'calendar_bounds.dart';

// Deliberately not wired to a loading state: disabling during a fast fetch
// reads as flicker; the views owning it still guard double-clicks.
class HoursWeekNav extends StatelessWidget
{
  // Fixed so the arrows never shift as the week label's text changes length.
  static const double _weekLabelWidth = 210;

  final DateTime weekStart;

  // Arrows either side of the label and Oggi underneath, for a narrow card.
  final bool stacked;

  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToday;

  const HoursWeekNav({
    super.key,
    required this.weekStart,
    required this.stacked,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context)
  {
    final weekEnd = addDays(weekStart, 6);
    final isFirstWeek = !weekStart.isAfter(startOfWeek(kAssociationFoundedOn));
    // Days past the horizon do not exist until the December run generates them.
    final isLastWeek = addDays(weekStart, 7).isAfter(calendarHorizon());

    final weekLabel = Text(
      '${formatDayMonthShort(weekStart)} – ${formatDayMonthShort(weekEnd)} ${weekEnd.year}',
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

    if (stacked)
    {
      return Column(
        children: [
          Row(
            children: [
              back,
              Expanded(child: Center(child: weekLabel)),
              forward,
            ],
          ),
          const SizedBox(height: 12),
          AppTodayButton(onTap: onToday),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTodayButton(onTap: onToday),
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
