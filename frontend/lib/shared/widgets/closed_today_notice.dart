import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

class ClosedTodayNotice extends StatelessWidget
{
  const ClosedTodayNotice({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_busy_rounded, size: 26, color: AppTheme.trialMutedText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "L'associazione è chiusa",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nessuna apertura prevista.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
