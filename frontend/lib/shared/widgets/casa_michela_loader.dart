import 'dart:ui';

import 'package:flutter/material.dart';

class CasaMichelaLoader extends StatelessWidget
{
  static const double _largeScreenBreakpoint = 500;
  static const double _maxLogoSize = 400.0;
  static const double _logoWidthFraction = 0.8;
  static const double _blurSigma = 20.0;
  static const double _scrimOpacity = 0.5;

  final bool isOverlay;

  const CasaMichelaLoader({super.key, this.isOverlay = true});

  @override
  Widget build(BuildContext context)
  {
    final screenWidth = MediaQuery.of(context).size.width;

    final logoSize = screenWidth > _largeScreenBreakpoint
        ? _maxLogoSize
        : screenWidth * _logoWidthFraction;

    final loaderContent = Center(
      child: SizedBox(
        width: logoSize,
        height: logoSize,
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      ),
    );

    if (!isOverlay)
    {
      return loaderContent;
    }

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: Container(color: Colors.white.withValues(alpha: _scrimOpacity)),
        ),
        loaderContent,
      ],
    );
  }
}