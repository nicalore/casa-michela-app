import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../utils/booking_window.dart';

String _count(int value, String singular, String plural)
{
  return '$value ${value == 1 ? singular : plural}';
}

// Counts are pre-search and count people, not rows.
String lessonsDaySummary({required int availableTeachers, required int presentStudents})
{
  return [
    _count(availableTeachers, 'docente disponibile', 'docenti disponibili'),
    _count(presentStudents, 'alunno prenotato', 'alunni prenotati'),
  ].join(' · ');
}

// On the wide window, beside the rail; below it the tab names the day and the tabs carry the summary.
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

  @override
  Widget build(BuildContext context)
  {
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
            lessonsDaySummary(availableTeachers: availableTeachers, presentStudents: presentStudents),
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
