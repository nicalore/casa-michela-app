import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../utils/booking_window.dart';

// What a day amounts to, over the band it is worked from.
//
// The counts are the day's own, taken before any search: they are here to say
// whether the day holds together — how many teachers are covering how many
// pupils — which is a question the list below cannot answer once it has been
// filtered down to one name. They count people and not rows: a teacher who has
// left two slots open counts once, and so does a pupil booked in twice.
class LessonsDayHeader extends StatelessWidget
{
  final DateTime day;

  // On a narrow window the day is already named by the heading above this, so
  // it is left out here rather than said twice in forty pixels.
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
