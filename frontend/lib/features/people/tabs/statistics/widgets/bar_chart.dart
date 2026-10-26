import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../../shared/widgets/page_density.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';

const LinearGradient _barGradient = AppTheme.chartBarGradient;

const Color _hoveredBarColor = AppTheme.chartLilac;

// The highlight rises inside the bar: a lerp between two hues passes through a dull mix.
const Duration _hoverFill = Duration(milliseconds: 200);

// The Y axis is painted outside the scrollable area so labels stay visible.
const double _yAxisWidth = 45.0;

// Shared by the widget and the painter: if they disagree, bars and labels drift.
const double _plotBottomPadding = 52.0;

// Below this slot width the plot scrolls horizontally instead of shrinking.
const double _minBarSlotWidth = 95.0;

const double _barWidthRatio = 0.6;
const double _labelFontSize = 13;

const double _labelGap = 10;

// Bars laid across: the names' column, and the room between rows.
const double _acrossNamesShare = 0.4;
const double _acrossNamesMax = 200;
const double _acrossRowGap = 10;
const double _acrossBarHeight = 14;

class BarChart extends StatefulWidget
{
  final List<ChartDatum> data;

  const BarChart({super.key, required this.data});

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> with SingleTickerProviderStateMixin
{
  final ScrollController _scroll = ScrollController();

  final _FillLevels _fills = _FillLevels();

  // Runs only while some bar is still filling or draining.
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  int? _hoveredIndex;

  // Survives pointer exit, so the popup fades out in place.
  int? _popupIndex;

  int get _total => widget.data.fold(0, (sum, item) => sum + item.count);

  @override
  void initState()
  {
    super.initState();
    _ticker = createTicker(_tick);
    _fills.reset(widget.data.length);

    // Bars slide under a still pointer, which would leave the wrong one lit.
    _scroll.addListener(() => _hoverSlot(null));
  }

  @override
  void didUpdateWidget(covariant BarChart oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data)
    {
      _hoveredIndex = null;
      _popupIndex = null;
      _ticker.stop();
      _fills.reset(widget.data.length);
    }
  }

  @override
  void dispose()
  {
    _scroll.dispose();
    _ticker.dispose();
    _fills.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed)
  {
    final step = (elapsed - _lastTick).inMicroseconds / _hoverFill.inMicroseconds;
    final levels = _fills.levels;
    var settled = true;

    _lastTick = elapsed;

    for (var i = 0; i < levels.length; i++)
    {
      final double target = i == _hoveredIndex ? 1 : 0;

      levels[i] = target > levels[i] ? math.min(target, levels[i] + step) : math.max(target, levels[i] - step);
      settled = settled && levels[i] == target;
    }

    _fills.changed();

    if (settled)
    {
      _ticker.stop();
    }
  }

  List<Rect> _computeBarRects(double innerWidth, double chartHeight, int maxValue)
  {
    final stepX = innerWidth / widget.data.length;
    final barWidth = stepX * _barWidthRatio;

    return [
      for (var i = 0; i < widget.data.length; i++)
        () {
          final barHeight = (widget.data[i].count / maxValue) * chartHeight;
          final left = (i * stepX) + (stepX / 2) - (barWidth / 2);

          return Rect.fromLTWH(left, chartHeight - barHeight, barWidth, barHeight);
        }(),
    ];
  }

  // The whole column hit-tests, label included, so moving across bars never drops the popup.
  void _hoverAt(Offset position, double innerWidth)
  {
    final slot = (position.dx / (innerWidth / widget.data.length)).floor();

    _hoverSlot(slot >= 0 && slot < widget.data.length ? slot : null);
  }

  void _hoverSlot(int? index)
  {
    if (index == _hoveredIndex)
    {
      return;
    }

    setState(()
    {
      _hoveredIndex = index;

      if (index != null)
      {
        _popupIndex = index;
      }
    });

    if (!_ticker.isActive)
    {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  String _popupText(int index)
  {
    final datum = widget.data[index];
    final share = _total == 0 ? 0.0 : datum.count / _total * 100;

    return '${datum.label}: ${datum.count} (${share.toStringAsFixed(1)}%)';
  }

  @override
  Widget build(BuildContext context)
  {
    final maxValue = chartMaxValue(widget.data.map((item) => item.count).reduce(math.max));
    final bool dense = AppPageDensity.of(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double room = constraints.maxWidth - _yAxisWidth;

        // Dense, nothing scrolls sideways: columns too narrow for their names lay the bars across.
        if (dense && room / widget.data.length < _minBarSlotWidth)
        {
          return _BarsAcross(data: widget.data, maxValue: maxValue);
        }

        final innerWidth = dense ? room : math.max(room, widget.data.length * _minBarSlotWidth);

        // A card that lets the chart size itself gives its height as a minimum.
        final double height = constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight;
        final chartHeight = height - _plotBottomPadding;
        final barRects = _computeBarRects(innerWidth, chartHeight, maxValue);
        final popupIndex = _popupIndex;
        final scrolled = _scroll.hasClients ? _scroll.offset : 0.0;

        // The popup lives outside the scroll view, which would clip it.
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: _yAxisWidth,
                    child: CustomPaint(
                      size: Size(_yAxisWidth, height),
                      painter: _YAxisPainter(maxValue: maxValue),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: innerWidth,
                        height: height,
                        child: MouseRegion(
                          onHover: (event) => _hoverAt(event.localPosition, innerWidth),
                          onExit: (_) => _hoverSlot(null),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _BarChartPainter(
                              data: widget.data,
                              barRects: barRects,
                              hoveredIndex: _hoveredIndex,
                              fills: _fills,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (popupIndex != null && popupIndex < barRects.length)
                ChartValuePopup(
                  target: Offset(
                    _yAxisWidth + barRects[popupIndex].center.dx - scrolled,
                    barRects[popupIndex].top,
                  ),
                  text: _popupText(popupIndex),
                  isVisible: _hoveredIndex != null,
                ),
            ],
          ),
        );
      },
    );
  }
}

// One row per bar, the name on the left and the count at the end: nothing scrolls, a cut name shows whole on hover.
class _BarsAcross extends StatefulWidget
{
  final List<ChartDatum> data;
  final int maxValue;

  const _BarsAcross({required this.data, required this.maxValue});

  @override
  State<_BarsAcross> createState() => _BarsAcrossState();
}

class _BarsAcrossState extends State<_BarsAcross>
{
  int? _hoveredIndex;

  Widget _row(int index, double namesWidth)
  {
    final ChartDatum datum = widget.data[index];
    final bool hovered = index == _hoveredIndex;
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: hovered ? FontWeight.w700 : FontWeight.w600,
      color: hovered ? AppTheme.trialOcean : AppTheme.trialInk,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = _hoveredIndex == index ? null : _hoveredIndex),
      child: Padding(
        padding: EdgeInsets.only(bottom: index < widget.data.length - 1 ? _acrossRowGap : 0),
        child: Row(
          children: [
            SizedBox(
              width: namesWidth,
              child: OverflowTooltipText(text: datum.label, maxLines: 2, style: style),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AcrossBar(fraction: widget.maxValue == 0 ? 0 : datum.count / widget.maxValue, lit: hovered),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 24),
              child: Text(
                '${datum.count}',
                textAlign: TextAlign.right,
                style: style.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double namesWidth = math.min(constraints.maxWidth * _acrossNamesShare, _acrossNamesMax);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.data.length; i++) _row(i, namesWidth),
          ],
        );
      },
    );
  }
}

// The hovered bar fills with the accent from its start, as an upright one does from its foot.
class _AcrossBar extends StatelessWidget
{
  final double fraction;
  final bool lit;

  const _AcrossBar({required this.fraction, required this.lit});

  @override
  Widget build(BuildContext context)
  {
    final BorderRadius radius = BorderRadius.circular(_acrossBarHeight / 2);

    return Container(
      height: _acrossBarHeight,
      decoration: BoxDecoration(color: AppTheme.slate200.withValues(alpha: 0.6), borderRadius: radius),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0, 1),
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.chartNavy, AppTheme.chartViolet]),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: lit ? 1 : 0),
              duration: _hoverFill,
              curve: Curves.easeOut,
              builder: (context, level, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: level,
                heightFactor: 1,
                child: const ColoredBox(color: _hoveredBarColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YAxisPainter extends CustomPainter
{
  final int maxValue;

  _YAxisPainter({required this.maxValue});

  @override
  void paint(Canvas canvas, Size size)
  {
    final gridPaint = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final chartHeight = size.height - _plotBottomPadding;

    for (var i = 0; i <= gridDivisions; i++)
    {
      final y = chartHeight - (i * (chartHeight / gridDivisions));
      canvas.drawLine(Offset(size.width - 5, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: '${((maxValue / gridDivisions) * i).round()}',
        style: GoogleFonts.plusJakartaSans(color: AppTheme.trialMutedText, fontSize: _labelFontSize),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 12, y - 6));
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _YAxisPainter oldDelegate) => oldDelegate.maxValue != maxValue;
}

// Gold level per bar, 0 to 1; each moves on its own, so a quick sweep never makes one jump.
class _FillLevels extends ChangeNotifier
{
  List<double> levels = const [];

  void reset(int count)
  {
    levels = List.filled(count, 0.0);
    notifyListeners();
  }

  void changed() => notifyListeners();
}

class _BarChartPainter extends CustomPainter
{
  final List<ChartDatum> data;
  final List<Rect> barRects;
  final int? hoveredIndex;
  final _FillLevels fills;

  _BarChartPainter({
    required this.data,
    required this.barRects,
    required this.hoveredIndex,
    required this.fills,
  }) : super(repaint: fills);

  double _highlightOf(int index)
  {
    return index < fills.levels.length ? Curves.easeOut.transform(fills.levels[index]) : 0;
  }

  @override
  void paint(Canvas canvas, Size size)
  {
    final slotWidth = size.width / data.length;
    final chartHeight = size.height - _plotBottomPadding;

    final gridPaint = Paint()
      ..color = AppTheme.trialLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= gridDivisions; i++)
    {
      final y = chartHeight - (i * (chartHeight / gridDivisions));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < barRects.length; i++)
    {
      final highlight = _highlightOf(i);
      final bool hovered = i == hoveredIndex;

      final Rect rect = barRects[i];
      final RRect bar = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      // Per bar: a shader spans the rect it fills; a plot-wide one gives each bar a ramp slice.
      canvas.drawRRect(bar, Paint()..shader = _barGradient.createShader(rect));

      if (highlight > 0)
      {
        canvas.save();
        canvas.clipRRect(bar);
        canvas.drawRect(
          Rect.fromLTRB(rect.left, rect.bottom - rect.height * highlight, rect.right, rect.bottom),
          Paint()..color = _hoveredBarColor,
        );
        canvas.restore();
      }

      textPainter.text = TextSpan(
        text: data[i].label,
        style: GoogleFonts.plusJakartaSans(
          color: hovered ? AppTheme.trialOcean : AppTheme.trialMutedText,
          fontSize: _labelFontSize,
          fontWeight: hovered ? FontWeight.w700 : FontWeight.w600,
        ),
      );
      textPainter.textAlign = TextAlign.center;
      // Two lines: long city and school names do not fit one slot.
      textPainter.maxLines = 2;
      textPainter.ellipsis = '...';
      textPainter.layout(maxWidth: slotWidth - _labelGap);
      textPainter.paint(
        canvas,
        Offset(barRects[i].center.dx - (textPainter.width / 2), chartHeight + 12),
      );
    }

    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate)
  {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.data != data ||
        oldDelegate.barRects != barRects;
  }
}
