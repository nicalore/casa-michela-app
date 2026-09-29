import 'package:flutter/widgets.dart';

abstract final class MobilePalette
{
  // AppTheme.trialMutedText reads below 3:1 on the glass over the dark sea.
  static const Color mutedText = Color(0xFF3E5260);

  static const Color currentRim = Color(0xD9E3A83C);
  static const double currentRimWidth = 2;

  // The desktop's red, lightened to read on the dark sea and on white.
  static const Color nowLine = Color(0xFFE4674F);

  // The two modes' colours lightened to read on the dark sea.
  static const Color presenceOnSea = Color(0xFF5FD3C4);
  static const Color onlineOnSea = Color(0xFFF2BB5C);
}
