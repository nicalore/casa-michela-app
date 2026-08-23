import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/booking_summary_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../utils/opening_window.dart';
import 'booking_fields_section.dart' show bookingTagLabels;
import 'calendar_lesson_block.dart' show lessonTitle;
import 'person_avatar.dart';

const double _detailsWidth = 680;

const double _columnGap = 32;

const double _twoColumnMin = 460;

const double _voiceGap = 18;

const String _empty = '—';

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

  List<({String label, String value, bool alone})> get _entries
  {
    final topic = _perBooking((booking) => booking.topic ?? '');
    final notes = _perBooking((booking) => booking.notes ?? '');

    return [
      (
        label: 'Orario',
        value: '${formatTimeRange(lesson.startTime, lesson.endTime)} · ${formatMinutes(lesson.minutes)}',
        alone: false,
      ),
      (label: _theOther.label, value: _theOther.value, alone: false),
      (label: 'Luogo', value: _where, alone: false),
      (
        label: 'Materia',
        value: _perBooking((booking) => bookingTitle(booking, ministrySubjects)),
        alone: false,
      ),
      (
        label: 'Discipline',
        value: lesson.disciplineNames.isEmpty ? _empty : lesson.disciplineNames.join(', '),
        alone: false,
      ),
      (
        label: 'Tipo di lezione',
        value: _perBooking((booking) => bookingTagLabels(booking.tags).join(', ')),
        alone: false,
      ),
      (label: 'Argomento', value: topic, alone: topic != _empty),
      (label: 'Note per il docente', value: notes, alone: notes != _empty),
    ];
  }

  List<List<({String label, String value, bool alone})>> get _rows
  {
    final rows = <List<({String label, String value, bool alone})>>[];

    for (final entry in _entries)
    {
      if (entry.alone)
      {
        rows.add([entry]);

        continue;
      }

      if (rows.isEmpty || rows.last.length == 2 || rows.last.single.alone)
      {
        rows.add([entry]);

        continue;
      }

      rows.last.add(entry);
    }

    return rows;
  }

  Widget _buildVoice(String label, String value)
  {
    final isEmpty = value == _empty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: isEmpty ? AppTheme.trialMutedText : AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    List<({String label, String value, bool alone})> row, {
    required bool wide,
  })
  {
    if (!wide || row.length == 1)
    {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < row.length; index++) ...[
            if (index > 0) const SizedBox(height: _voiceGap),
            _buildVoice(row[index].label, row[index].value),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < row.length; index++) ...[
          if (index > 0) const SizedBox(width: _columnGap),
          Expanded(child: _buildVoice(row[index].label, row[index].value)),
        ],
      ],
    );
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
        AppDialogPill(
          expand: true,
          child: SelectionArea(
            child: LayoutBuilder(
              builder: (context, constraints)
              {
                final wide = constraints.maxWidth >= _twoColumnMin;
                final rows = _rows;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < rows.length; index++) ...[
                      if (index > 0) const SizedBox(height: _voiceGap),
                      _buildRow(rows[index], wide: wide),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
