import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// The two ways this app writes the name of something above the thing itself.
//
// [AppFieldLabel] names a single field: the one datum under it. [AppEyebrow]
// names a block: a dialog, a page, a group of things of the same shape.
//
// The test for picking one: if it is one of several blocks of the same shape,
// it is an eyebrow; if it names a single datum, it is a field label.

const double _fieldFontSize = 13;

const double _eyebrowFontSize = 11;

// Kept here because the text field uses it to reserve the label's height even
// when it does not show one.
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

// Exposed for callers that cannot use [AppEyebrow] as it is — a card that has
// to ellipsize its own and spell it out on hover.
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
