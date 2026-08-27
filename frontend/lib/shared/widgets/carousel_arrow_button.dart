import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CarouselArrowButton extends StatefulWidget
{
  static const double defaultSize = 44;
  static const double defaultIconSize = 20;

  final IconData icon;
  final VoidCallback onTap;
  final bool isDisabled;

  final Color hoverColor;
  final Color hoverIconColor;

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
