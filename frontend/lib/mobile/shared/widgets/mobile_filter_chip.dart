import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

// Sized as MobileChoiceChips, so both rows read alike on the sea.
const double _height = 32;
const double _iconSize = 16;

class MobileFilterChip extends StatelessWidget
{
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const MobileFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color ink = active ? AppTheme.trialDeepWater : Colors.white.withValues(alpha: 0.85);

    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: _height,
          padding: const EdgeInsets.fromLTRB(11, 0, 13, 0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.92 : 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Colors.transparent : Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _iconSize, color: ink),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
