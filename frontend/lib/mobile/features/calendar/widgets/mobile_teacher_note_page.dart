import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/calendar/widgets/teacher_note_dialog.dart' show lessonSubjects;
import '../../../../features/lessons/models/lesson_item.dart';
import '../../../../features/people/utils/student_notes_strings.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';

// Matches the lesson sheet's face.
const double _faceSize = 72;

const int _minLines = 5;
const int _maxLines = 8;

// Sent to the administrators; the teacher does not see the note again.
class MobileTeacherNotePage extends StatefulWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;

  final VoidCallback onSent;

  const MobileTeacherNotePage({
    super.key,
    required this.lesson,
    required this.ministrySubjects,
    required this.onSent,
  });

  @override
  State<MobileTeacherNotePage> createState() => _MobileTeacherNotePageState();
}

class _MobileTeacherNotePageState extends State<MobileTeacherNotePage>
{
  final TextEditingController _text = TextEditingController();

  bool _busy = false;

  @override
  void dispose()
  {
    _text.dispose();
    super.dispose();
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _send() async
  {
    if (_busy)
    {
      return;
    }

    final String text = _text.text.trim();

    if (text.isEmpty)
    {
      MobileNotice.show(context, kEmptyNote, error: true);
      return;
    }

    setState(() => _busy = true);

    try
    {
      await ApiService().createTeacherNote(widget.lesson.id, text);

      if (mounted)
      {
        widget.onSent();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final LessonItem lesson = widget.lesson;
    final student = lesson.bookings.first.presence.student;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: kNewNoteEyebrow,
        title: '${student.firstName} ${student.lastName}',
        subtitle: '${lessonSubjects(lesson, widget.ministrySubjects)} · ${formatWeekdayColumnLabel(lesson.date)}',
        leading: MobileAvatar(
          firstName: student.firstName,
          lastName: student.lastName,
          imageUrl: student.profileImageUrl,
          size: _faceSize,
        ),
        aboveKeyboard: true,
        body: [
          const SizedBox(height: 18),
          const MobileSheetText(kTeacherNoteHint),
          const SizedBox(height: 18),
          MobileTextField(
            controller: _text,
            label: kTeacherNoteFieldLabel,
            maxLength: FieldLimits.studentNote,
            minLines: _minLines,
            maxLines: _maxLines,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: kSendLabel,
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}
