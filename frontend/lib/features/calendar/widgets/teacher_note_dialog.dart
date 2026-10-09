import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../lessons/models/booking_summary_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../people/utils/student_notes_strings.dart';

const double _dialogWidth = 900;

const int _lines = 10;

// From its first minute on, on the association's clock.
bool lessonHasBegun(LessonItem lesson, DateTime now)
{
  final DateTime date = lesson.date;
  final DateTime start = DateTime(date.year, date.month, date.day, lesson.startTime.hour, lesson.startTime.minute);

  return !start.isAfter(now);
}

// Every subject of the lesson, each once: the note is about the whole lesson.
String lessonSubjects(LessonItem lesson, List<MinistrySubjectItem> ministrySubjects)
{
  return {for (final entry in lesson.bookings) bookingTitle(entry.booking, ministrySubjects)}.join(', ');
}

// True once sent; the teacher does not see the note again.
Future<bool> showTeacherNoteDialog(
  BuildContext context,
  LessonItem lesson,
  List<MinistrySubjectItem> ministrySubjects,
) async
{
  final bool? sent = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'TeacherNote',
    builder: (context) => _TeacherNoteDialog(lesson: lesson, ministrySubjects: ministrySubjects),
  );

  return sent ?? false;
}

class _TeacherNoteDialog extends StatefulWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;

  const _TeacherNoteDialog({required this.lesson, required this.ministrySubjects});

  @override
  State<_TeacherNoteDialog> createState() => _TeacherNoteDialogState();
}

class _TeacherNoteDialogState extends State<_TeacherNoteDialog>
{
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();

  bool _sending = false;

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async
  {
    final String text = _controller.text.trim();

    if (text.isEmpty)
    {
      CustomSnackBar.show(context: context, message: kEmptyNote, isError: true);

      return;
    }

    setState(() => _sending = true);

    try
    {
      await _apiService.createTeacherNote(widget.lesson.id, text);

      if (mounted)
      {
        Navigator.of(context).pop(true);
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _sending = false);
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final LessonItem lesson = widget.lesson;
    final student = lesson.bookings.first.presence.student;
    final String day = formatWeekdayColumnLabel(lesson.date);

    return AppDialogStack(
      eyebrow: kNewNoteEyebrow,
      title: '${student.firstName} ${student.lastName}',
      leading: PersonAvatar(person: student, size: PersonAvatar.titleSize),
      subtitle: Text(
        '${lessonSubjects(lesson, widget.ministrySubjects)} · $day',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.trialMutedText,
        ),
      ),
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kSendLabel,
          icon: Icons.send_rounded,
          height: 52,
          fontSize: 14,
          busy: _sending,
          onPressed: _send,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kTeacherNoteHint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: AppTheme.trialMutedText,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _controller,
                label: kTeacherNotesTitle,
                showLabel: false,
                hintText: '',
                minLines: _lines,
                maxLines: _lines,
                maxLength: FieldLimits.studentNote,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
