import 'package:flutter/material.dart';

class PageWatermark extends StatelessWidget
{
  static const double _minViewportWidth = 1024;
  static const double _imageWidth = 800;
  static const double _opacity = 0.04;

  const PageWatermark({super.key});

  @override
  Widget build(BuildContext context)
  {
    final window = MediaQuery.sizeOf(context);

    if (window.width <= _minViewportWidth)
    {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      width: window.width,
      height: window.height,
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: _opacity,
            child: Image.asset(
              'assets/images/house_watermark.png',
              width: _imageWidth,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
