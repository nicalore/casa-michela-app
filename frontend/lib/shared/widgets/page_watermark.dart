import 'package:flutter/material.dart';

// Faint house logo behind the page content. It is hidden on narrow viewports,
// where it would sit under the interface instead of beside it, and the
// breakpoint lives here so the three pages using it cannot drift apart.
class PageWatermark extends StatelessWidget
{
  static const double _minViewportWidth = 1024;
  static const double _imageWidth = 800;
  static const double _opacity = 0.04;

  const PageWatermark({super.key});

  @override
  Widget build(BuildContext context)
  {
    if (MediaQuery.of(context).size.width <= _minViewportWidth)
    {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
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