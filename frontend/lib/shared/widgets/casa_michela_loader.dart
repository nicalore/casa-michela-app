import 'dart:ui';
import 'package:flutter/material.dart';

class CasaMichelaLoader extends StatefulWidget
{
  final bool isOverlay;

  const CasaMichelaLoader({super.key, this.isOverlay = true});

  @override
  State<CasaMichelaLoader> createState() => _CasaMichelaLoaderState();
}

class _CasaMichelaLoaderState extends State<CasaMichelaLoader> with SingleTickerProviderStateMixin
{
  late AnimationController _controller;
  late Animation<double>   _fadeAnimation;

  @override
  void initState()
  {
    super.initState();

    //Initialize animation controller
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(
      reverse: true,
    );

    //Setup fade animation
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve:  Curves.easeInOut,
    );
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final        screenWidth = MediaQuery.of(context).size.width;
    final double logoSize    = screenWidth > 500 ? 400.0 : screenWidth * 0.8;

    Widget loaderContent = Center(
      child: SizedBox(
        width:  logoSize,
        height: logoSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0,      0,      0,      1, 0,
              ]),
              child: Image.asset(
                'assets/images/logo.png',
                width: logoSize,
                fit:   BoxFit.contain,
              ),
            ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                'assets/images/logo.png',
                width: logoSize,
                fit:   BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isOverlay)
    {
      return Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.white.withValues(alpha: 0.5)),
          ),
          loaderContent,
        ],
      );
    }

    return loaderContent;
  }
}
