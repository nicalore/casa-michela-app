import 'package:flutter/widgets.dart';

abstract final class MobilePalette
{
  // AppTheme.trialMutedText reads below 3:1 on the glass over the dark sea.
  static const Color mutedText = Color(0xFF3E5260);

  // Small marks of the current day.
  static const Color currentRim = Color(0xD9E3A83C);
  static const double currentRimWidth = 2;

  // The desktop's red, lightened to read on the dark sea and on white.
  static const Color nowLine = Color(0xFFE4674F);

  // Struck labels: the font's own line-through vanishes on a phone.
  static const double strikeThickness = 2.5;

  // The two modes' colours lightened to read on the dark sea.
  static const Color presenceOnSea = Color(0xFF5FD3C4);
  static const Color onlineOnSea = Color(0xFFF2BB5C);

  // Edges of the hours chips; their in-person fill is AppTheme.presenceBadge.
  static const Color presenceChipEdge = Color(0x400B6478);
  static const Color onlineChipEdge = Color(0x73E3A83C);
  static const double hoursChipRadius = 8;

  // Hours chips and lesson rows past or past the deadline: an opaque grey, never see-through on the glass.
  static const Color pastSurface = Color(0xFFD5DBDD);
  static const Color pastEdge = Color(0x1F122438);

  // A chart's months outside the chosen period; never see-through on the glass.
  static const Color chartFaded = Color(0xFF7F92A3);
}
