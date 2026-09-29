import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/people/models/member_trend_item.dart';
import '../../../../features/people/tabs/statistics/widgets/chart_common.dart' show chartMaxValue;
import '../../../../features/people/tabs/statistics/widgets/stats_constants.dart' show monthAbbreviations;
import '../../../shared/mobile_palette.dart';

const double _height = 168;

// Room for the scale on the left and the months underneath.
const double _left = 26;
const double _right = 12;
const double _top = 30;
const double _bottom = 24;

const double _pointRadius = 3.4;
const double _chosenRadius = 5.5;

// A tap this close to a point, sideways, picks it.
const double _reach = 24;

const Duration _popDuration = Duration(milliseconds: 240);

// How long a value stays up before it goes by itself.
const Duration _shownFor = Duration(seconds: 5);

// No hover on touch: a tap pops a point's value, hidden again by timeout or a second tap.
class MobileTrendChart extends StatefulWidget
{
  final List<MemberTrendItem> data;

  const MobileTrendChart({super.key, required this.data});

  @override
  State<MobileTrendChart> createState() => _MobileTrendChartState();
}

class _MobileTrendChartState extends State<MobileTrendChart> with SingleTickerProviderStateMixin
{
  // Kept while the value shrinks away, so it goes from where it stood.
  int? _chosen;

  Timer? _hide;

  late final AnimationController _pop = AnimationController(vsync: this, duration: _popDuration);

  late final Animation<double> _shown = CurvedAnimation(
    parent: _pop,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(MobileTrendChart oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data)
    {
      _hide?.cancel();
      _pop.value = 0;
      _chosen = null;
    }
  }

  @override
  void dispose()
  {
    _hide?.cancel();
    _pop.dispose();
    super.dispose();
  }

  void _show(int index)
  {
    _hide?.cancel();
    setState(() => _chosen = index);
    _pop.forward(from: 0);
    _hide = Timer(_shownFor, _dismiss);
  }

  void _dismiss()
  {
    _hide?.cancel();

    if (mounted && _pop.value > 0)
    {
      _pop.reverse();
    }
  }

  void _pick(Offset position, double width)
  {
    final int count = widget.data.length;

    if (count == 0)
    {
      return;
    }

    final double step = count > 1 ? (width - _left - _right) / (count - 1) : 0;
    final int nearest = step == 0 ? 0 : ((position.dx - _left) / step).round().clamp(0, count - 1);
    final double x = _left + nearest * step;

    final bool onPoint = (position.dx - x).abs() <= _reach;
    final bool alreadyUp = _chosen == nearest && _pop.status != AnimationStatus.reverse && _pop.value > 0;

    if (!onPoint || alreadyUp)
    {
      _dismiss();
    }
    else
    {
      _show(nearest);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _pick(details.localPosition, constraints.maxWidth),
        child: CustomPaint(
          size: Size(constraints.maxWidth, _height),
          painter: _TrendPainter(
            data: widget.data,
            chosen: _chosen,
            shown: _shown,
            scaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter
{
  final List<MemberTrendItem> data;
  final int? chosen;
  final TextScaler scaler;

  final Animation<double> shown;

  _TrendPainter({
    required this.data,
    required this.chosen,
    required this.shown,
    required this.scaler,
  }) : super(repaint: shown);

  TextPainter _text(
    String text, {
    double size = 10.5,
    Color color = MobilePalette.mutedText,
    FontWeight weight = FontWeight.w700,
  })
  {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    final int max = chartMaxValue(data.map((item) => item.totalMembers).fold(0, math.max));
    final double width = size.width - _left - _right;
    final double height = size.height - _top - _bottom;
    final double step = data.length > 1 ? width / (data.length - 1) : 0;

    double yOf(int value) => _top + height * (1 - value / max);

    final Paint grid = Paint()
      ..color = AppTheme.trialInk.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (final int value in [0, max ~/ 2, max])
    {
      final double y = yOf(value);
      canvas.drawLine(Offset(_left, y), Offset(size.width - _right, y), grid);

      final TextPainter label = _text('$value');
      label.paint(canvas, Offset(_left - 8 - label.width, y - label.height / 2));
    }

    final List<Offset> points = [
      for (var i = 0; i < data.length; i++) Offset(_left + i * step, yOf(data[i].totalMembers)),
    ];

    if (points.isEmpty)
    {
      return;
    }

    final Path line = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1))
    {
      line.lineTo(point.dx, point.dy);
    }

    final Path area = Path.from(line)
      ..lineTo(points.last.dx, _top + height)
      ..lineTo(points.first.dx, _top + height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.trialTurquoise.withValues(alpha: 0.32),
            AppTheme.trialTurquoise.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, _top, size.width, height)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = AppTheme.trialTealDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final Paint fill = Paint()..color = Colors.white;
    final Paint ring = Paint()
      ..color = AppTheme.trialTealDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < points.length; i++)
    {
      final double radius = i == this.chosen
          ? ui.lerpDouble(_pointRadius, _chosenRadius, shown.value.clamp(0.0, 1.0))!
          : _pointRadius;
      canvas.drawCircle(points[i], radius, fill);
      canvas.drawCircle(points[i], radius, ring);
    }

    // Every other month, counted back from the last so the newest is named.
    for (var i = data.length - 1; i >= 0; i -= 2)
    {
      final int? month = data[i].month;
      final TextPainter label = _text(month == null ? '${data[i].year}' : monthAbbreviations[month - 1]);
      final double x = (points[i].dx - label.width / 2).clamp(0.0, size.width - label.width);

      label.paint(canvas, Offset(x, size.height - label.height));
    }

    final int? chosen = this.chosen;

    if (chosen != null && shown.value > 0)
    {
      _paintValue(canvas, size, points[chosen], data[chosen].totalMembers, shown.value);
    }
  }

  // The pop may overshoot the size, never the opacity.
  void _paintValue(Canvas canvas, Size size, Offset point, int value, double shown)
  {
    final double alpha = shown.clamp(0.0, 1.0);
    final TextPainter text = _text(
      '$value',
      size: 13,
      color: Colors.white.withValues(alpha: alpha),
      weight: FontWeight.w800,
    );
    final double width = text.width + 16;
    final double height = text.height + 8;
    final double left = (point.dx - width / 2).clamp(0.0, size.width - width);
    final double top = math.max(0, point.dy - _chosenRadius - 6 - height);

    final Offset anchor = Offset(point.dx.clamp(left, left + width), top + height);

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.scale(math.max(0, shown));
    canvas.translate(-anchor.dx, -anchor.dy);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width, height), Radius.circular(height / 2)),
      Paint()..color = AppTheme.trialDeepWater.withValues(alpha: alpha),
    );
    text.paint(canvas, Offset(left + 8, top + 4));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate)
  {
    return oldDelegate.data != data || oldDelegate.chosen != chosen || oldDelegate.scaler != scaler;
  }
}
