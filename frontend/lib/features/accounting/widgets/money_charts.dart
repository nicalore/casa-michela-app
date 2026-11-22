import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../people/tabs/statistics/widgets/chart_common.dart';
import '../../people/tabs/statistics/widgets/chart_value_popup.dart';
import '../../people/tabs/statistics/widgets/stats_constants.dart';
import '../../people/tabs/statistics/widgets/trend_band.dart';

// Twelve months of euros as lines (several series), stacked bars or bars either side of zero.
// The month band and the look follow TrendLineChart.

const double _padTop = 8;
const double _padBottom = 38;
const double _padRight = 10;
const double _minLeft = 40;
const double _labelGap = 8;

const double _bandAbove = 8;
const double _bandBelow = 45;
const double _bandRadius = 12;
const double _bandAlpha = 0.1;
const double _bandOverhangLeft = 7;
const double _bandOverhangRight = 10;

const double _barWidthRatio = 0.6;
const double _barRadius = 8;

TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(color: AppTheme.trialMutedText, fontSize: 13);

class MoneySeries
{
  final String label;
  final Color color;
  final List<int> cents;

  const MoneySeries({required this.label, required this.color, required this.cents});
}

// 1, 2, 2.5 or 5 euros times a power of ten, in cents.
int _niceStep(double cents)
{
  final double euros = math.max(cents / 100, 1);
  var magnitude = 1;

  while (magnitude * 10 <= euros)
  {
    magnitude *= 10;
  }

  for (final double factor in const [1, 2, 2.5, 5, 10])
  {
    if (factor * magnitude >= euros)
    {
      return (factor * magnitude * 100).round();
    }
  }

  return magnitude * 1000;
}

// Ends and step of the scale: four steps over the values, zero always on it.
class _Scale
{
  final int low;
  final int high;
  final int step;

  const _Scale(this.low, this.high, this.step);

  factory _Scale.over(int lowest, int highest)
  {
    final int floor = math.min(lowest, 0);
    final int ceiling = math.max(highest, 0);

    if (floor == 0)
    {
      final int step = _niceStep(ceiling * 1.2 / gridDivisions);

      return _Scale(0, step * gridDivisions, step);
    }

    final int step = _niceStep((ceiling - floor) * 1.15 / gridDivisions);
    final int high = ceiling == 0 ? 0 : (ceiling / step).ceil() * step;

    return _Scale((floor / step).floor() * step, high, step);
  }

  List<int> get ticks => [for (var value = low; value <= high; value += step) value];

  @override
  bool operator ==(Object other) => other is _Scale && other.low == low && other.high == high && other.step == step;

  @override
  int get hashCode => Object.hash(low, high, step);
}

// The scale's labels are whole euros.
String _axisLabel(int cents)
{
  final String amount = formatSignedAmount(cents);

  return amount.endsWith(',00') ? amount.substring(0, amount.length - 3) : amount;
}

double _leftOf(_Scale scale)
{
  final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
  var widest = 0.0;

  for (final int tick in scale.ticks)
  {
    painter.text = TextSpan(text: _axisLabel(tick), style: _labelStyle);
    painter.layout();
    widest = math.max(widest, painter.width);
  }

  painter.dispose();

  return math.max(_minLeft, (widest + _labelGap).ceilToDouble());
}

// Where each month and amount lands; shared by the painter and the hit testing.
class _Frame
{
  final Size size;
  final double left;
  final int count;
  final bool bars;
  final _Scale scale;

  const _Frame(this.size, this.left, this.count, this.bars, this.scale);

  double get plotWidth => size.width - left - _padRight;

  double get bottom => size.height - _padBottom;

  double get plotHeight => bottom - _padTop;

  // Points span the plot; bars stand mid-slot.
  double get step => bars ? plotWidth / count : (count > 1 ? plotWidth / (count - 1) : plotWidth);

  double xOf(double index) => left + (bars ? index + 0.5 : index) * step;

  double yOf(int cents) => bottom - (cents - scale.low) / (scale.high - scale.low) * plotHeight;

  int indexAt(double x)
  {
    final double slot = bars ? (x - left) / step - 0.5 : (x - left) / step;

    return slot.round().clamp(0, count - 1);
  }

  @override
  bool operator ==(Object other) =>
      other is _Frame &&
      other.size == size &&
      other.left == left &&
      other.count == count &&
      other.bars == bars &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(size, left, count, bars, scale);
}

class MoneyChart extends StatefulWidget
{
  final List<DateTime> months;

  // Lines: one or more series.
  final List<MoneySeries> lines;

  // Bars: each month's parts from the bottom up, coloured in order; one part may go below zero.
  final List<List<int>> stacks;
  final List<Color> stackColors;

  // The months of the chosen period; null marks none.
  final TrendSpan? span;

  final Widget Function(int index) tooltip;

  const MoneyChart.lines({
    super.key,
    required this.months,
    required this.lines,
    required this.tooltip,
    this.span,
  })  : stacks = const [],
        stackColors = const [];

  const MoneyChart.bars({
    super.key,
    required this.months,
    required this.stacks,
    required this.stackColors,
    required this.tooltip,
    this.span,
  }) : lines = const [];

  bool get isBars => lines.isEmpty;

  @override
  State<MoneyChart> createState() => _MoneyChartState();
}

class _MoneyChartState extends State<MoneyChart>
{
  int? _hovered;

  // Survives the pointer leaving, so the popup fades out in place.
  int? _popup;

  _Scale get _scale
  {
    var lowest = 0;
    var highest = 0;

    if (widget.isBars)
    {
      for (final List<int> parts in widget.stacks)
      {
        final int up = parts.where((part) => part > 0).fold(0, (sum, part) => sum + part);
        final int down = parts.where((part) => part < 0).fold(0, (sum, part) => sum + part);

        highest = math.max(highest, up);
        lowest = math.min(lowest, down);
      }
    }
    else
    {
      for (final MoneySeries series in widget.lines)
      {
        for (final int cents in series.cents)
        {
          highest = math.max(highest, cents);
          lowest = math.min(lowest, cents);
        }
      }
    }

    return _Scale.over(lowest, highest);
  }

  double _topOf(int index, _Frame frame)
  {
    if (widget.isBars)
    {
      final int up = widget.stacks[index].where((part) => part > 0).fold(0, (sum, part) => sum + part);

      return frame.yOf(up);
    }

    var top = frame.bottom;

    for (final MoneySeries series in widget.lines)
    {
      top = math.min(top, frame.yOf(series.cents[index]));
    }

    return top;
  }

  void _hover(int? index)
  {
    if (index == _hovered)
    {
      return;
    }

    setState(()
    {
      _hovered = index;

      if (index != null)
      {
        _popup = index;
      }
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final _Scale scale = _scale;
    final double left = _leftOf(scale);
    final int count = widget.months.length;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final _Frame frame = _Frame(constraints.biggest, left, count, widget.isBars, scale);
        final int? popup = _popup;

        return MouseRegion(
          onHover: (event) => _hover(count == 0 ? null : frame.indexAt(event.localPosition.dx)),
          onExit: (_) => _hover(null),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TrendBandBuilder(
                  span: widget.span,
                  count: count,
                  builder: (context, band) => CustomPaint(
                    painter: _MoneyPainter(
                      frame: frame,
                      months: widget.months,
                      lines: widget.lines,
                      stacks: widget.stacks,
                      stackColors: widget.stackColors,
                      band: band,
                      hovered: _hovered,
                    ),
                  ),
                ),
              ),
              if (popup != null && popup < count)
                ChartValuePopup(
                  target: Offset(frame.xOf(popup.toDouble()), _topOf(popup, frame)),
                  content: widget.tooltip(popup),
                  isVisible: _hovered != null,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MoneyPainter extends CustomPainter
{
  final _Frame frame;
  final List<DateTime> months;
  final List<MoneySeries> lines;
  final List<List<int>> stacks;
  final List<Color> stackColors;
  final TrendBand band;
  final int? hovered;

  _MoneyPainter({
    required this.frame,
    required this.months,
    required this.lines,
    required this.stacks,
    required this.stackColors,
    required this.band,
    required this.hovered,
  });

  bool get _bars => lines.isEmpty;

  Rect get _bandRect
  {
    if (_bars)
    {
      return Rect.fromLTRB(
        frame.xOf(band.start),
        _padTop - _bandAbove,
        frame.xOf(band.end),
        frame.bottom + _bandBelow,
      );
    }

    return Rect.fromLTRB(
      math.max(frame.xOf(band.start), frame.left - _bandOverhangLeft),
      _padTop - _bandAbove,
      math.min(frame.xOf(band.end), frame.size.width + _bandOverhangRight),
      frame.bottom + _bandBelow,
    );
  }

  void _paintGrid(Canvas canvas, TextPainter text)
  {
    final Paint grid = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1;

    for (final int tick in frame.scale.ticks)
    {
      final double y = frame.yOf(tick);

      canvas.drawLine(Offset(frame.left, y), Offset(frame.size.width, y), grid);

      text.text = TextSpan(text: _axisLabel(tick), style: _labelStyle);
      text.layout();
      text.paint(canvas, Offset(frame.left - text.width - _labelGap, y - text.height / 2));
    }

    // Zero stands out when the scale goes below it.
    if (frame.scale.low < 0)
    {
      final double zero = frame.yOf(0);

      canvas.drawLine(
        Offset(frame.left, zero),
        Offset(frame.size.width, zero),
        Paint()
          ..color = AppTheme.chartGray
          ..strokeWidth = 1.2,
      );
    }
  }

  // The last month is always named; between, as many as fit.
  ({Set<int> indices, int stride}) _labelled(TextPainter text)
  {
    final int count = months.length;

    if (count <= 1)
    {
      return (indices: {0}, stride: 1);
    }

    text.text = TextSpan(text: '${monthAbbreviations[0]}\n9999', style: _labelStyle);
    text.layout();

    final double needed = text.width + _labelGap;
    final int stride = needed > frame.step ? (needed / frame.step).ceil() : 1;
    final List<int> indices = [for (var index = 0; index < count; index += stride) index];
    final int last = count - 1;

    if (indices.last != last)
    {
      if (frame.xOf(last.toDouble()) - frame.xOf(indices.last.toDouble()) < needed)
      {
        indices.removeLast();
      }

      indices.add(last);
    }

    return (indices: indices.toSet(), stride: stride);
  }

  void _paintMonths(Canvas canvas, TextPainter text)
  {
    final ({Set<int> indices, int stride}) shown = _labelled(text);

    for (var index = 0; index < months.length; index++)
    {
      // A lone month is always named, and the labels it would touch give way, as in TrendLineChart.
      final double alpha = band.labelAlpha(index, shown.indices, shown.stride);

      if (alpha <= 0)
      {
        continue;
      }

      final bool marked = band.marks(index);
      final DateTime month = months[index];

      text.text = TextSpan(
        text: '${monthAbbreviations[month.month - 1]}\n${month.year}',
        style: _labelStyle.copyWith(
          color: (marked ? AppTheme.trialOceanText : AppTheme.trialMutedText).withValues(alpha: alpha),
          fontWeight: marked ? FontWeight.w800 : null,
        ),
      );
      text.textAlign = TextAlign.center;
      text.layout();
      text.paint(canvas, Offset(frame.xOf(index.toDouble()) - text.width / 2, frame.bottom + _labelGap));
    }
  }

  void _paintLines(Canvas canvas)
  {
    for (final MoneySeries series in lines)
    {
      final Path path = Path();

      for (var index = 0; index < series.cents.length; index++)
      {
        final Offset point = Offset(frame.xOf(index.toDouble()), frame.yOf(series.cents[index]));

        if (index == 0)
        {
          path.moveTo(point.dx, point.dy);
        }
        else
        {
          path.lineTo(point.dx, point.dy);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = series.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (var index = 0; index < series.cents.length; index++)
      {
        final Offset point = Offset(frame.xOf(index.toDouble()), frame.yOf(series.cents[index]));
        final bool lit = index == hovered;

        canvas.drawCircle(point, lit ? 7 : 5, Paint()..color = lit ? AppTheme.surface : series.color);
        canvas.drawCircle(point, lit ? 5 : 3, Paint()..color = lit ? series.color : AppTheme.surface);
      }
    }
  }

  // Grey outside the band, as the other charts do; a negative month in lilac.
  void _paintBars(Canvas canvas)
  {
    final double width = frame.step * _barWidthRatio;
    final double zero = frame.yOf(0);

    for (var index = 0; index < stacks.length; index++)
    {
      final double x = frame.xOf(index.toDouble()) - width / 2;
      final bool inside = band.strength == 0 || band.covers(index);
      final List<int> parts = stacks[index];
      final int lastUp = parts.lastIndexWhere((part) => part > 0);
      final int up = parts.where((part) => part > 0).fold(0, (sum, part) => sum + part);
      var base = 0;

      // Grey in one piece: stacked, the joins between the parts would show.
      if (!inside && up > 0)
      {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(x, frame.yOf(up), x + width, zero),
            topLeft: const Radius.circular(_barRadius),
            topRight: const Radius.circular(_barRadius),
          ),
          Paint()..color = AppTheme.chartGrayLight,
        );
      }

      for (var part = 0; part < parts.length; part++)
      {
        final int cents = parts[part];

        if (cents == 0)
        {
          continue;
        }

        if (cents < 0)
        {
          final Rect rect = Rect.fromLTRB(x, zero, x + width, frame.yOf(cents));

          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              bottomLeft: const Radius.circular(_barRadius),
              bottomRight: const Radius.circular(_barRadius),
            ),
            Paint()..color = inside ? AppTheme.chartLilac : AppTheme.chartGrayLight,
          );

          continue;
        }

        final Rect rect = Rect.fromLTRB(x, frame.yOf(base + cents), x + width, frame.yOf(base));
        final Radius top = part == lastUp ? const Radius.circular(_barRadius) : Radius.zero;
        final Paint paint = Paint();

        base += cents;

        if (!inside)
        {
          continue;
        }

        if (parts.length == 1)
        {
          paint.shader = AppTheme.chartBarGradient.createShader(rect);
        }
        else
        {
          paint.color = stackColors[part % stackColors.length];
        }

        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: top, topRight: top), paint);
      }
    }
  }

  void _paintHover(Canvas canvas)
  {
    final int? index = hovered;

    if (index == null || index >= months.length)
    {
      return;
    }

    final double x = frame.xOf(index.toDouble());

    if (_bars)
    {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - frame.step / 2, _padTop, x + frame.step / 2, frame.bottom),
          const Radius.circular(_barRadius),
        ),
        Paint()..color = AppTheme.chartHover,
      );

      return;
    }

    canvas.drawLine(
      Offset(x, _padTop),
      Offset(x, frame.bottom),
      Paint()
        ..color = AppTheme.trialMutedText.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    if (months.isEmpty)
    {
      return;
    }

    final TextPainter text = TextPainter(textDirection: TextDirection.ltr);

    canvas.drawRRect(
      RRect.fromRectAndRadius(_bandRect, const Radius.circular(_bandRadius)),
      Paint()..color = AppTheme.chartOcean.withValues(alpha: _bandAlpha * band.strength),
    );

    _paintGrid(canvas, text);
    _paintMonths(canvas, text);
    _paintHover(canvas);

    if (_bars)
    {
      _paintBars(canvas);
    }
    else
    {
      _paintLines(canvas);
    }

    text.dispose();
  }

  @override
  bool shouldRepaint(covariant _MoneyPainter oldDelegate)
  {
    return oldDelegate.frame != frame ||
        oldDelegate.months != months ||
        oldDelegate.lines != lines ||
        oldDelegate.stacks != stacks ||
        oldDelegate.band != band ||
        oldDelegate.hovered != hovered;
  }
}
