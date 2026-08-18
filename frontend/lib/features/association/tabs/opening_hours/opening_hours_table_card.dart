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
  // Fixed so the nav row's arrows never shift position when the week-range
  // label's text changes length (different day-count/month-name widths).
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
    // The calendar starts at the association's founding week; there is nothing
    // to show before it.
    final isFirstWeek = !weekStart.isAfter(startOfWeek(kAssociationFoundedOn));
    // The far end is the generated horizon: next year's days do not exist
    // until the December run produces them.
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

    // Wide: everything on the heading's own line, with the week label held to a
    // fixed width so the arrows never shift as the month names change length.
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

    // Narrow: the arrows take the ends of the card and the week between them
    // takes what is left, with the jump back to today under the three. Nothing
    // is dropped — there is no second place to put a week you cannot reach.
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
        // Both answers come from the width of the card itself. The nav gives up
        // its place beside the title first; the four columns hold on a good
        // deal longer, and only below the second breakpoint does each day
        // become a block of its own with its bands wrapped under it.
        final navBeside = constraints.maxWidth >= kHoursTableNavBreakpoint;
        final narrow = constraints.maxWidth < kHoursTableColumnsBreakpoint;

        return AppCard(
          title: 'Orario settimanale',
          compact: true,
          leading: const AppCardBadge(icon: Icons.calendar_month_rounded, compact: true),
          // Deliberately NOT wired to isLoading: a fetch is normally fast enough
          // that disabling these (greying out, dropping the shadow) reads as a
          // flicker rather than useful feedback. The table body below is the one
          // loading indicator; overlapping fetches from a rapid double-click are
          // still guarded in OpeningHoursView, just without a visual disabled state.
          trailing: navBeside ? weekNav : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Under the title rather than beside it once the card is narrow:
              // side by side there is no room left for the week it names.
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
        // Inset like the day rows below, which carry the same padding on their
        // hover/today background: without it the headings drift left of the
        // columns they name, by more the further right they sit.
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
      // Same reason as the band cells: "Pomeriggio" is the widest thing in the
      // narrowest column, and wrapping it would push the whole table down.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.trialMutedText),
    );
  }

  // What the row says, worked out once for both forms.
  ({bool isOverrideClosure, bool isOrdinaryClosure, Map<TimeBucket, OpeningDayItem> bucketed}) _readDay(DateTime day)
  {
    final rowsForDay = openingDays.where((d) => isSameDate(d.date, day)).toList();

    // A row with no hours is a closure somebody decided on — an extraordinary
    // one, or a public holiday. No rows at all is the other kind: the weekly
    // template simply never opens that day.
    //
    // That second reading only holds once the week has actually loaded. While a
    // fetch is in flight the rows on hand are the previous week's, so every day
    // of the new one matches nothing and would claim to be closed: stepping
    // through the weeks flashed a full grey "Chiuso" board between each. Until
    // the answer arrives the cells stay on their dash, which says "not known"
    // rather than "closed".
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

  // The row a phone gets: the day on its own line, its bands wrapped under it,
  // each labelled with the part of the day it belongs to — the column headings
  // have nowhere to live at this width, so every value carries its own.
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

  // The band and the part of the day it belongs to as one run of text rather
  // than as two widgets in a row: a row of two would overflow the card if the
  // pair ever came out wider than it, where a single line simply ends in an
  // ellipsis.
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
          // A closed day says so once, across the three band columns, the way
          // the variations card does — rather than parking the word under
          // Pomeriggio and leaving the other two on their dash.
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

  // Closed all day. The tint and the amber are what separate a closure someone
  // decided on from a day the weekly template never opens: the ordinary one
  // stays in the same grey as the empty cells, so a Sunday reads as
  // unremarkable while a Ferragosto stands out.
  //
  // Neither carries its note any more. The note belongs to the variation, and
  // the variations card is where it is read; here it made one row of seven
  // twice as tall as the others.
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
      // Never two lines: the card's height is a measured constant that assumes
      // one, and a wrapped cell would push the row — and the variations card
      // pinned to that height — out of line.
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
