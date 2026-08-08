import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// The mark on whatever has been chosen: a ticked row, a chosen card.
const Color kPickedSurface = Color(0xFFE8F7F5);

class AppCheckMark extends StatelessWidget
{
  static const double size = 22;

  // The mark appears, it does not toggle: it fades in and grows the last little
  // bit meanwhile. The same duration the row holding it takes to tint, because
  // two movements out of step on the same row read as a flicker.
  static const Duration _fade = Duration(milliseconds: 180);

  static final BorderRadius _radius = BorderRadius.circular(7);

  final bool selected;
  final bool partial;
  final VoidCallback? onTap;

  const AppCheckMark({
    super.key,
    required this.selected,
    this.partial = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool filled = selected || partial;

    // The filled state sits on top of the empty one and fades over it rather
    // than replacing it: with a single AnimatedContainer going from a solid
    // colour to a gradient, the colour stops being painted the moment the
    // gradient exists, and half the animation went by in a jump.
    final Widget mark = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _radius,
              border: Border.all(color: AppTheme.trialLine, width: 2),
            ),
          ),
          AnimatedOpacity(
            opacity: filled ? 1 : 0,
            duration: _fade,
            curve: Curves.easeOutCubic,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: _radius,
              ),
              child: Center(
                child: AnimatedScale(
                  scale: filled ? 1 : 0.7,
                  duration: _fade,
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    partial && !selected ? Icons.remove_rounded : Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null)
    {
      return mark;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: mark),
    );
  }
}
