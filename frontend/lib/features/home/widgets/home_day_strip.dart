import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../association/tabs/opening_hours/mode_hours_parts.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../../dashboard/widgets/published_pill.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import 'home_schedule_data.dart';

const double _columnGap = 16;
const double _rowGap = 8;
const double _trackHeight = 17;
const double _timeGap = 6;

const List<String> kStripModes = [kPresenceMode, kOnlineMode];

// A mode the band does not open, or a closed band: greyer than the muted text.
final Color kStripClosedColor = AppTheme.trialMutedText.withValues(alpha: 0.62);

TextStyle _caps() => GoogleFonts.plusJakartaSans(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      height: 1.3,
      color: AppTheme.trialMutedText,
    );

String _clock(int minutes) => formatTimeOfDayShort(timeOfDayFromMinutes(minutes));

TextStyle _time() => GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialMutedText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// Mattina, Pomeriggio and Sera side by side, always all three, parted by hairlines.
class DayStripFrame extends StatelessWidget
{
  final Widget Function(TimeBucket band) column;

  const DayStripFrame({super.key, required this.column});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, band) in TimeBucket.values.indexed) ...[
            if (index > 0) ...[
              const SizedBox(width: _columnGap),
              Container(width: 1, color: AppTheme.trialLine),
              const SizedBox(width: _columnGap),
            ],
            Expanded(child: column(band)),
          ],
        ],
      ),
    );
  }
}

class StripBandHead extends StatelessWidget
{
  final TimeBucket band;

  final bool isPublished;
  final bool isDraft;

  const StripBandHead({super.key, required this.band, this.isPublished = false, this.isDraft = false});

  @override
  Widget build(BuildContext context)
  {
    // On a narrow column the pill goes under the name.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 22),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            bandLabel(band),
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppTheme.trialOcean,
            ),
          ),
          if (isPublished) PublishedPill(isDraft: isDraft),
        ],
      ),
    );
  }
}

class ClosedBandColumn extends StatelessWidget
{
  final TimeBucket band;

  const ClosedBandColumn({super.key, required this.band});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StripBandHead(band: band),
        const SizedBox(height: _rowGap),
        Row(
          children: [
            Icon(Icons.event_busy_rounded, size: 19, color: kStripClosedColor),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                "L'Associazione è chiusa",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// A mode the band keeps closed holds its row, so the rows of the three bands line up.
class StripClosedMode extends StatelessWidget
{
  final String mode;

  final double height;

  const StripClosedMode({super.key, required this.mode, required this.height});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Icon(lessonModeIcon(mode), size: 16, color: kStripClosedColor),
          const SizedBox(width: 5),
          Text(
            kClosedLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: kStripClosedColor,
            ),
          ),
        ],
      ),
    );
  }
}

// The day of a teacher, a pupil or a parent: what they gave or booked against each band's opening.
class HomeDayStrip extends StatelessWidget
{
  final List<HomeBandStatus>? bands;
  final bool isLoading;

  final DateTime day;

  final String title;
  final String ownHeading;
  final String? convenedHeading;
  final String emptyBandLabel;
  final String? unconvenedLabel;

  // A lane per child instead of one per mode.
  final bool named;

  const HomeDayStrip({
    super.key,
    required this.bands,
    required this.day,
    required this.title,
    required this.ownHeading,
    required this.emptyBandLabel,
    this.convenedHeading,
    this.unconvenedLabel,
    this.isLoading = false,
    this.named = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      icon: Icons.today_rounded,
      title: title,
      action: DashboardCardNote(formatWeekdayColumnLabel(day)),
      child: _body(),
    );
  }

  Widget _body()
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    final List<HomeBandStatus>? read = bands;

    if (read == null)
    {
      return Text(
        'Gli orari di oggi non sono disponibili.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    return DayStripFrame(
      column: (band)
      {
        final HomeBandStatus? status = read.where((status) => status.band == band).firstOrNull;

        return status == null ? ClosedBandColumn(band: band) : _column(status);
      },
    );
  }

  String _headingOf(HomeBandStatus status)
  {
    final String? convened = convenedHeading;
    final String? unconvened = unconvenedLabel;

    if (!status.isEmpty)
    {
      return status.isPublished && convened != null ? convened : ownHeading;
    }

    return status.isPublished && status.offered && unconvened != null ? unconvened : emptyBandLabel;
  }

  Widget _column(HomeBandStatus status)
  {
    final List<Widget> rows = [];

    // Children with lessons get a lane each; an empty band shows its opening instead.
    if (named && status.lanes.isNotEmpty)
    {
      rows.addAll(status.lanes.map((lane) => StripLane(lane: lane)));

      for (final name in status.idle)
      {
        rows.add(Text(
          '$name · ${emptyBandLabel.toLowerCase()}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            height: 1.35,
            color: AppTheme.trialMutedText,
          ),
        ));
      }
    }
    else
    {
      for (final mode in kStripModes)
      {
        final HomeLane? lane = status.lanes.where((lane) => lane.mode == mode && lane.name.isEmpty).firstOrNull;
        final OpeningWindow? opening = status.openings[mode];

        if (lane != null)
        {
          rows.add(StripLane(lane: lane));
        }
        else if (opening != null)
        {
          rows.add(StripLane(
            lane: HomeLane(mode: mode, name: '', opening: opening, spans: const [], subjects: 0),
          ));
        }
        else
        {
          rows.add(_ClosedLane(mode: mode));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StripBandHead(band: status.band, isPublished: status.isPublished),
        const SizedBox(height: 2),
        Text(_headingOf(status).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _caps()),
        for (final row in rows) ...[
          const SizedBox(height: _rowGap),
          row,
        ],
      ],
    );
  }
}

// A lane's label over the closed word, the height of a lane's label over its track.
class _ClosedLane extends StatelessWidget
{
  final String mode;

  const _ClosedLane({required this.mode});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LaneLabel(icon: lessonModeIcon(mode), label: modeLabel(mode), color: kStripClosedColor),
        const SizedBox(height: 5),
        SizedBox(
          height: _trackHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              kClosedLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: kStripClosedColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LaneLabel extends StatelessWidget
{
  final IconData icon;
  final String label;
  final Color color;

  final String? note;

  const _LaneLabel({required this.icon, required this.label, required this.color, this.note});

  @override
  Widget build(BuildContext context)
  {
    final String? note = this.note;

    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (note != null)
                    TextSpan(
                      text: '  $note',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// The track is the mode's opening, ends beside it; the reader's own hours are bars, read on hover.
class StripLane extends StatelessWidget
{
  final HomeLane lane;

  const StripLane({super.key, required this.lane});

  @override
  Widget build(BuildContext context)
  {
    final OpeningWindow opening = lane.opening;
    final bool named = lane.name.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LaneLabel(
          icon: lessonModeIcon(lane.mode),
          label: named ? lane.name : modeLabel(lane.mode),
          color: named ? AppTheme.trialInk : lessonAccent(lane.mode),
          note: lane.subjects > 0 ? homeSubjectsLabel(lane.subjects) : null,
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: _trackHeight,
          child: Row(
            children: [
              Text(_clock(opening.startMinutes), style: _time()),
              const SizedBox(width: _timeGap),
              Expanded(child: _Track(lane: lane)),
              const SizedBox(width: _timeGap),
              Text(_clock(opening.endMinutes), style: _time()),
            ],
          ),
        ),
      ],
    );
  }
}

class _Track extends StatelessWidget
{
  final HomeLane lane;

  const _Track({required this.lane});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(builder: _buildBar);
  }

  Widget _buildBar(BuildContext context, BoxConstraints constraints)
  {
    final OpeningWindow opening = lane.opening;
    final Color accent = lessonAccent(lane.mode);
    final double width = constraints.maxWidth;

    double x(int minutes) => (minutes - opening.startMinutes) / opening.minutes * width;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.trialPaper,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
            ),
          ),
        ),
        for (final (start, end) in lane.spans)
          Positioned(
            left: x(start),
            width: x(end) - x(start),
            top: 0,
            bottom: 0,
            child: AppTooltip(
              message: formatMinutesRange(start, end),
              child: DecoratedBox(
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(_trackHeight / 2)),
              ),
            ),
          ),
      ],
    );
  }
}
