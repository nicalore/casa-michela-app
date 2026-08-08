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
  // Off for every dialog of the app: with the windows made of separate floating
  // pieces, the paper "outside" one runs between its pieces as well, and a tap
  // meant for a field that landed a few pixels short would throw the whole edit
  // away. They close by their own X or by the button that says so.
  bool barrierDismissible = false,
  // Longer for a dialog that brings its pieces in one after the other and needs
  // the room to do it.
  Duration transitionDuration = const Duration(milliseconds: 240),
})
{
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: .15),
    transitionDuration: transitionDuration,
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