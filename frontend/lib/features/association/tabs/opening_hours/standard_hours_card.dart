import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../models/opening_day_item.dart';
import 'opening_hours_layout.dart';

const String _closedLabel = 'Chiuso';

// Shows the schedule actually in force right now, taken from the generated
// calendar rather than from weekly_templates: a change dated in the future is
// already stored in the templates but does not apply yet, and one dated in the
// past has been superseded — reading the templates would show either as though
// it were today's schedule.
//
// Laid out as a board rather than a list of "Lun–Ven / 09:00–13:00" rows: the
// seven days run across the card and each one carries its own bands stacked
// underneath, so the week is read left to right the way a timetable is. The
// day-over-values arrangement follows the enrolment cards in
// features/people/tabs/person_schools_tab.dart — a caption above the values it
// labels, spread evenly across the full width of the card.
class StandardHoursCard extends StatelessWidget
{
  // A day holds at most a morning, an afternoon and an evening band, and the
  // card is pinned to a height that clears exactly those three.
  static const int _maxBandsPerDay = 3;

  static const double _bandGap = 6;

  // Weekday (1-7) to the bands in force on the next occurrence of that day.
  final Map<int, List<OpeningDayItem>> scheduleByWeekday;
  final bool isLoading;

  const StandardHoursCard({super.key, required this.scheduleByWeekday, required this.isLoading});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Once the days stack there are seven of them one under the other, far
        // past the height the board is pinned to — so the pinned height applies
        // to the side-by-side layout only.
        final isStacked = constraints.maxWidth < kHoursCompactBreakpoint;

        final card = AppCard(
          title: 'Orario standard',
          compact: true,
          leading: const AppCardBadge(icon: Icons.schedule_rounded, compact: true),
          child: _buildBody(isStacked),
        );

        return isStacked ? card : SizedBox(height: kStandardHoursCardHeight, child: card);
      },
    );
  }

  Widget _buildBody(bool isStacked)
  {
    // Nothing at all while loading: the card fills in fast, and any placeholder
    // here only flashes.
    if (isLoading)
    {
      return const SizedBox.shrink();
    }

    // A week with nothing configured at all reads better as one sentence than
    // as seven columns of "Chiuso".
    if (!_hasAnyOpening)
    {
      return Text(
        'Nessun orario standard configurato.',
        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppTheme.trialMutedText),
      );
    }

    if (isStacked)
    {
      // A day per line, its name on the left and its bands on the right, rather
      // than seven centred columns one under the other: stacked, a column of
      // centred text has nothing to line up against and reads as seven separate
      // little cards.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            if (weekday > 1) const Divider(height: 25, thickness: 1, color: AppTheme.trialLine),
            _buildDayRow(weekday),
          ],
        ],
      );
    }

    // Expanded rather than spaceEvenly: every day takes the same slice of the
    // card regardless of how many bands it holds, so the day names stay evenly
    // spaced and the bands underneath line up in rows across the week.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var weekday = 1; weekday <= 7; weekday++) Expanded(child: _buildDayColumn(weekday)),
      ],
    );
  }

  // One line of the stacked form.
  Widget _buildDayRow(int weekday)
  {
    final bands = _bandsFor(weekday);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            weekdayFullName(weekday),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: bands.isEmpty
              ? Text(
                  _closedLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                  ),
                )
              // Wrapped, so a day with three bands runs on to a second line
              // instead of pushing the two beside it off the card.
              : Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final band in bands)
                      Text(
                        formatTimeRange(band.startTime!, band.endTime!),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.trialInk,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(int weekday)
  {
    final bands = _bandsFor(weekday);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekdayFullName(weekday),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 10),
        if (bands.isEmpty)
          Text(
            _closedLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
            ),
          )
        else
          for (var i = 0; i < bands.length; i++) ...[
            if (i > 0) const SizedBox(height: _bandGap),
            Text(
              formatTimeRange(bands[i].startTime!, bands[i].endTime!),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialInk,
              ),
            ),
          ],
      ],
    );
  }

  // The day's opening bands, earliest first — so they read morning, afternoon,
  // evening down the column. Capped at the three the card is sized for: a
  // fourth band on one day would push that column past the pinned height.
  List<OpeningDayItem> _bandsFor(int weekday)
  {
    final bands = (scheduleByWeekday[weekday] ?? const <OpeningDayItem>[])
        .where((band) => band.startTime != null && band.endTime != null)
        .toList()
      ..sort((a, b) => _minutesOf(a.startTime!).compareTo(_minutesOf(b.startTime!)));

    return bands.take(_maxBandsPerDay).toList();
  }

  bool get _hasAnyOpening
  {
    return scheduleByWeekday.values
        .any((bands) => bands.any((band) => band.startTime != null && band.endTime != null));
  }

  int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;
}
