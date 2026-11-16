import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../utils/opening_strings.dart';

// «Da configurare»: whoever the initial set-up still waits for, where money would show.
class OpeningPendingPill extends StatelessWidget
{
  final double fontSize;

  const OpeningPendingPill({super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.8, vertical: fontSize * 0.3),
      decoration: BoxDecoration(
        color: AppTheme.trialOcean.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(fontSize * 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_actions_rounded, size: fontSize + 2, color: AppTheme.trialOcean),
          SizedBox(width: fontSize * 0.4),
          Text(
            kOpeningPending,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialOcean,
            ),
          ),
        ],
      ),
    );
  }
}
