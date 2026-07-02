import 'package:flutter/material.dart';

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
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  bool _isHovered = false;

  @override
  void initState()
  {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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

  void _onTapDown(TapDownDetails details)
  {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details)
  {
    _scaleController.reverse();
    widget.onPressed();
  }

  void _onTapCancel()
  {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFF004D99) : const Color(0xFF003C82),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003C82).withValues(alpha: _isHovered ? 0.4 : 0.2),
                  offset: Offset(0, _isHovered ? 8 : 4),
                  blurRadius: _isHovered ? 16 : 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
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