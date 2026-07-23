import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const Duration _enterDuration = Duration(milliseconds: 450);
const Duration _exitDuration = Duration(milliseconds: 250);
const Duration _defaultVisibleDuration = Duration(seconds: 5);

// The banner starts one and a half times its own height below the resting
// position, so the easeOutBack overshoot stays outside the viewport.
const Offset _enterOffset = Offset(0, 1.5);

const double _bottomMargin = 24;
const double _horizontalMargin = 20;

class _SnackBarStyle
{
  final Color background;
  final Color border;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  const _SnackBarStyle({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });

  static const _SnackBarStyle error = _SnackBarStyle(
    background: Color(0xFFFFEBEE),
    border: Color(0xFFFFCDD2),
    iconColor: Color(0xFFD32F2F),
    textColor: Color(0xFFC62828),
    icon: Icons.error_rounded,
  );

  static final _SnackBarStyle info = _SnackBarStyle(
    background: const Color(0xFFE3F2FD),
    border: AppTheme.primary.withValues(alpha: 0.2),
    iconColor: AppTheme.primary,
    textColor: const Color(0xFF002244),
    icon: Icons.check_circle_rounded,
  );
}

abstract final class CustomSnackBar
{
  static OverlayEntry? _currentOverlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    bool isError = false,
    Duration duration = _defaultVisibleDuration,
  })
  {
    dismiss();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _SnackBarAnimationWidget(
        message: message,
        isError: isError,
        duration: duration,
        // The identity check matters: a newer snackbar may have replaced this
        // entry while it was fading out, and it must not be removed twice.
        onDismissed: ()
        {
          if (_currentOverlayEntry == entry)
          {
            entry.remove();
            _currentOverlayEntry = null;
          }
        },
      ),
    );

    _currentOverlayEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss()
  {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  }
}

class _SnackBarAnimationWidget extends StatefulWidget
{
  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismissed;

  const _SnackBarAnimationWidget({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_SnackBarAnimationWidget> createState() => _SnackBarAnimationWidgetState();
}

class _SnackBarAnimationWidgetState extends State<_SnackBarAnimationWidget>
    with SingleTickerProviderStateMixin
{
  late final AnimationController _animationController;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  Timer? _dismissTimer;

  @override
  void initState()
  {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: _enterDuration,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    );

    _slideAnimation = Tween<Offset>(
      begin: _enterOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _dismissTimer = Timer(widget.duration, _startExitAnimation);
  }

  @override
  void dispose()
  {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startExitAnimation()
  {
    if (!mounted)
    {
      return;
    }

    _animationController
        .animateTo(0.0, duration: _exitDuration, curve: Curves.easeIn)
        .then((_) => widget.onDismissed());
  }

  @override
  Widget build(BuildContext context)
  {
    final style = widget.isError ? _SnackBarStyle.error : _SnackBarStyle.info;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + _bottomMargin,
      left: _horizontalMargin,
      right: _horizontalMargin,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: style.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 6),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(style.icon, color: style.iconColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: style.textColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}