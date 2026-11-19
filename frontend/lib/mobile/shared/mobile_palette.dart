import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colours.dart';

abstract final class MobilePalette
{
  // The top of the sea follows the theme; AppTheme.trialDeepWaterText stays Casa Michela's.
  static Color get seaTop => ThemeColours.seaTop;

  // AppTheme.trialMutedText reads below 3:1 on the glass over the dark sea.
  static Color get mutedText => ThemeColours.fixed(0xFF3E5260);

  // Small marks of the current day.
  static Color get currentRim => ThemeColours.of(0xD9E3A83C);
  static const double currentRimWidth = 2;

  // The desktop's red, lightened to read on the dark sea and on white.
  static const Color nowLine = Color(0xFFE4674F);

  // Struck labels: the font's own line-through vanishes on a phone.
  static const double strikeThickness = 2.5;

  // The two modes' colours lightened to read on the dark sea; in person, the badges' green.
  static Color get presenceOnSea => ThemeColours.of(0xFF92D3BF);
  static Color get onlineOnSea => ThemeColours.of(0xFFF2BB5C);

  // Edges of the hours chips; their in-person fill is AppTheme.presenceBadge.
  static Color get presenceChipEdge => AppTheme.presenceAccentText.withAlpha(0x40);
  static Color get onlineChipEdge => ThemeColours.of(0x73E3A83C);
  static const double hoursChipRadius = 8;

  // Hours chips and lesson rows past or past the deadline: an opaque grey, never see-through on the glass.
  static Color get pastSurface => ThemeColours.of(0xFFD5DBDD);
  static Color get pastEdge => ThemeColours.fixed(0x1F122438);

  // A chart's months outside the chosen period; never see-through on the glass.
  static Color get chartFaded => ThemeColours.fixed(0xFF7F92A3);
}
