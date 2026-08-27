import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_today_button.dart';
import '../../../../shared/widgets/carousel_arrow_button.dart';
import '../../models/opening_day_item.dart';
import 'calendar_bounds.dart';
import 'opening_hours_layout.dart';

class OpeningHoursTableCard extends StatelessWidget
{
  // Fixed so the arrows never shift as the week label's text changes length.
  static const double _weekLabelWidth = 210;

  final DateTime weekStart;
  final List<OpeningDayItem> openingDays;
  final bool isLoading;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToday;

  const OpeningHoursTableCard({
    super.key,
    required this.weekStart,
    required this.openingDays,
    required this.isLoading,
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

    final weekNav = Row(
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

    final narrowNav = Column(
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

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final navBeside = constraints.maxWidth >= kHoursTableNavBreakpoint;
        final narrow = constraints.maxWidth < kHoursTableColumnsBreakpoint;

        return AppCard(
          title: 'Orario settimanale',
          compact: true,
          leading: const AppCardBadge(icon: Icons.calendar_month_rounded, compact: true),
          // Deliberately not wired to isLoading: disabling during a fast fetch
          // reads as flicker; OpeningHoursView still guards double-clicks.
          trailing: navBeside ? weekNav : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!navBeside) ...[
                narrowNav,
                const SizedBox(height: 20),
              ],
              if (!narrow) ...[
                _buildHeaderRow(),
                const SizedBox(height: 12),
              ],
              AnimatedOpacity(
                opacity: isLoading ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Column(
                  children: [
                    for (final day in daysOfWeek(weekStart)) ...[
                      narrow ? _buildNarrowDayRow(day) : _buildDayRow(day),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow()
  {
    return Column(
      children: [
        // Same inset as the day rows, so headings align with their columns.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Expanded(flex: 4, child: SizedBox.shrink()),
              Expanded(flex: 2, child: Center(child: _headerLabel('Mattina'))),
              Expanded(flex: 2, child: Center(child: _headerLabel('Pomeriggio'))),
              Expanded(flex: 2, child: Center(child: _headerLabel('Sera'))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
      ],
    );
  }

  Widget _headerLabel(String label)
  {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.trialMutedText),
    );
  }

  ({bool isOverrideClosure, bool isOrdinaryClosure, Map<TimeBucket, OpeningDayItem> bucketed}) _readDay(DateTime day)
  {
    final rowsForDay = openingDays.where((d) => isSameDate(d.date, day)).toList();

    // A row with no hours is a decided closure; no rows means the template never
    // opens that day. The !isLoading guard stops days from reading as closed
    // while a fetch is in flight and the rows on hand are the previous week's.
    final isOverrideClosure = rowsForDay.any((d) => d.startTime == null);
    final isOrdinaryClosure = !isLoading && rowsForDay.isEmpty;

    final Map<TimeBucket, OpeningDayItem> bucketed = {};

    if (!isOverrideClosure)
    {
      for (final row in rowsForDay)
      {
        final bucket = bucketFor(row.startTime);

        if (bucket != null)
        {
          bucketed[bucket] = row;
        }
      }
    }

    return (
      isOverrideClosure: isOverrideClosure,
      isOrdinaryClosure: isOrdinaryClosure,
      bucketed: bucketed,
    );
  }

  Widget _buildNarrowDayRow(DateTime day)
  {
    final isToday = isSameDate(day, DateTime.now());
    final reading = _readDay(day);
    final closed = reading.isOverrideClosure || reading.isOrdinaryClosure;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? AppTheme.todaySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatWeekdayColumnLabel(day),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
              color: isToday ? AppTheme.trialTealDeep : AppTheme.trialInk,
            ),
          ),
          const SizedBox(height: 6),
          if (closed)
            Align(
              alignment: Alignment.centerLeft,
              child: _buildClosedRow(isOverride: reading.isOverrideClosure),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final bucket in TimeBucket.values)
                  if (reading.bucketed[bucket] != null)
                    _buildNarrowBand(bucket, reading.bucketed[bucket]!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNarrowBand(TimeBucket bucket, OpeningDayItem row)
  {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${bandLabel(bucket)} ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
          TextSpan(
            text: formatTimeRange(row.startTime!, row.endTime!),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: row.isOverride ? FontWeight.w700 : FontWeight.w600,
              color: row.isOverride ? AppTheme.modifiedAccent : AppTheme.trialInk,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDayRow(DateTime day)
  {
    final isToday = isSameDate(day, DateTime.now());
    final (:isOverrideClosure, :isOrdinaryClosure, :bucketed) = _readDay(day);

    return Container(
      decoration: BoxDecoration(
        color: isToday ? AppTheme.todaySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              formatWeekdayColumnLabel(day),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                color: isToday ? AppTheme.trialTealDeep : AppTheme.trialInk,
              ),
            ),
          ),
          if (isOverrideClosure || isOrdinaryClosure)
            Expanded(flex: 6, child: _buildClosedRow(isOverride: isOverrideClosure))
          else
            for (final bucket in TimeBucket.values)
              Expanded(flex: 2, child: Center(child: _buildBucketCell(bucketed[bucket]))),
        ],
      ),
    );
  }

  Widget _buildEmptyCell()
  {
    return Text('–', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppTheme.trialMutedText));
  }

  Widget _buildClosedRow({required bool isOverride})
  {
    return Container(
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isOverride ? AppTheme.modifiedAccentSurface : AppTheme.closedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Chiuso',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: isOverride ? FontWeight.w700 : FontWeight.w500,
          color: isOverride ? AppTheme.modifiedAccent : AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildBucketCell(OpeningDayItem? row)
  {
    if (row == null)
    {
      return _buildEmptyCell();
    }

    return Text(
      formatTimeRange(row.startTime!, row.endTime!),
      // Never two lines: the card's fixed height assumes one line per row.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: row.isOverride ? FontWeight.w700 : FontWeight.w600,
        color: row.isOverride ? AppTheme.modifiedAccent : AppTheme.trialInk,
      ),
    );
  }
}
