import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../calendar/widgets/own_lesson_dialog.dart' show LessonDialogSection, LessonVoice, LessonVoicesTable, lessonVoicesOf;
import '../../lessons/models/lesson_item.dart';

const double _width = 680;

// The lesson alone, as the family's calendar tells it, with its teacher named after the hours.
Future<void> showBookingHistoryLessonDialog({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
})
{
  final List<LessonVoice> voices = lessonVoicesOf(lesson, ministrySubjects, where: true);

  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'BookingHistoryLesson',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: 'Lezione',
      title: 'Dettagli lezione',
      subtitle: Text(
        formatWeekdayColumnLabel(lesson.date),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.trialMutedText,
        ),
      ),
      maxWidth: _width,
      children: [
        LessonDialogSection(
          child: LessonVoicesTable(
            voices: [
              voices.first,
              LessonVoice(label: 'Docente', value: lesson.teacher.fullName),
              ...voices.skip(1),
            ],
          ),
        ),
      ],
    ),
  );
}
