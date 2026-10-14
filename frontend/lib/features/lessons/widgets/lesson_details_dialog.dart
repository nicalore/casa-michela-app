import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../calendar/widgets/own_lesson_dialog.dart' show LessonDialogSection, LessonVoice, LessonVoicesTable, kVoiceEmpty;
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../utils/opening_window.dart';
import 'booking_fields_section.dart' show bookingTagLabels;
import 'calendar_lesson_block.dart' show lessonAbout, lessonTitle;
import 'person_avatar.dart';

const double _detailsWidth = 680;

const String _empty = kVoiceEmpty;

Future<void> showLessonDetailsDialog({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  CalendarView view = CalendarView.byTeacher,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'LessonDetails',
    builder: (dialogContext) => _LessonDetailsDialog(
      lesson: lesson,
      ministrySubjects: ministrySubjects,
      view: view,
    ),
  );
}

class _LessonDetailsDialog extends StatelessWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;

  final CalendarView view;

  const _LessonDetailsDialog({
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
  });

  bool get _byStudent => view == CalendarView.byStudent;

  String _perBooking(String Function(BookingSummaryItem booking) said)
  {
    final entries = lesson.bookings;

    if (entries.length == 1)
    {
      final only = said(entries.single.booking).trim();

      return only.isEmpty ? _empty : only;
    }

    final lines = <String>[];

    for (final entry in entries)
    {
      final value = said(entry.booking).trim();

      if (value.isNotEmpty)
      {
        lines.add('${entry.presence.student.firstName}: $value');
      }
    }

    return lines.isEmpty ? _empty : lines.join('\n');
  }

  String get _where
  {
    if (lesson.mode == kOnlineMode)
    {
      return modeLabel(kOnlineMode);
    }

    return lesson.room?.name ?? _empty;
  }

  ({String label, String value}) get _theOther
  {
    if (!_byStudent)
    {
      return (label: 'Docente', value: lesson.teacher.fullName);
    }

    final students = [
      for (final entry in lesson.bookings) entry.presence.student.fullName,
    ];

    return (
      label: students.length == 1 ? 'Alunno' : 'Alunni',
      value: students.isEmpty ? _empty : students.join(', '),
    );
  }

  // As teachers, parents and pupils see it, with what the administrators need.
  List<LessonVoice> get _voices
  {
    // A single discipline adds nothing to the subject and is left out.
    final disciplines = lessonAbout(lesson, ministrySubjects).disciplines;

    return [
      LessonVoice(
        label: 'Orario',
        value: '${formatTimeRange(lesson.startTime, lesson.endTime)} · ${formatMinutes(lesson.minutes)}',
      ),
      LessonVoice(label: _theOther.label, value: _theOther.value),
      LessonVoice(label: 'Luogo', value: _where),
      LessonVoice(label: 'Materia', value: _perBooking((booking) => bookingTitle(booking, ministrySubjects))),
      if (disciplines != null)
        LessonVoice(label: disciplines.contains(', ') ? 'Discipline' : 'Disciplina', value: disciplines),
      LessonVoice(
        label: 'Tipo di lezione',
        value: _perBooking((booking) => bookingTagLabels(booking.tags).join(', ')),
      ),
      LessonVoice(label: 'Argomento', value: _perBooking((booking) => booking.topic ?? '')),
      LessonVoice(label: 'Note per il docente', value: _perBooking((booking) => booking.notes ?? '')),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final only = lesson.bookings.length == 1 ? lesson.bookings.single.presence.student : null;
    final face = _byStudent ? lesson.teacher : only;

    return AppDialogStack(
      eyebrow: 'Lezione',
      title: lessonTitle(lesson, view: view),
      leading: face == null ? null : PersonAvatar(person: face, size: PersonAvatar.titleSize),
      subtitle: Text(
        formatWeekdayColumnLabel(lesson.date),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.trialMutedText,
        ),
      ),
      maxWidth: _detailsWidth,
      children: [
        LessonDialogSection(child: LessonVoicesTable(voices: _voices)),
      ],
    );
  }
}
