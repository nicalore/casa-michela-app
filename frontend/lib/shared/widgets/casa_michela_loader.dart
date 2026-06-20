import 'dart:ui';
import 'package:flutter/material.dart';

class CasaMichelaLoader extends StatelessWidget
{
  final bool isOverlay;

  const CasaMichelaLoader({super.key, this.isOverlay = true});

  @override
  Widget build(BuildContext context)
  {
    final screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = screenWidth > 500 ? 400.0 : screenWidth * 0.8;

    Widget loaderContent = Center(
      child: SizedBox(
        width:  logoSize,
        height: logoSize,
        //Display static colored logo
        child:  Image.asset(
          'assets/images/logo.png',
          width: logoSize,
          fit:   BoxFit.contain,
        ),
      ),
    );

    if (isOverlay)
    {
      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child:  Container(color: Colors.white.withValues(alpha: 0.5)),
          ),
          loaderContent,
        ],
      );
    }

    return loaderContent;
  }
}