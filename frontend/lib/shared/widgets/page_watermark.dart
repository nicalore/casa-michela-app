import 'package:flutter/material.dart';

// Faint house logo behind the page content. It is hidden on narrow viewports,
// where it would sit under the interface instead of beside it, and the
// breakpoint lives here so the pages using it cannot drift apart.
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

    // Measured against the window and not against the page it is drawn on. A
    // page is as tall as what is on it — the settings run past the bottom of the
    // screen, a module page is exactly the screen — so centred in the page the
    // house stood somewhere else on each of them, and walking from one
    // destination to the next slid it up or down behind the content. Anchored to
    // the window it is in the same place everywhere, which is the only thing a
    // watermark has to be.
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
