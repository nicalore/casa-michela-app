import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../../../../core/platform/visual_effects.dart';
import '../../../models/member_trend_item.dart';
import 'stats_data.dart';

const Duration _slideDuration = Duration(milliseconds: 320);

// Point indices of a trend, both included.
typedef TrendSpan = ({int first, int last});

// Null when the period covers the whole trend.
TrendSpan? statsPeriodSpan(String period, List<MemberTrendItem> trend)
{
  final StatsPeriod parts = statsPeriodParts(period);
  final int? months = parts.months;

  if (months != null)
  {
    return months >= trend.length ? null : (first: trend.length - months, last: trend.length - 1);
  }

  final int index = trend.indexWhere((item) => item.year == parts.year && item.month == parts.month);

  return index < 0 ? null : (first: index, last: index);
}

// Edges in point indices: a month reaches half a step either side of its point.
class TrendBand
{
  final double start;
  final double end;

  // 0 over the whole trend, where no band shows.
  final double strength;

  // Per month, how far it stands as the only one chosen.
  final List<double> lone;

  const TrendBand._({required this.start, required this.end, required this.strength, required this.lone});

  factory TrendBand.over(TrendSpan? span, int count)
  {
    return TrendBand._(
      start: (span?.first ?? 0) - 0.5,
      end: (span?.last ?? count - 1) + 0.5,
      strength: span == null ? 0 : 1,
      lone: [
        for (var index = 0; index < count; index++)
          span != null && span.first == index && span.last == index ? 1 : 0,
      ],
    );
  }

  static TrendBand lerp(TrendBand from, TrendBand to, double t)
  {
    return TrendBand._(
      start: lerpDouble(from.start, to.start, t)!,
      end: lerpDouble(from.end, to.end, t)!,
      strength: lerpDouble(from.strength, to.strength, t)!,
      lone: [for (var index = 0; index < to.lone.length; index++) lerpDouble(from.lone[index], to.lone[index], t)!],
    );
  }

  bool covers(int index) => index >= start && index <= end;

  bool marks(int index) => strength >= 0.5 && covers(index);

  // Opacity of a month's label: a lone month is always named, and the labels it would touch give way.
  double labelAlpha(int index, Set<int> regular, int stride)
  {
    double crowded = 0;

    for (var other = math.max(0, index - stride + 1); other < math.min(lone.length, index + stride); other++)
    {
      if (other != index)
      {
        crowded = math.max(crowded, lone[other]);
      }
    }

    return math.max(lone[index], regular.contains(index) ? 1 - crowded : 0);
  }
}

class TrendBandBuilder extends StatefulWidget
{
  final TrendSpan? span;
  final int count;
  final Widget Function(BuildContext context, TrendBand band) builder;

  const TrendBandBuilder({super.key, required this.span, required this.count, required this.builder});

  @override
  State<TrendBandBuilder> createState() => _TrendBandBuilderState();
}

class _TrendBandBuilderState extends State<TrendBandBuilder> with SingleTickerProviderStateMixin
{
  late final AnimationController _slide = AnimationController(vsync: this, duration: _slideDuration, value: 1);
  late final Animation<double> _eased = CurvedAnimation(parent: _slide, curve: Curves.easeInOutCubic);

  late TrendBand _from = TrendBand.over(widget.span, widget.count);
  late TrendBand _to = _from;

  TrendBand get _now => _slide.isCompleted ? _to : TrendBand.lerp(_from, _to, _eased.value);

  @override
  void didUpdateWidget(TrendBandBuilder oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.span == widget.span && oldWidget.count == widget.count)
    {
      return;
    }

    final TrendBand next = TrendBand.over(widget.span, widget.count);

    if (oldWidget.count != widget.count || !VisualEffects.on)
    {
      _from = next;
      _to = next;
      _slide.value = 1;

      return;
    }

    _from = _now;
    _to = next;
    _slide.value = 0;

    // A ticker started during a slow build counts from that frame and skips the slide.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        _slide.forward();
      }
    });
  }

  @override
  void dispose()
  {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return AnimatedBuilder(
      animation: _eased,
      builder: (context, _) => widget.builder(context, _now),
    );
  }
}
