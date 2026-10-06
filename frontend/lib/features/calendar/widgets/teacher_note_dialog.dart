import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
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

  int _chosen = 0;

  bool _sending = false;

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  List<LessonBookingItem> get _bookings => widget.lesson.bookings;

  String _subjectOf(LessonBookingItem entry) => bookingTitle(entry.booking, widget.ministrySubjects);

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
      await _apiService.createTeacherNote(widget.lesson.id, _bookings[_chosen].booking.id, text);

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

  Widget _buildSubjects()
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFieldLabel(kSubjectLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _bookings.length; i++)
                AppSelectableChip(
                  label: _subjectOf(_bookings[i]),
                  selected: i == _chosen,
                  onSelected: (_) => setState(() => _chosen = i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final LessonItem lesson = widget.lesson;
    final student = lesson.bookings.first.presence.student;
    final String day = formatWeekdayColumnLabel(lesson.date);
    final bool several = _bookings.length > 1;

    return AppDialogStack(
      eyebrow: kNewNoteEyebrow,
      title: '${student.firstName} ${student.lastName}',
      leading: PersonAvatar(person: student, size: PersonAvatar.titleSize),
      subtitle: Text(
        several ? day : '${_subjectOf(_bookings.first)} · $day',
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
              if (several) _buildSubjects(),
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
