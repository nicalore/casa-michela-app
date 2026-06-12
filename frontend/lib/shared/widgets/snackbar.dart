import 'dart:async';
import 'package:flutter/material.dart';

class CustomSnackBar
{
  static OverlayEntry? _currentOverlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 5),
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
    if (_currentOverlayEntry != null)
    {
      _currentOverlayEntry!.remove();
      _currentOverlayEntry = null;
    }
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

class _SnackBarAnimationWidgetState extends State<_SnackBarAnimationWidget> with SingleTickerProviderStateMixin
{
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  
  Timer? _dismissTimer;

  @override
  void initState()
  {
    super.initState();

    //InitializeAnimationController
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack, 
      ),
    );

    _animationController.forward();

    //AutoDismissTimer
    _dismissTimer = Timer(widget.duration, ()
    {
      if (mounted)
      {
        _animationController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeIn,
        ).then((_)
        {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose()
  {
    //ReleaseResources
    _dismissTimer?.cancel();
    _animationController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    //DetermineStyling
    final bgColor = widget.isError ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);
    final iconColor = widget.isError ? const Color(0xFFD32F2F) : const Color(0xFF003C82);
    final textColor = widget.isError ? const Color(0xFFC62828) : const Color(0xFF002244);
    
    final borderColor = widget.isError 
        ? const Color(0xFFFFCDD2) 
        : const Color(0xFF003C82).withValues(alpha: 0.2);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + 24,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.08),
                    offset: const Offset(0, 6),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError ? Icons.error_rounded : Icons.check_circle_rounded,
                    color: iconColor,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
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