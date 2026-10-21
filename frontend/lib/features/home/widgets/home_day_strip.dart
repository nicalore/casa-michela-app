import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../association/tabs/opening_hours/mode_hours_parts.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../../dashboard/widgets/published_pill.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import 'home_schedule_data.dart';

const List<String> kStripModes = [kPresenceMode, kOnlineMode];

// A mode the band does not open, or a closed band: greyer than the muted text.
final Color kStripClosedColor = AppTheme.trialMutedText.withValues(alpha: 0.62);

// Below this the three bands go one under the other, each with its name beside its rows.
const double kStripStackedBelow = 480;

const double _stackedHeadWidth = 112;

class StripScale
{
  final double columnGap;
  final double rowGap;
  final double track;
  final double timeGap;
  final double caps;
  final double time;
  final double bandName;
  final double label;
  final double note;
  final double icon;
  final double closed;
  final double labelGap;
  final double hours;
  final double figure;
  final double figureLabel;

  const StripScale._({
    required this.columnGap,
    required this.rowGap,
    required this.track,
    required this.timeGap,
    required this.caps,
    required this.time,
    required this.bandName,
    required this.label,
    required this.note,
    required this.icon,
    required this.closed,
    required this.labelGap,
    required this.hours,
    required this.figure,
    required this.figureLabel,
  });

  static const StripScale _wide = StripScale._(
    columnGap: 16,
    rowGap: 8,
    track: 17,
    timeGap: 6,
    caps: 10.5,
    time: 11.5,
    bandName: 16,
    label: 13,
    note: 12,
    icon: 16,
    closed: 13,
    labelGap: 5,
    hours: 15,
    figure: 18,
    figureLabel: 12.5,
  );

  static const StripScale _dense = StripScale._(
    columnGap: 12,
    rowGap: 6,
    track: 14,
    timeGap: 5,
    caps: 9.5,
    time: 10.5,
    bandName: 14.5,
    label: 12,
    note: 11.5,
    icon: 15,
    closed: 12.5,
    labelGap: 4,
    hours: 13.5,
    figure: 16,
    figureLabel: 11.5,
  );

  static StripScale of(BuildContext context) => AppBreakpoints.of(context).isDense ? _dense : _wide;
}

TextStyle _caps(StripScale scale) => GoogleFonts.plusJakartaSans(
      fontSize: scale.caps,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      height: 1.3,
      color: AppTheme.trialMutedText,
    );

String _clock(int minutes) => formatTimeOfDayShort(timeOfDayFromMinutes(minutes));

TextStyle _time(StripScale scale) => GoogleFonts.plusJakartaSans(
      fontSize: scale.time,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialMutedText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// Mattina, Pomeriggio and Sera side by side, always all three, parted by hairlines; stacked, one under the other.
class DayStripFrame extends StatelessWidget
{
  final Widget Function(TimeBucket band) column;

  final bool stacked;

  const DayStripFrame({super.key, required this.column, this.stacked = false});

  @override
  Widget build(BuildContext context)
  {
    final StripScale scale = StripScale.of(context);

    if (stacked)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, band) in TimeBucket.values.indexed) ...[
            if (index > 0) ...[
              SizedBox(height: scale.rowGap + 2),
              Container(height: 1, color: AppTheme.trialLine),
              SizedBox(height: scale.rowGap + 2),
            ],
            column(band),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, band) in TimeBucket.values.indexed) ...[
            if (index > 0) ...[
              SizedBox(width: scale.columnGap),
              Container(width: 1, color: AppTheme.trialLine),
              SizedBox(width: scale.columnGap),
            ],
            Expanded(child: column(band)),
          ],
        ],
      ),
    );
  }
}

// Stacked bands: the name and its line on the left, the rows beside them.
class StripStackedBand extends StatelessWidget
{
  final Widget head;
  final List<Widget> rows;

  const StripStackedBand({super.key, required this.head, required this.rows});

  @override
  Widget build(BuildContext context)
  {
    final StripScale scale = StripScale.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _stackedHeadWidth, child: head),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, row) in rows.indexed) ...[
                if (index > 0) SizedBox(height: scale.rowGap),
                row,
              ],
            ],
          ),
        ),
      ],
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
    final StripScale scale = StripScale.of(context);

    // On a narrow column the pill goes under the name.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 22),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DescenderRoom(
            child: Text(
              bandLabel(band),
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: scale.bandName,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppTheme.trialOcean,
              ),
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

  final bool stacked;

  const ClosedBandColumn({super.key, required this.band, this.stacked = false});

  @override
  Widget build(BuildContext context)
  {
    final StripScale scale = StripScale.of(context);

    final Widget closed = Row(
      children: [
        Icon(Icons.event_busy_rounded, size: scale.icon + 3, color: kStripClosedColor),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            "L'Associazione è chiusa",
            style: GoogleFonts.plusJakartaSans(
              fontSize: scale.closed,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
      ],
    );

    if (stacked)
    {
      return StripStackedBand(head: StripBandHead(band: band), rows: [closed]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StripBandHead(band: band),
        SizedBox(height: scale.rowGap),
        closed,
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
    final StripScale scale = StripScale.of(context);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Icon(lessonModeIcon(mode), size: scale.icon, color: kStripClosedColor),
          const SizedBox(width: 5),
          Text(
            kClosedLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scale.closed - 0.5,
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
      child: LayoutBuilder(
        builder: (context, constraints) => _body(context, stacked: constraints.maxWidth < kStripStackedBelow),
      ),
    );
  }

  Widget _body(BuildContext context, {required bool stacked})
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
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    return DayStripFrame(
      stacked: stacked,
      column: (band)
      {
        final HomeBandStatus? status = read.where((status) => status.band == band).firstOrNull;

        return status == null
            ? ClosedBandColumn(band: band, stacked: stacked)
            : _column(context, status, stacked: stacked);
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

  Widget _column(BuildContext context, HomeBandStatus status, {required bool stacked})
  {
    final StripScale scale = StripScale.of(context);
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
            fontSize: scale.closed - 0.5,
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

    final Widget heading = Text(
      _headingOf(status).toUpperCase(),
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: _caps(scale),
    );

    if (stacked)
    {
      return StripStackedBand(
        head: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripBandHead(band: status.band, isPublished: status.isPublished),
            const SizedBox(height: 2),
            heading,
          ],
        ),
        rows: rows,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StripBandHead(band: status.band, isPublished: status.isPublished),
        const SizedBox(height: 2),
        heading,
        for (final row in rows) ...[
          SizedBox(height: scale.rowGap),
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
    final StripScale scale = StripScale.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LaneLabel(icon: lessonModeIcon(mode), label: modeLabel(mode), color: kStripClosedColor),
        SizedBox(height: scale.labelGap),
        SizedBox(
          height: scale.track,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              kClosedLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: scale.closed - 1,
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
    final StripScale scale = StripScale.of(context);

    return SizedBox(
      height: scale.label + 5,
      child: Row(
        children: [
          Icon(icon, size: scale.icon, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: DescenderRoom(
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (note != null)
                      TextSpan(
                        text: '  $note',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scale.note,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: scale.label,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: color,
                ),
              ),
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
    final StripScale scale = StripScale.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LaneLabel(
          icon: lessonModeIcon(lane.mode),
          label: named ? lane.name : modeLabel(lane.mode),
          color: named ? AppTheme.trialInk : lessonAccent(lane.mode),
          note: lane.subjects > 0 ? homeSubjectsLabel(lane.subjects) : null,
        ),
        SizedBox(height: scale.labelGap),
        SizedBox(
          height: scale.track,
          child: Row(
            children: [
              Text(_clock(opening.startMinutes), style: _time(scale)),
              SizedBox(width: scale.timeGap),
              Expanded(child: _Track(lane: lane)),
              SizedBox(width: scale.timeGap),
              Text(_clock(opening.endMinutes), style: _time(scale)),
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
    final double radius = constraints.maxHeight / 2;

    double x(int minutes) => (minutes - opening.startMinutes) / opening.minutes * width;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.trialPaper,
              borderRadius: BorderRadius.circular(radius),
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
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(radius)),
              ),
            ),
          ),
      ],
    );
  }
}
