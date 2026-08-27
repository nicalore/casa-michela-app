import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const Color kPickedSurface = Color(0xFFE8F7F5);

class AppCheckMark extends StatelessWidget
{
  static const double size = 22;

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
