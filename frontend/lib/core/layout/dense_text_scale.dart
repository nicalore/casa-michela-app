import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';
import 'large_text_scale.dart';

// Below the wide window every text of the desktop app reads a tenth larger, over the user's own scale.
const double kDenseTextScale = 1.1;

class _DenseLargeScaler extends TextScaler
{
  final TextScaler base;

  const _DenseLargeScaler(this.base);

  @override
  double scale(double fontSize) => base.scale(fontSize) * kDenseTextScale;

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) => other is _DenseLargeScaler && other.base == base;

  @override
  int get hashCode => base.hashCode;
}

// The tenth counts toward the cap, so a large browser text stops at the same size on every window.
TextScaler desktopTextScalerFor(TextScaler system, {required bool dense})
{
  if (!dense)
  {
    return largeTextScalerFor(system);
  }

  if (userTextFactor(system) <= 1)
  {
    return TextScaler.linear(system.scale(1) * kDenseTextScale);
  }

  return _DenseLargeScaler(largeTextScalerFor(system, cap: kMaxTextScale / kDenseTextScale));
}

double _drawnFactor(BuildContext context) => AppBreakpoints.of(context).isDense ? kDenseTextScale : 1;

// What a box of fixed height adds for [textHeight] of its text once large text outgrows the size it was drawn for.
double largeTextRoom(BuildContext context, double textHeight)
{
  return textHeight * math.max(0, userTextFactor(MediaQuery.textScalerOf(context)) - _drawnFactor(context));
}

// For marks placed on a drawn scale, like a timeline's hours: wider ones would run into each other.
TextScaler drawnTextScaler(BuildContext context)
{
  final TextScaler scaler = MediaQuery.textScalerOf(context);
  final double drawn = _drawnFactor(context);

  return userTextFactor(scaler) <= drawn ? scaler : TextScaler.linear(drawn);
}

class DenseTextScale extends StatelessWidget
{
  final Widget child;

  const DenseTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData data = MediaQuery.of(context);
    final bool dense = AppBreakpoints.fromSize(data.size).isDense;

    // Always a MediaQuery, so crossing the threshold keeps the tree below it.
    return MediaQuery(data: data.copyWith(textScaler: desktopTextScalerFor(data.textScaler, dense: dense)), child: child);
  }
}
