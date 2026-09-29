import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const double _blurSigma = 10;

class MobileGlassPanel extends StatelessWidget
{
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double whiteAlpha;
  final List<BoxShadow> shadow;
  // Never on a moving sheet: the per-frame screen readback stutters.
  final bool blur;

  final Color tint;

  static const double cardAlpha = 0.65;

  // Public for the sign-in handover, which must start from exactly this glass.
  static const double edgeAlpha = 0.62;
  static const double highlightAlpha = 0.85;
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(28));

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x42000000), offset: Offset(0, 18), blurRadius: 40),
  ];

  static const List<BoxShadow> sheetShadow = [
    BoxShadow(color: Color(0x40000000), offset: Offset(0, -16), blurRadius: 36),
  ];

  // The nav bar's glass; near-opaque so the dimmed page and gold button don't show through.
  static const Color sheetTint = Color(0xFFF0F6F7);
  static const double sheetAlpha = 0.94;

  const MobileGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 22),
    this.borderRadius = cardRadius,
    this.whiteAlpha = cardAlpha,
    this.shadow = cardShadow,
    this.blur = false,
    this.tint = Colors.white,
  });

  const MobileGlassPanel.sheet({
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

    // Passthrough, so a panel given a height fills it with glass.
    final Widget glass = Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: whiteAlpha),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: edgeAlpha)),
          ),
          child: Padding(padding: padding, child: child),
        ),
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
                  Colors.white.withValues(alpha: highlightAlpha),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
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
  }
}
