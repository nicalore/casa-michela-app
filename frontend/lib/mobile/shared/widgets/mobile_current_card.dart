import 'package:flutter/widgets.dart';

import '../../../core/theme/app_theme.dart';

// Use as a foregroundDecoration, so the content keeps its place.
class MobileCurrentCard extends BoxDecoration
{
  static const double rimWidth = 3;

  MobileCurrentCard(BorderRadius radius)
    : super(
        borderRadius: radius,
        border: Border.fromBorderSide(
          BorderSide(color: AppTheme.trialGold, width: rimWidth, strokeAlign: BorderSide.strokeAlignOutside),
        ),
      );
}
