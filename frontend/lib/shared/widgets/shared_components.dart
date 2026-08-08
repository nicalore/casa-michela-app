import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedActionButton extends StatefulWidget
{
  final String text;
  final IconData icon;
  final Color baseColor;
  final Color hoverColor;
  final VoidCallback onPressed;

  /// 56 suits a dialog footer; page-level actions sit at 50, matching the
  /// search bar and the "Nuova …" buttons.
  final double height;

  const AnimatedActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.baseColor,
    required this.hoverColor,
    required this.onPressed,
    this.height = 56,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
{
  static const Duration _animationDuration = Duration(milliseconds: 250);

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_)
        {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: _animationDuration,
          curve: Curves.easeOutQuint,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutQuint,
            height: widget.height,
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverColor : widget.baseColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.baseColor.withValues(alpha: _isHovered ? 0.4 : 0.2),
                  offset: Offset(0, _isHovered ? 8 : 4),
                  blurRadius: _isHovered ? 16 : 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Icon button whose background fades in on hover. StaticHoverIconButton below
// was a byte for byte copy of this widget and is now an alias of it.
class FadeHoverIconButton extends StatefulWidget
{
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const FadeHoverIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<FadeHoverIconButton> createState() => _FadeHoverIconButtonState();
}

class _FadeHoverIconButtonState extends State<FadeHoverIconButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : widget.hoverColor.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
      ),
    );
  }
}

// Transitional alias: the two widgets were identical, so the duplicate
// implementation was dropped. Call sites can migrate to FadeHoverIconButton and
// this line can then be deleted.
typedef StaticHoverIconButton = FadeHoverIconButton;