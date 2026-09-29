import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/utils/day_marks.dart';
import '../mobile_palette.dart';

class MobileDateCapsule extends StatelessWidget
{
  final String label;
  final bool current;
  final bool tablet;

  // Null where there is nothing that way.
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  final VoidCallback onPick;

  const MobileDateCapsule({
    super.key,
    required this.label,
    required this.current,
    required this.tablet,
    required this.onBack,
    required this.onForward,
    required this.onPick,
  });

  static final Color _divider = Colors.white.withValues(alpha: 0.18);

  Widget _buildArrow(IconData icon, VoidCallback? onTap, {required bool leading})
  {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: tablet ? 54 : 48,
          decoration: BoxDecoration(
            border: leading ? Border(right: BorderSide(color: _divider)) : Border(left: BorderSide(color: _divider)),
          ),
          child: Icon(icon, size: 26, color: Colors.white.withValues(alpha: onTap != null ? 0.92 : 0.26)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double height = tablet ? 50 : 46;
    final BorderRadius radius = BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      foregroundDecoration: current
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: MobilePalette.currentRim,
                width: MobilePalette.currentRimWidth,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildArrow(Icons.chevron_left_rounded, onBack, leading: true),
          Expanded(
            child: Semantics(
              button: true,
              label: kPickDayLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 20, color: Colors.white.withValues(alpha: 0.92)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: tablet ? 18 : 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
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
          _buildArrow(Icons.chevron_right_rounded, onForward, leading: false),
        ],
      ),
    );
  }
}
