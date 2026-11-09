import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/people/models/member_trend_item.dart';
import '../../../../features/people/tabs/statistics/widgets/chart_common.dart' show TrendScale;
import '../../../../features/people/tabs/statistics/widgets/stats_constants.dart' show monthAbbreviations;
import '../../../../features/people/tabs/statistics/widgets/trend_band.dart';
import '../../../shared/mobile_palette.dart';

const double _height = 168;

// Room for the scale on the left and the months underneath.
const double _left = 26;
const double _right = 12;
const double _top = 30;
const double _bottom = 24;

const double _pointRadius = 3.4;
const double _chosenRadius = 5.5;

// Every other month is named.
const int _labelStride = 2;

const double _scaleGap = 8;
const double _barWidthRatio = 0.56;
const double _barRadius = 4;

TextStyle _scaleStyle({Color color = MobilePalette.mutedText}) =>
    GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: color);

// Room for the scale of charts stacked in one card, so their plots line up.
double mobileTrendPadding(
  List<({List<MemberTrendItem> data, TrendScale scale})> charts,
  TextScaler scaler,
)
{
  double widest = 0;

  for (final chart in charts)
  {
    final int top = chart.scale.top(chart.data.map((item) => item.totalMembers).fold(0, math.max));
    final TextPainter label = TextPainter(
      text: TextSpan(text: chart.scale.axis(top), style: _scaleStyle()),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    widest = math.max(widest, label.width);
    label.dispose();
  }

  return math.max(_left, (widest + _scaleGap).ceilToDouble());
}

// Points span the plot; bars stand in the middle of equal slots.
double _xOf(double index, double left, double width, int count, bool bars)
{
  if (bars)
  {
    return left + (index + 0.5) * width / count;
  }

  return left + index * (count > 1 ? width / (count - 1) : 0);
}

// Short of the scale, past the first point.
const double _bandOverhang = 7;
const double _bandAbove = 12;
const double _bandBelow = 2;
const double _bandRadius = 9;
const double _bandAlpha = 0.5;

// A tap this close to a point, sideways, picks it.
const double _reach = 24;

const Duration _popDuration = Duration(milliseconds: 240);

// How long a value stays up before it goes by itself.
const Duration _shownFor = Duration(seconds: 5);

// No hover on touch: a tap pops a point's value, hidden again by timeout or a second tap.
class MobileTrendChart extends StatefulWidget
{
  final List<MemberTrendItem> data;

  // The months of the chosen period; null marks none.
  final TrendSpan? span;

  final TrendScale scale;

  // Months as bars, for sums such as pay.
  final bool bars;

  // Room for the scale; charts stacked in one card pass the same.
  final double? leftPadding;

  const MobileTrendChart({
    super.key,
    required this.data,
    this.span,
    this.scale = TrendScale.count,
    this.bars = false,
    this.leftPadding,
  });

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

  double get _leftPadding => widget.leftPadding ?? _left;

  void _pick(Offset position, double width)
  {
    final int count = widget.data.length;

    if (count == 0)
    {
      return;
    }

    final double left = _leftPadding;
    final double plot = width - left - _right;
    final double step = widget.bars ? plot / count : (count > 1 ? plot / (count - 1) : 0);
    final int nearest = widget.bars
        ? ((position.dx - left) / step).floor().clamp(0, count - 1)
        : (step == 0 ? 0 : ((position.dx - left) / step).round().clamp(0, count - 1));
    final double x = _xOf(nearest.toDouble(), left, plot, count, widget.bars);

    // A bar answers anywhere in its column.
    final bool onPoint = widget.bars
        ? position.dx >= left && position.dx < width - _right
        : (position.dx - x).abs() <= _reach;
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
        child: TrendBandBuilder(
          span: widget.span,
          count: widget.data.length,
          builder: (context, band) => CustomPaint(
            size: Size(constraints.maxWidth, _height),
            painter: _TrendPainter(
              data: widget.data,
              chosen: _chosen,
              shown: _shown,
              scaler: MediaQuery.textScalerOf(context),
              band: band,
              left: _leftPadding,
              scale: widget.scale,
              bars: widget.bars,
            ),
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
  final TrendBand band;
  final double left;
  final TrendScale scale;
  final bool bars;

  final Animation<double> shown;

  _TrendPainter({
    required this.data,
    required this.chosen,
    required this.shown,
    required this.scaler,
    required this.band,
    required this.left,
    required this.scale,
    required this.bars,
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
        style: _scaleStyle(color: color).copyWith(fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    final int max = scale.top(data.map((item) => item.totalMembers).fold(0, math.max));
    final double width = size.width - left - _right;
    final double height = size.height - _top - _bottom;

    double xOf(double index) => _xOf(index, left, width, data.length, bars);
    double yOf(int value) => _top + height * (1 - value / max);

    // Bars end within the plot: their band's outer edges reach the line's as it arrives there.
    final double first = math.max(_xOf(-0.5, left, width, data.length, false), left - _bandOverhang);
    final double last = math.min(_xOf(data.length - 0.5, left, width, data.length, false), size.width);
    final double toFirst = bars ? (0.5 - band.start).clamp(0.0, 1.0) : 0;
    final double toLast = bars ? (band.end - (data.length - 1.5)).clamp(0.0, 1.0) : 0;

    final Rect bandRect = Rect.fromLTRB(
      bars ? xOf(band.start) + (first - left) * toFirst : math.max(xOf(band.start), first),
      _top - _bandAbove,
      bars ? xOf(band.end) + (last - (left + width)) * toLast : math.min(xOf(band.end), last),
      size.height + _bandBelow,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bandRect, const Radius.circular(_bandRadius)),
      Paint()..color = Colors.white.withValues(alpha: _bandAlpha * band.strength),
    );

    final Paint grid = Paint()
      ..color = AppTheme.trialInk.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (final int value in [0, max ~/ 2, max])
    {
      final double y = yOf(value);
      canvas.drawLine(Offset(left, y), Offset(size.width - _right, y), grid);

      final TextPainter label = _text(scale.axis(value));
      label.paint(canvas, Offset(left - _scaleGap - label.width, y - label.height / 2));
    }

    final List<Offset> points = [
      for (var i = 0; i < data.length; i++) Offset(xOf(i.toDouble()), yOf(data[i].totalMembers)),
    ];

    if (points.isEmpty)
    {
      return;
    }

    if (bars)
    {
      _paintBars(canvas, points, width, _top + height, bandRect);
    }
    else
    {
      _paintLine(canvas, size, points, height, bandRect);
    }

    // Counted back from the last so the newest is named.
    final Set<int> regular = {for (var i = data.length - 1; i >= 0; i -= _labelStride) i};

    for (var i = 0; i < data.length; i++)
    {
      final double alpha = band.labelAlpha(i, regular, _labelStride);

      if (alpha == 0)
      {
        continue;
      }

      final bool marked = band.marks(i);
      final int? month = data[i].month;
      final TextPainter label = _text(
        month == null ? '${data[i].year}' : monthAbbreviations[month - 1],
        color: (marked ? AppTheme.chartViolet : MobilePalette.mutedText).withValues(alpha: alpha),
        weight: marked ? FontWeight.w800 : FontWeight.w700,
      );
      final double x = (points[i].dx - label.width / 2).clamp(0.0, size.width - label.width);

      label.paint(canvas, Offset(x, size.height - label.height));
    }

    final int? chosen = this.chosen;

    if (chosen != null && shown.value > 0)
    {
      _paintValue(canvas, size, points[chosen], data[chosen].totalMembers, shown.value);
    }
  }

  void _paintLine(Canvas canvas, Size size, List<Offset> points, double height, Rect bandRect)
  {
    final Path line = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1))
    {
      line.lineTo(point.dx, point.dy);
    }

    final Path area = Path.from(line)
      ..lineTo(points.last.dx, _top + height)
      ..lineTo(points.first.dx, _top + height)
      ..close();

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.clipRect(bandRect, clipOp: ui.ClipOp.difference);
    canvas.drawPath(line, stroke..color = MobilePalette.chartFaded);
    canvas.restore();

    canvas.save();
    canvas.clipRect(bandRect);
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.chartViolet.withValues(alpha: 0.24),
            AppTheme.chartViolet.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, _top, size.width, height)),
    );

    canvas.drawPath(line, stroke..color = AppTheme.chartViolet);
    canvas.restore();

    final Paint fill = Paint()..color = Colors.white;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < points.length; i++)
    {
      final double radius = i == chosen
          ? ui.lerpDouble(_pointRadius, _chosenRadius, shown.value.clamp(0.0, 1.0))!
          : _pointRadius;
      canvas.drawCircle(points[i], radius, fill);
      canvas.drawCircle(points[i], radius, ring..color = band.covers(i) ? AppTheme.chartViolet : MobilePalette.chartFaded);
    }
  }

  // Faded outside the band and violet inside, cut where the band's edge passes as it slides.
  void _paintBars(Canvas canvas, List<Offset> tops, double width, double base, Rect bandRect)
  {
    final double barWidth = width / data.length * _barWidthRatio;
    final List<RRect> columns = [
      for (var i = 0; i < data.length; i++)
        if (data[i].totalMembers > 0)
          RRect.fromRectAndCorners(
            Rect.fromLTRB(tops[i].dx - barWidth / 2, tops[i].dy, tops[i].dx + barWidth / 2, base),
            topLeft: const Radius.circular(_barRadius),
            topRight: const Radius.circular(_barRadius),
          ),
    ];

    canvas.save();
    canvas.clipRect(bandRect, clipOp: ui.ClipOp.difference);

    for (final bar in columns)
    {
      canvas.drawRRect(bar, Paint()..color = MobilePalette.chartFaded);
    }

    canvas.restore();
    canvas.save();
    canvas.clipRect(bandRect);

    for (final bar in columns)
    {
      canvas.drawRRect(bar, Paint()..color = AppTheme.chartViolet);
    }

    canvas.restore();
  }

  // The pop may overshoot the size, never the opacity.
  void _paintValue(Canvas canvas, Size size, Offset point, int value, double shown)
  {
    final double alpha = shown.clamp(0.0, 1.0);
    final TextPainter text = _text(
      scale.point(value),
      size: 13,
      color: Colors.white.withValues(alpha: alpha),
      weight: FontWeight.w800,
    );
    final double width = text.width + 16;
    final double height = text.height + 8;
    final double left = (point.dx - width / 2).clamp(0.0, size.width - width);
    final double top = math.max(0, point.dy - (bars ? 0 : _chosenRadius) - 6 - height);

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
    return oldDelegate.data != data ||
        oldDelegate.chosen != chosen ||
        oldDelegate.scaler != scaler ||
        oldDelegate.band != band;
  }
}
