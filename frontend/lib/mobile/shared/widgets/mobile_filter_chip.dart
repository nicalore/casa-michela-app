import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';

// Sized as MobileChoiceChips, so both rows read alike.
const double _height = 32;
const double _iconSize = 16;
const double _gap = 8;

// The page margin is inside the row, so it can bleed past it on both sides.
class MobileFilterChips extends StatelessWidget
{
  final List<Widget> chips;
  final double margin;

  const MobileFilterChips({super.key, required this.chips, required this.margin});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: _gap),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}

class MobileFilterChip extends StatelessWidget
{
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  // Inside a card or a sheet rather than on the sea.
  final bool onLight;

  const MobileFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onLight = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color fill = onLight
        ? (active ? AppTheme.trialDeepWater : AppTheme.trialOcean.withValues(alpha: 0.06))
        : Colors.white.withValues(alpha: active ? 0.92 : 0.12);
    final Color edge = onLight
        ? AppTheme.trialOcean.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.22);
    final Color ink = onLight
        ? (active ? Colors.white : MobilePalette.mutedText)
        : (active ? AppTheme.trialDeepWater : Colors.white.withValues(alpha: 0.85));

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
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Colors.transparent : edge),
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
