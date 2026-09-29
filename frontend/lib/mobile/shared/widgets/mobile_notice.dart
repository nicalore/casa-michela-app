import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/snackbar.dart';
import 'mobile_baseline_hang.dart';

const Duration _visibleFor = Duration(seconds: 5);
const Duration _enterDuration = Duration(milliseconds: 360);
const Duration _exitDuration = Duration(milliseconds: 220);

const double _sideMargin = 16;
const double _topMargin = 12;
const double _radius = 18;

const Offset _enterOffset = Offset(0, -1.2);

const double _fontSize = 14;
const double _iconSize = 22;

// From the capitals' top to the last baseline, not the line box.
const double _verticalPadding = 16;

// Plus Jakarta Sans per 1000 units: ascender 1038, cap height 745, descender 222.
const double _inkShift = (1.038 - 0.745 - 0.222) / 2;

const TextHeightBehavior _tightBox = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
);

// In the root overlay so it clears modal sheets.
abstract final class MobileNotice
{
  static OverlayEntry? _entry;

  static void show(BuildContext context, String message, {bool error = false, SnackBarTone? tone})
  {
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _NoticeBanner(
        message: message,
        tone: tone ?? (error ? SnackBarTone.error : SnackBarTone.info),
        // A newer notice may have replaced this one while it was leaving.
        onDone: ()
        {
          if (_entry == entry)
          {
            entry.remove();
            _entry = null;
          }
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }

  static void dismiss()
  {
    _entry?.remove();
    _entry = null;
  }
}

class _NoticeBanner extends StatefulWidget
{
  final String message;
  final SnackBarTone tone;
  final VoidCallback onDone;

  const _NoticeBanner({required this.message, required this.tone, required this.onDone});

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _enterDuration,
    reverseDuration: _exitDuration,
  );

  late final Animation<Offset> _slide = Tween<Offset>(begin: _enterOffset, end: Offset.zero).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn),
  );

  Timer? _timer;

  @override
  void initState()
  {
    super.initState();
    _controller.forward();
    _timer = Timer(_visibleFor, _leave);
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave() async
  {
    _timer?.cancel();

    await _controller.reverse();

    if (mounted)
    {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final (Color accent, IconData icon) = switch (widget.tone)
    {
      SnackBarTone.info => (AppTheme.trialTurquoise, Icons.check_circle_rounded),
      SnackBarTone.warning => (AppTheme.trialGold, Icons.warning_amber_rounded),
      SnackBarTone.error => (AppTheme.trialDangerLight, Icons.error_rounded),
    };
    final double em = MediaQuery.textScalerOf(context).scale(_fontSize);

    return Positioned(
      top: MediaQuery.paddingOf(context).top + _topMargin,
      left: _sideMargin,
      right: _sideMargin,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _controller,
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: _leave,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  _verticalPadding - _inkShift * em,
                  18,
                  _verticalPadding + _inkShift * em,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.trialDeepWater.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x59000000), offset: Offset(0, 12), blurRadius: 32),
                  ],
                ),
                // Hung from the baseline: top-aligned, it sat high at small text scales.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    MobileBaselineHang(
                      above: kCapitalsMiddle * em,
                      child: Icon(icon, size: _iconSize, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        textHeightBehavior: _tightBox,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: _fontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
