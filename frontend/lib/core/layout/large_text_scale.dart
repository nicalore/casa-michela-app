import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// The largest text size the layouts are built for.
const double kMaxTextScale = 1.5;

// Sizes up to here take the whole scale; from the second on they take half, so titles keep to the page.
const double _wholeUpTo = 18;
const double _halfFrom = 32;

// Read at body size: Android 14 already bends the scale for larger type.
const double _readAt = 14;

double userTextFactor(TextScaler system) => system.scale(_readAt) / _readAt;

// Below 1 the system's own scaling stays, so small text sizes render as they always did.
TextScaler largeTextScalerFor(TextScaler system, {double cap = kMaxTextScale})
{
  final double factor = userTextFactor(system);

  return factor <= 1 ? system : _LargeTextScaler(math.min(factor, cap));
}

class _LargeTextScaler extends TextScaler
{
  @override
  final double textScaleFactor;

  const _LargeTextScaler(this.textScaleFactor);

  @override
  double scale(double fontSize)
  {
    final double past = ((fontSize - _wholeUpTo) / (_halfFrom - _wholeUpTo)).clamp(0.0, 1.0);

    return fontSize * (1 + (textScaleFactor - 1) * (1 - past / 2));
  }

  // Equal scalers keep MediaQuery's dependents quiet through every keyboard frame.
  @override
  bool operator ==(Object other) => other is _LargeTextScaler && other.textScaleFactor == textScaleFactor;

  @override
  int get hashCode => textScaleFactor.hashCode;
}
