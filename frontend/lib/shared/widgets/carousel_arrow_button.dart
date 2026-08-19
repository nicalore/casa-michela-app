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

  // The outline it draws round itself under the pointer. Given for a close,
  // which answers with the pale gold and would otherwise be the one round
  // control in the app that lights up without one: everything pressable here
  // takes the gold ring, and a fill on its own reads as a hover half done.
  //
  // Left out for an arrow, which reverses itself into the brand colour — a ring
  // round that is a second answer to a question already answered.
  final Color? hoverBorderColor;

  final double size;
  final double iconSize;

  const CarouselArrowButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
    this.hoverColor = AppTheme.trialTealDeep,
    this.hoverIconColor = Colors.white,
    this.hoverBorderColor,
    this.size = defaultSize,
    this.iconSize = defaultIconSize,
  });

  @override
  State<CarouselArrowButton> createState() => _CarouselArrowButtonState();
}

class _CarouselArrowButtonState extends State<CarouselArrowButton>
{
  bool _isHovered = false;

  // Always drawn, transparent while the pointer is away: a border appearing out
  // of nothing would move the glyph two pixels at the moment of the hover, and
  // there is nothing to animate between a border and none.
  Border? get _border
  {
    final color = widget.hoverBorderColor;

    if (color == null || widget.isDisabled)
    {
      return null;
    }

    return Border.all(color: _isHovered ? color : color.withValues(alpha: 0), width: 2);
  }

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
            border: _border,
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
