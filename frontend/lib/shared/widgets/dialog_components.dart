import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double _dialogBlurSigma = 8.0;

// Opens a dialog with the blur, fade and scale transition shared by every
// wizard of the app. The child is built inside transitionBuilder, so it keeps
// the same construction semantics as a plain showGeneralDialog.
Future<T?> showBlurredDialog<T>({
  required BuildContext context,
  required String barrierLabel,
  required WidgetBuilder builder,
})
{
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: .15),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child)
    {
      final blurValue = animation.value * _dialogBlurSigma;

      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: builder(context),
          ),
        ),
      );
    },
  );
}

class ResponsiveDialogButtonsRow extends StatelessWidget
{
  static const double _breakpoint = 460;
  static const double _defaultStackedWidth = 240;

  final Widget secondaryButton;
  final Widget primaryButton;

  /// Width of each button once stacked. Null stretches them to the full width,
  /// which reads better inside a dialog that is already narrow.
  final double? stackedButtonWidth;

  const ResponsiveDialogButtonsRow({
    required this.secondaryButton,
    required this.primaryButton,
    this.stackedButtonWidth = _defaultStackedWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        // When stacked the primary button moves on top, so the order differs
        // from the side by side layout on purpose.
        if (constraints.maxWidth < _breakpoint)
        {
          final width = stackedButtonWidth;

          Widget sized(Widget button)
          {
            return width == null ? button : SizedBox(width: width, child: button);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                width == null ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            children: [
              sized(primaryButton),
              const SizedBox(height: 16),
              sized(secondaryButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: secondaryButton),
            const SizedBox(width: 16),
            Expanded(child: primaryButton),
          ],
        );
      },
    );
  }
}

class CustomChip extends StatefulWidget
{
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const CustomChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<CustomChip> createState() => _CustomChipState();
}

class _CustomChipState extends State<CustomChip>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final backgroundColor = widget.isSelected
        ? AppTheme.primary
        : (_isHovered ? AppTheme.surfaceHover : Colors.white);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected ? AppTheme.primary : AppTheme.border,
              width: 1.0,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? Colors.white : AppTheme.primary,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class OutlinedActionButton extends StatefulWidget
{
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const OutlinedActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  @override
  State<OutlinedActionButton> createState() => _OutlinedActionButtonState();
}

class _OutlinedActionButtonState extends State<OutlinedActionButton>
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
            height: 56,
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.surfaceHover : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
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