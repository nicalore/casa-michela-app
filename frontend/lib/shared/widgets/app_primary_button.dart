import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const String _fontFamily = 'PlusJakartaSans';

class AppPrimaryButton extends StatefulWidget
{
  final String label;
  final VoidCallback onPressed;
  final double width;
  final double height;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 220,
    this.height = 56,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> with SingleTickerProviderStateMixin
{
  static const Duration _pressDuration = Duration(milliseconds: 150);
  static const Duration _hoverDuration = Duration(milliseconds: 200);
  static const double _pressedScale = 0.95;

  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  bool _isHovered = false;

  @override
  void initState()
  {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: _pressDuration,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: _pressedScale).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose()
  {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details)
  {
    _scaleController.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: _onTapUp,
        onTapCancel: () => _scaleController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: _hoverDuration,
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.primaryHover : AppTheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: _isHovered ? 0.4 : 0.2),
                  offset: Offset(0, _isHovered ? 8 : 4),
                  blurRadius: _isHovered ? 16 : 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}