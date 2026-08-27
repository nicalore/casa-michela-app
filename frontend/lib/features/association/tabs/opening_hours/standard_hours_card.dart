import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../models/opening_day_item.dart';
import 'opening_hours_layout.dart';

const String _closedLabel = 'Chiuso';

// Shows the schedule in force right now, read from the generated calendar
// rather than weekly_templates: templates can hold future or superseded rows.
class StandardHoursCard extends StatelessWidget
{
  // The card height clears exactly three bands per day.
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
        // The pinned height applies to the side-by-side layout only.
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
    if (isLoading)
    {
      return const SizedBox.shrink();
    }

    if (!_hasAnyOpening)
    {
      return Text(
        'Nessun orario standard configurato.',
        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppTheme.trialMutedText),
      );
    }

    if (isStacked)
    {
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

    // Expanded rather than spaceEvenly: equal slices keep the bands lined up.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var weekday = 1; weekday <= 7; weekday++) Expanded(child: _buildDayColumn(weekday)),
      ],
    );
  }

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

  // Earliest first, capped at the three bands the card is sized for.
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
