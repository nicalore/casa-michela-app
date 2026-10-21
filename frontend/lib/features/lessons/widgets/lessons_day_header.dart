import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../utils/booking_window.dart';

// Counts are pre-search and count people, not rows.
class LessonsDayHeader extends StatelessWidget
{
  final DateTime day;

  final bool showDay;

  final int availableTeachers;
  final int presentStudents;

  const LessonsDayHeader({
    super.key,
    required this.day,
    required this.showDay,
    required this.availableTeachers,
    required this.presentStudents,
  });

  static String _count(int value, String singular, String plural)
  {
    return '$value ${value == 1 ? singular : plural}';
  }

  String get _summary
  {
    return [
      _count(availableTeachers, 'docente disponibile', 'docenti disponibili'),
      _count(presentStudents, 'alunno prenotato', 'alunni prenotati'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context)
  {
    // Below the wide window the day and its summary share one line.
    if (AppBreakpoints.of(context).isDense)
    {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            if (showDay)
              Text(
                formatAvailableDayLabel(day),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppTheme.trialOcean,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                _summary,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDay) ...[
            Text(
              formatAvailableDayLabel(day),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppTheme.trialOcean,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            _summary,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ),
    );
  }
}
