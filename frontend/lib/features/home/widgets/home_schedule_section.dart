import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/closed_today_notice.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../../dashboard/widgets/published_pill.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import 'home_schedule_data.dart';

const double _bandGap = 12;
const double _laneGap = 8;
const double _gap = 6;

const double _trackHeight = 14;
const double _labelWidth = 118;
const double _timeWidth = 42;

const double _blockPadding = 16;
const double _blockBorder = 1.5;

const double _stackedBelow = 340;

// Ticks closer than this to the previous one are dropped.
const double _tickWidth = 36;
const double _tickRow = 16;

const double _labelSize = 12.5;
const double _labelLineHeight = 1.3;

// Lines the bar up with the label's first line.
const double _barTopInset = (_labelSize * _labelLineHeight - _trackHeight) / 2;

String _subjectsLabel(int count) => count == 1 ? '1 materia' : '$count materie';

class HomeScheduleSection extends StatelessWidget
{
  // Null when the day could not be read, distinct from a day with no openings.
  final List<HomeBandStatus>? bands;

  final bool isLoading;

  final String title;

  final String ownHeading;

  final String? convenedHeading;

  final String emptyBandLabel;

  final String? unconvenedLabel;

  // Passed in because a LayoutBuilder cannot answer under IntrinsicHeight.
  final double width;

  final double minHeight;
  final bool fill;

  const HomeScheduleSection({
    super.key,
    required this.bands,
    required this.title,
    required this.ownHeading,
    required this.emptyBandLabel,
    required this.width,
    this.convenedHeading,
    this.unconvenedLabel,
    this.isLoading = false,
    this.minHeight = 0,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      eyebrow: 'Oggi',
      title: title,
      minHeight: minHeight,
      fill: fill,
      child: _buildBody(),
    );
  }

  Widget _buildBody()
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final List<HomeBandStatus>? open = bands;

    if (open == null)
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

    if (open.isEmpty)
    {
      return const ClosedTodayNotice();
    }

    final bool shares = fill && open.length > 1;

    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: shares ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < open.length; i++)
          if (shares)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i == open.length - 1 ? 0 : _bandGap),
                child: _band(open[i]),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: i == open.length - 1 ? 0 : _bandGap),
              child: _band(open[i]),
            ),
      ],
    );
  }

  Widget _band(HomeBandStatus status)
  {
    return _BandBlock(
      status: status,
      heading: _headingOf(status),
      emptyLabel: emptyBandLabel,
      stacked: width - 2 * (_blockPadding + _blockBorder) < _stackedBelow,
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

    return status.isPublished && status.offered && unconvened != null
        ? unconvened
        : emptyBandLabel;
  }
}

class _BandBlock extends StatelessWidget
{
  final HomeBandStatus status;
  final String heading;
  final String emptyLabel;
  final bool stacked;

  const _BandBlock({
    required this.status,
    required this.heading,
    required this.emptyLabel,
    required this.stacked,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _blockPadding, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.trialLine, width: _blockBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHead(),
          const SizedBox(height: 10),
          for (var i = 0; i < status.lanes.length; i++) ...[
            if (i > 0) const SizedBox(height: _laneGap),
            _Lane(lane: status.lanes[i], stacked: stacked),
          ],
          if (!status.isEmpty)
            for (final name in status.idle) ...[
              const SizedBox(height: _laneGap),
              Text(
                '$name · ${emptyLabel.toLowerCase()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildHead()
  {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              bandLabel(status.band),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppTheme.trialOcean,
              ),
            ),
            if (status.isPublished) ...[
              const SizedBox(width: 8),
              const PublishedPill(),
            ],
          ],
        ),
        Text(
          heading.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            height: 1.3,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }
}

class _Lane extends StatelessWidget
{
  final HomeLane lane;
  final bool stacked;

  const _Lane({required this.lane, required this.stacked});

  @override
  Widget build(BuildContext context)
  {
    final OpeningWindow opening = lane.opening;

    final Widget bar = Row(
      children: [
        SizedBox(
          width: _timeWidth,
          child: _Time(minutes: opening.startMinutes, align: TextAlign.right),
        ),
        const SizedBox(width: _gap),
        Expanded(child: _Track(lane: lane)),
        const SizedBox(width: _gap),
        SizedBox(
          width: _timeWidth,
          child: _Time(minutes: opening.endMinutes, align: TextAlign.left),
        ),
      ],
    );

    final Widget padded = Padding(
      padding: EdgeInsets.only(bottom: _tickMinutes(lane).isEmpty ? 0 : _tickRow),
      child: bar,
    );

    if (stacked)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LaneLabel(lane: lane, stacked: true),
          const SizedBox(height: 2),
          padded,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _labelWidth, child: _LaneLabel(lane: lane, stacked: false)),
        const SizedBox(width: _gap),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: _barTopInset),
            child: padded,
          ),
        ),
      ],
    );
  }
}

class _LaneLabel extends StatelessWidget
{
  final HomeLane lane;
  final bool stacked;

  const _LaneLabel({required this.lane, required this.stacked});

  @override
  Widget build(BuildContext context)
  {
    final Color accent = lessonAccent(lane.mode);
    final String? subjects = lane.subjects > 0 ? _subjectsLabel(lane.subjects) : null;

    final TextStyle muted = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: _labelLineHeight,
      color: AppTheme.trialMutedText,
    );

    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(lessonModeIcon(lane.mode), size: 17, color: accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: lane.name.isEmpty ? modeLabel(lane.mode) : lane.name,
              children: [
                if (stacked && subjects != null) TextSpan(text: ' · $subjects', style: muted),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _labelSize,
              fontWeight: FontWeight.w700,
              height: _labelLineHeight,
              color: accent,
            ),
          ),
        ),
      ],
    );

    if (stacked || subjects == null)
    {
      return label;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        Padding(
          padding: const EdgeInsets.only(left: 23),
          child: Text(subjects, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
        ),
      ],
    );
  }
}

class _Time extends StatelessWidget
{
  final int minutes;
  final TextAlign align;

  const _Time({required this.minutes, required this.align});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      formatTimeOfDayShort(timeOfDayFromMinutes(minutes)),
      textAlign: align,
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppTheme.trialMutedText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

List<int> _tickMinutes(HomeLane lane)
{
  final OpeningWindow opening = lane.opening;

  final Set<int> minutes = {
    for (final (start, end) in lane.spans) ...[start, end],
  }..removeAll([opening.startMinutes, opening.endMinutes]);

  return minutes.toList()..sort();
}

// The fixed height answers the intrinsic-height queries the LayoutBuilder inside cannot.
class _Track extends StatelessWidget
{
  final HomeLane lane;

  const _Track({required this.lane});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: _trackHeight,
      child: LayoutBuilder(builder: _buildBar),
    );
  }

  Widget _buildBar(BuildContext context, BoxConstraints constraints)
  {
    final OpeningWindow opening = lane.opening;
    final Color accent = lessonAccent(lane.mode);

    final double width = constraints.maxWidth;

    double x(int minutes) => (minutes - opening.startMinutes) / opening.minutes * width;

    final List<int> ticks = [];

    for (final minutes in _tickMinutes(lane))
    {
      if (ticks.isEmpty || x(minutes) - x(ticks.last) >= _tickWidth + 4)
      {
        ticks.add(minutes);
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              border: Border.all(color: AppTheme.trialLine),
            ),
          ),
        ),
        for (final (start, end) in lane.spans)
          Positioned(
            left: x(start),
            width: x(end) - x(start),
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(_trackHeight / 2),
              ),
            ),
          ),
        for (final minutes in ticks)
          Positioned(
            left: x(minutes) - _tickWidth / 2,
            width: _tickWidth,
            top: _trackHeight + 2,
            child: Text(
              formatTimeOfDayShort(timeOfDayFromMinutes(minutes)),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppTheme.trialMutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}
