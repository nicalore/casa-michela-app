import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const Duration _enterDuration = Duration(milliseconds: 450);
const Duration _exitDuration = Duration(milliseconds: 250);
const Duration _defaultVisibleDuration = Duration(seconds: 5);

// A banner that stays up until somebody takes it down.
//
// For the ones a gesture in flight raises: the sentence is true for as long as
// the pointer is where it is, and one that faded out on its own would leave a
// refusal on screen for five seconds and then a wrong place with nothing said
// about it. [CustomSnackBar.dismiss] is what ends these.
const Duration kUntilDismissed = Duration(days: 1);

// The banner starts one and a half times its own height below the resting
// position, so the easeOutBack overshoot stays outside the viewport.
const Offset _enterOffset = Offset(0, 1.5);

const double _bottomMargin = 24;
const double _horizontalMargin = 20;

// The three things a banner can be.
//
// A warning is not an error and not a confirmation: the calendar answers a save
// that went through with something the server thought worth saying — a teacher
// somebody named as not preferred, a room over its capacity — and neither of
// the two existing tones can carry that without lying about it.
enum SnackBarTone
{
  info,
  warning,
  error,
}

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

  // The two colours the app already gives to a value that deviates from what
  // was expected, which is exactly what a warning is.
  static final _SnackBarStyle warning = _SnackBarStyle(
    background: AppTheme.modifiedAccentSurface,
    border: AppTheme.modifiedAccent.withValues(alpha: 0.25),
    iconColor: AppTheme.modifiedAccent,
    textColor: AppTheme.modifiedAccent,
    icon: Icons.warning_amber_rounded,
  );

  static _SnackBarStyle of(SnackBarTone tone)
  {
    return switch (tone)
    {
      SnackBarTone.info => info,
      SnackBarTone.warning => warning,
      SnackBarTone.error => error,
    };
  }
}

abstract final class CustomSnackBar
{
  static OverlayEntry? _currentOverlayEntry;

  // The banner currently up, reachable so that its clock can be restarted
  // without rebuilding it. See [keepShowing].
  static GlobalKey<_SnackBarAnimationWidgetState>? _currentKey;

  // [tone] wins where it is given; [isError] is what the forty call sites
  // written before there were three tones still say, and it keeps meaning what
  // it meant.
  static void show({
    required BuildContext context,
    required String message,
    bool isError = false,
    SnackBarTone? tone,
    Duration duration = _defaultVisibleDuration,
  })
  {
    dismiss();

    // The root one, not the nearest. A dialog is pushed on the root navigator,
    // so a banner put in the overlay of the page underneath comes out below the
    // window that asked for it — and, worse, behind that window's backdrop
    // filter, which blurs it along with the page. The banner has to reach the
    // top of the app whatever asked for it.
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    final key = GlobalKey<_SnackBarAnimationWidgetState>();

    entry = OverlayEntry(
      builder: (context) => _SnackBarAnimationWidget(
        key: key,
        message: message,
        tone: tone ?? (isError ? SnackBarTone.error : SnackBarTone.info),
        duration: duration,
        // The identity check matters: a newer snackbar may have replaced this
        // entry while it was fading out, and it must not be removed twice.
        onDismissed: ()
        {
          if (_currentOverlayEntry == entry)
          {
            entry.remove();
            _currentOverlayEntry = null;
            _currentKey = null;
          }
        },
      ),
    );

    _currentOverlayEntry = entry;
    _currentKey = key;
    overlay.insert(entry);
  }

  // Puts the standard clock back on the banner that is already up, and touches
  // nothing else about it.
  //
  // For a sentence that was raised by a gesture and outlives it: it has been on
  // screen for as long as the pointer was in the wrong place, and now that the
  // gesture is over it should go a few seconds later. Showing it again would say
  // the same thing while replaying the entrance animation — under the eye of
  // somebody in the middle of reading it.
  //
  // Answers false where there is no banner up to keep, and then the caller has
  // to [show] one.
  static bool keepShowing()
  {
    final state = _currentKey?.currentState;

    if (state == null)
    {
      return false;
    }

    state.keepFor(_defaultVisibleDuration);

    return true;
  }

  static void dismiss()
  {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
    _currentKey = null;
  }
}

class _SnackBarAnimationWidget extends StatefulWidget
{
  final String message;
  final SnackBarTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  const _SnackBarAnimationWidget({
    super.key,
    required this.message,
    required this.tone,
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

  // Start the clock again, leaving the banner exactly as it is on screen.
  void keepFor(Duration duration)
  {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(duration, _startExitAnimation);
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
    final style = _SnackBarStyle.of(widget.tone);
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
