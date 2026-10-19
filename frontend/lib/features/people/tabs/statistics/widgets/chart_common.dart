import 'package:flutter/painting.dart';

import '../../../../../core/theme/app_theme.dart';

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