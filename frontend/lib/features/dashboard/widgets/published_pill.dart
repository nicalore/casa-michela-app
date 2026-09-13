import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

class PublishedPill extends StatelessWidget
{
  final bool isDraft;

  const PublishedPill({super.key, this.isDraft = false});

  @override
  Widget build(BuildContext context)
  {
    final Color accent = isDraft ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDraft ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        isDraft ? 'IN BOZZA' : 'PUBBLICATO',
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 1.1,
          color: accent,
        ),
      ),
    );
  }
}
