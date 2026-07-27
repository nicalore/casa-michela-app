import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Color _searchFocusShadow = Color(0x15003C82);
const Color _searchIdleShadow = Color(0x0A000000);

class AnimatedSearchBar extends StatefulWidget
{
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const AnimatedSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
{
  final FocusNode _focusNode = FocusNode();

  bool _isFocused = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged()
  {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context)
  {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuint,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: _isFocused
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused ? _searchFocusShadow : _searchIdleShadow,
            offset: const Offset(0, 4),
            blurRadius: _isFocused ? 24 : 16,
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppTheme.primary,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppTheme.primary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppTheme.hint,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 28),
          suffixIcon: Icon(
            Icons.search,
            size: 32,
            color: _isFocused ? AppTheme.primary : AppTheme.hint,
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 64, minHeight: 50),
        ),
      ),
    );
  }
}

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