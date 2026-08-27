import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double _fieldFontSize = 13;

const double _eyebrowFontSize = 11;

// Used by the text field to reserve the label's height even when it shows none.
const double _fieldLineHeightRatio = 1.28;

const double kFieldLabelLineHeight = _fieldFontSize * _fieldLineHeightRatio;

class AppFieldLabel extends StatelessWidget
{
  final String text;

  const AppFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.trialOcean,
        fontWeight: FontWeight.w700,
        fontSize: _fieldFontSize,
        height: _fieldLineHeightRatio,
      ),
    );
  }
}

TextStyle eyebrowTextStyle()
{
  return GoogleFonts.plusJakartaSans(
    color: AppTheme.trialMutedText,
    fontWeight: FontWeight.w600,
    fontSize: _eyebrowFontSize,
    letterSpacing: 1.4,
  );
}

class AppEyebrow extends StatelessWidget
{
  final String text;

  const AppEyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(text.toUpperCase(), style: eyebrowTextStyle());
  }
}
