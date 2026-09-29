import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';

enum MobilePillTone { gold, teal, muted, sea }

class MobilePill extends StatelessWidget
{
  final String label;
  final MobilePillTone tone;
  final bool dense;

  const MobilePill(this.label, {super.key, this.tone = MobilePillTone.gold, this.dense = false});

  @override
  Widget build(BuildContext context)
  {
    final (Color fill, Color edge, Color text) = switch (tone)
    {
      MobilePillTone.gold => (
          AppTheme.trialGoldSurface,
          AppTheme.trialGold.withValues(alpha: 0.55),
          AppTheme.modifiedAccent,
        ),
      MobilePillTone.teal => (
          Colors.white.withValues(alpha: 0.5),
          AppTheme.trialTealDeep.withValues(alpha: 0.25),
          AppTheme.trialTealDeep,
        ),
      MobilePillTone.muted => (
          Colors.white.withValues(alpha: 0.55),
          MobilePalette.mutedText.withValues(alpha: 0.28),
          MobilePalette.mutedText,
        ),
      MobilePillTone.sea => (
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.32),
          Colors.white.withValues(alpha: 0.85),
        ),
    };

    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: edge),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 8.5 : 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: dense ? 0.6 : 0.9,
          height: 1.3,
          color: text,
        ),
      ),
    );
  }
}
