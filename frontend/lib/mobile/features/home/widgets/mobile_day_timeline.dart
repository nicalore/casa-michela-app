import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/calendar/utils/calendar_strings.dart';
import '../../../../features/calendar/utils/teacher_band_call.dart';
import '../../../../features/home/widgets/home_schedule_data.dart';
import '../../../../features/home/widgets/role_home_layout.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../mobile_teacher_day.dart';

const double _timeWidth = 44;
const double _railWidth = 18;
const double _railGap = 8;
const double _bodyGap = 8;

const double _railStroke = 3;
const double _stopRadius = 6;
const double _stopStroke = 2.5;
const double _nowRadius = 6;
const double _nowHalo = 4;

// Clears the next stop when a band's own text is taller than its block.
const double _bodyBottom = 28;

const double _endStopHeight = _stopRadius * 2 + _stopStroke;

const Color _convenedText = Color(0xFFF3C766);
const Color _availableText = Color(0xFF7FE3D6);

class MobileDayTimeline extends StatefulWidget
{
  final MobileTeacherDay day;
  final bool feminine;

  // Bands are not to scale; each block is at least this tall.
  final double minBandHeight;

  // The last band takes the leftover height, reaching a neighbour-sized column's bottom.
  final bool fill;

  const MobileDayTimeline({
    super.key,
    required this.day,
    required this.feminine,
    this.minBandHeight = 150,
    this.fill = false,
  });

  @override
  State<MobileDayTimeline> createState() => _MobileDayTimelineState();
}

class _MobileDayTimelineState extends State<MobileDayTimeline>
{
  // Only the rails watch it, so the minute ticks without rebuilding the text.
  final ValueNotifier<int?> _nowMinutes = ValueNotifier(null);

  Timer? _timer;

  @override
  void initState()
  {
    super.initState();
    _tick();
  }

  @override
  void didUpdateWidget(MobileDayTimeline oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!isSameDate(widget.day.day, oldWidget.day.day))
    {
      _tick();
    }
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    _nowMinutes.dispose();
    super.dispose();
  }

  // Wakes on the minute, not every 60 s from whenever the page opened.
  void _tick()
  {
    final DateTime now = DateTime.now();

    _nowMinutes.value = isSameDate(now, widget.day.day) ? now.hour * 60 + now.minute : null;

    _timer?.cancel();
    _timer = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      _tick,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<MobileDayBand> bands = widget.day.bands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, band) in bands.indexed)
          if (widget.fill && i == bands.length - 1)
            Expanded(child: _buildBand(band))
          else
            _buildBand(band),
        _Rail(
          label: formatTimeOfDayShort(timeOfDayFromMinutes(bands.last.endMinutes)),
          height: _endStopHeight,
          line: false,
        ),
      ],
    );
  }

  Widget _buildBand(MobileDayBand band)
  {
    return _BandBlock(
      band: band,
      feminine: widget.feminine,
      minHeight: widget.minBandHeight,
      nowMinutes: _nowMinutes,
    );
  }
}

class _BandBlock extends StatelessWidget
{
  final MobileDayBand band;
  final bool feminine;
  final double minHeight;
  final ValueListenable<int?> nowMinutes;

  const _BandBlock({
    required this.band,
    required this.feminine,
    required this.minHeight,
    required this.nowMinutes,
  });

  @override
  Widget build(BuildContext context)
  {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(
              label: formatTimeOfDayShort(timeOfDayFromMinutes(band.startMinutes)),
              nowMinutes: nowMinutes,
              bandStartMinutes: band.startMinutes,
              bandEndMinutes: band.endMinutes,
            ),
            const SizedBox(width: _bodyGap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _bodyBottom),
                child: _BandBody(band: band, feminine: feminine),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Time column and line in one painter, so the present aligns without measuring.
class _Rail extends StatelessWidget
{
  final String label;

  // Set on a band's rail, which marks the present when it falls inside the band.
  final ValueListenable<int?>? nowMinutes;
  final int? bandStartMinutes;
  final int? bandEndMinutes;

  // A fixed height for the closing stop, which has no body beside it.
  final double? height;
  final bool line;

  const _Rail({
    required this.label,
    this.nowMinutes,
    this.bandStartMinutes,
    this.bandEndMinutes,
    this.height,
    this.line = true,
  });

  Widget _buildPaint(int? minutes)
  {
    final int? start = bandStartMinutes;
    final int? end = bandEndMinutes;

    final bool inside = minutes != null && start != null && end != null &&
        minutes >= start && minutes < end;

    return CustomPaint(
      painter: _RailPainter(
        label: label,
        line: line,
        nowFraction: inside ? (minutes - start) / (end - start) : null,
        nowLabel: inside ? formatTimeOfDayShort(timeOfDayFromMinutes(minutes)) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final ValueListenable<int?>? listenable = nowMinutes;

    return SizedBox(
      width: _timeWidth + _railGap + _railWidth,
      height: height,
      child: listenable == null
          ? _buildPaint(null)
          : ValueListenableBuilder<int?>(
              valueListenable: listenable,
              builder: (context, minutes, _) => _buildPaint(minutes),
            ),
    );
  }
}

class _RailPainter extends CustomPainter
{
  final String label;
  final bool line;
  final double? nowFraction;
  final String? nowLabel;

  const _RailPainter({
    required this.label,
    required this.line,
    required this.nowFraction,
    required this.nowLabel,
  });

  static final TextStyle _labelStyle = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Colors.white.withValues(alpha: 0.85),
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle _nowStyle = _labelStyle.copyWith(color: Colors.white);

  void _paintLabel(Canvas canvas, String text, TextStyle style, double centerY)
  {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(minWidth: _timeWidth, maxWidth: _timeWidth);

    painter.paint(canvas, Offset(0, centerY - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    final double x = _timeWidth + _railGap + _railWidth / 2;
    final double stopY = _stopRadius + _stopStroke / 2;

    if (line)
    {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = _railStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(Offset(x, stopY), _stopRadius, Paint()..color = AppTheme.trialDeepWater);
    canvas.drawCircle(
      Offset(x, stopY),
      _stopRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stopStroke,
    );

    _paintLabel(canvas, label, _labelStyle, stopY);

    final double? fraction = nowFraction;

    if (fraction != null)
    {
      final double y = (size.height * fraction).clamp(stopY + _stopRadius + _nowRadius, size.height);

      canvas.drawCircle(
        Offset(x, y),
        _nowRadius + _nowHalo,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      canvas.drawCircle(Offset(x, y), _nowRadius, Paint()..color = Colors.white);

      if (nowLabel case final String text)
      {
        _paintLabel(canvas, text, _nowStyle, y);
      }
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate)
  {
    return label != oldDelegate.label ||
        line != oldDelegate.line ||
        nowFraction != oldDelegate.nowFraction ||
        nowLabel != oldDelegate.nowLabel;
  }
}

class _BandBody extends StatelessWidget
{
  final MobileDayBand band;
  final bool feminine;

  const _BandBody({required this.band, required this.feminine});

  String _range(int startMinutes, int endMinutes)
  {
    return 'dalle ${formatTimeOfDayShort(timeOfDayFromMinutes(startMinutes))} '
        'alle ${formatTimeOfDayShort(timeOfDayFromMinutes(endMinutes))}';
  }

  // Title and detail, as the calendar's convocation card words them.
  (String, String) _convened(TeacherBandCall call)
  {
    final String detail = [
      for (final span in call.byMode) modeLabel(span.mode),
      convocationSummary(call),
    ].join(' · ');

    return (convocationTitle(call, feminine: feminine), detail);
  }

  List<Widget> _buildState()
  {
    switch (band.state)
    {
      case MobileBandState.convened:
        final (title, detail) = _convened(band.call!);

        return [_StateLine(title, color: _convenedText), _Detail(detail)];

      case MobileBandState.notConvened:
        return [_StateLine(unconvenedLabelFor(kTeacherRole, feminine: feminine)!, muted: true)];

      case MobileBandState.available:
        return [
          for (final span in band.availabilities) ...[
            _StateLine('$kAvailableLead ${_range(span.startMinutes, span.endMinutes)}', color: _availableText),
            _Detail(modeLabel(span.mode)),
          ],
        ];

      case MobileBandState.none:
        return [_StateLine(emptyBandLabelFor(kTeacherRole), muted: true)];
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              bandLabel(band.band).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            if (band.isPublished) ...[
              const SizedBox(width: 10),
              const MobilePill('Pubblicato'),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ..._buildState(),
        const SizedBox(height: 8),
        _Openings(openings: band.openings),
      ],
    );
  }
}

class _StateLine extends StatelessWidget
{
  final String text;
  final Color color;
  final bool muted;

  const _StateLine(this.text, {this.color = Colors.white, this.muted = false});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: muted ? 15 : 15.5,
        fontWeight: muted ? FontWeight.w600 : FontWeight.w800,
        height: 1.25,
        color: muted ? Colors.white.withValues(alpha: 0.6) : color,
      ),
    );
  }
}

class _Detail extends StatelessWidget
{
  final String text;

  const _Detail(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _Openings extends StatelessWidget
{
  final List<MobileModeSpan> openings;

  const _Openings({required this.openings});

  @override
  Widget build(BuildContext context)
  {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(
          'Apertura'.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        for (final opening in openings)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(lessonModeIcon(opening.mode), size: 16, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(
                formatMinutesRange(opening.startMinutes, opening.endMinutes),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
