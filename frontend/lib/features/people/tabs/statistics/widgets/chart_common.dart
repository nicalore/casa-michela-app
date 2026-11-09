import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/money.dart' show formatAmount;
import '../../../../../core/utils/week_range.dart' show formatMinutes;

// The line gradient's colour at a fraction of the plot width, for the markers on it.
Color chartLineColorAt(double fraction)
{
  return Color.lerp(AppTheme.chartOcean, AppTheme.chartViolet, fraction.clamp(0.0, 1.0))!;
}

class ChartDatum
{
  final String label;
  final int count;

  const ChartDatum({required this.label, required this.count});
}

// Shared by the line and bar charts.
const int gridDivisions = 4;

// Tallest value + 20% headroom, rounded up to a gridDivisions multiple for whole labels.
int chartMaxValue(int rawMax)
{
  final withHeadroom = rawMax == 0 ? gridDivisions : (rawMax * 1.2).ceil();

  if (withHeadroom < gridDivisions)
  {
    return gridDivisions;
  }

  return ((withHeadroom + gridDivisions - 1) ~/ gridDivisions) * gridDivisions;
}
// Whole hours a step: the top in minutes.
int _hoursTop(int rawMinutes) => chartMaxValue((rawMinutes / 60).ceil()) * 60;

String _hoursAxis(int minutes) => '${(minutes / 60).round()}h';

// Steps of 1, 2 or 5 euros times a power of ten: the top in cents.
int _centsTop(int rawCents)
{
  final double step = rawCents * 1.2 / 100 / gridDivisions;
  int magnitude = 1;

  while (magnitude * 10 <= step)
  {
    magnitude *= 10;
  }

  for (final int factor in const [1, 2, 5, 10])
  {
    if (factor * magnitude >= step)
    {
      return factor * magnitude * gridDivisions * 100;
    }
  }

  return magnitude * 10 * gridDivisions * 100;
}

// The scale's steps are whole euros.
String _euroAxis(int cents)
{
  final String amount = formatAmount(cents);

  return amount.endsWith(',00') ? amount.substring(0, amount.length - 3) : amount;
}

String _plainCount(int value) => '$value';

// How a trend's values read: the top of its scale, the scale's labels, a point's own value.
class TrendScale
{
  final int Function(int rawMax) top;
  final String Function(int value) axis;
  final String Function(int value) point;

  const TrendScale({required this.top, required this.axis, required this.point});

  static const TrendScale count = TrendScale(top: chartMaxValue, axis: _plainCount, point: _plainCount);
  static const TrendScale minutes = TrendScale(top: _hoursTop, axis: _hoursAxis, point: formatMinutes);
  static const TrendScale cents = TrendScale(top: _centsTop, axis: _euroAxis, point: formatAmount);
}

// How far each bar's hover highlight has risen, 0 to 1.
class ChartFillLevels extends ChangeNotifier
{
  List<double> levels = const [];

  void reset(int count)
  {
    levels = List.filled(count, 0.0);
    notifyListeners();
  }

  // Toward 1 for the hovered bar and 0 for the others; true once every level is there.
  bool advance(int? hovered, double step)
  {
    var settled = true;

    for (var i = 0; i < levels.length; i++)
    {
      final double target = i == hovered ? 1 : 0;

      levels[i] = target > levels[i] ? math.min(target, levels[i] + step) : math.max(target, levels[i] - step);
      settled = settled && levels[i] == target;
    }

    notifyListeners();

    return settled;
  }

  double eased(int index) => index < levels.length ? Curves.easeOut.transform(levels[index]) : 0;
}
