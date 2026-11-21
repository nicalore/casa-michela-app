import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/dark_colours.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../shared/widgets/holiday_snow.dart';

const double _blurSigma = 10;

class MobileGlassPanel extends StatelessWidget
{
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  // Null: the card glass of the mode in force.
  final double? whiteAlpha;
  final List<BoxShadow> shadow;
  // Never on a moving sheet: the per-frame screen readback stutters.
  final bool blur;

  // Null: white, a dark card in the dark mode.
  final Color? tint;

  // Denser in the dark, so the sea does not show through the dark glass.
  static double get cardAlpha => ThemeColours.isDark ? darkGlassAlpha : 0.65;

  // Public for the sign-in handover, which must start from exactly this glass.
  static const double edgeAlpha = 0.62;
  // The light streak along the top edge; the dark glass keeps one even edge all round.
  static double get highlightAlpha => ThemeColours.isDark ? 0 : 0.85;
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(28));

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x42000000), offset: Offset(0, 18), blurRadius: 40),
  ];

  static const List<BoxShadow> sheetShadow = [
    BoxShadow(color: Color(0x40000000), offset: Offset(0, -16), blurRadius: 36),
  ];

  // The nav bar's glass; opaque, nothing behind shows through.
  static Color get sheetTint => ThemeColours.of(0xFFF0F6F7);
  static const double sheetAlpha = 1;

  const MobileGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 22),
    this.borderRadius = cardRadius,
    this.whiteAlpha,
    this.shadow = cardShadow,
    this.blur = false,
    this.tint,
  });

  MobileGlassPanel.sheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 14, 24, 24),
  })  : borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
        whiteAlpha = sheetAlpha,
        shadow = sheetShadow,
        blur = false,
        tint = sheetTint;

  @override
  Widget build(BuildContext context)
  {
    final double inset = borderRadius.topLeft.x;
    final bool snowy = HolidaySnow.of(context);
    final Widget child = snowy ? HolidaySnow(on: false, child: this.child) : this.child;

    // Passthrough, so a panel given a height fills it with glass.
    final Widget glass = Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: (tint ?? AppTheme.surface).withValues(alpha: whiteAlpha ?? cardAlpha),
            borderRadius: borderRadius,
            border: Border.all(color: AppTheme.surfaceEdge.withValues(alpha: edgeAlpha)),
          ),
          child: Padding(padding: padding, child: child),
        ),
        if (highlightAlpha > 0)
          Positioned(
            top: 0,
            left: inset,
            right: inset,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    AppTheme.surface.withValues(alpha: highlightAlpha),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final Widget panel = DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blur
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
                child: glass,
              )
            : glass,
      ),
    );

    return snowy ? SnowCap(radius: inset, scale: 0.85, child: panel) : panel;
  }
}
