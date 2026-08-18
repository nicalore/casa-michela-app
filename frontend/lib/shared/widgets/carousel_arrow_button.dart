import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// The arrow a carousel is paged with, in the two sizes the app uses it at.
class CarouselArrowButton extends StatefulWidget
{
  // Its own size, and its glyph's. The carousel paging through a dialog's cards
  // wants it larger, because there the arrow is the way to move rather than an
  // accessory command.
  static const double defaultSize = 44;
  static const double defaultIconSize = 20;

  final IconData icon;
  final VoidCallback onTap;
  final bool isDisabled;

  // What it fills with under the pointer, and what the glyph turns into there.
  // An arrow fills with the brand and reverses its glyph out of it; a close
  // takes the pale gold every other close in the app takes and keeps its glyph,
  // because gold is the app's answer to "the pointer is here".
  final Color hoverColor;
  final Color hoverIconColor;

  final double size;
  final double iconSize;

  const CarouselArrowButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
    this.hoverColor = AppTheme.trialTealDeep,
    this.hoverIconColor = Colors.white,
    this.size = defaultSize,
    this.iconSize = defaultIconSize,
  });

  @override
  State<CarouselArrowButton> createState() => _CarouselArrowButtonState();
}

class _CarouselArrowButtonState extends State<CarouselArrowButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? AppTheme.arrowDisabledSurface
                : (_isHovered ? widget.hoverColor : Colors.white),
            shape: BoxShape.circle,
            boxShadow: widget.isDisabled ? null : AppTheme.cardShadow,
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.isDisabled
                ? AppTheme.trialMutedText.withValues(alpha: 0.5)
                : (_isHovered ? widget.hoverIconColor : AppTheme.trialTealDeep),
          ),
        ),
      ),
    );
  }
}
