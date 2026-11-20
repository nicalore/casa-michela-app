import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../calendar/utils/calendar_strings.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_face.dart';
import '../models/calendar_day.dart';
import '../utils/booking_wizard_strings.dart';
import 'person_avatar.dart';

const double _dialogWidth = 900;

const double _whoWidth = 250;

// Below this the field goes under the teacher.
const double _sideBySideWidth = 560;

// [onSave] gets the notes written, by teacher; true once they are kept.
Future<void> showTeacherNotesDialog({
  required BuildContext context,
  required String eyebrow,
  required List<TeacherLane> lanes,
  required Map<String, String> notes,
  required Future<bool> Function(Map<String, String> notes) onSave,
})
{
  final convened = convokedTeachers(lanes)..sort((a, b) => compareByName(a.teacher, b.teacher));

  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'TeacherNotes',
    builder: (context) => _TeacherNotesDialog(eyebrow: eyebrow, lanes: convened, notes: notes, onSave: onSave),
  );
}

String _countOf(int count, String one, String many) => count == 1 ? one : many;

// "15:00–17:30 · 3 lezioni", with the activities when there are some.
String teacherNoteDetail(TeacherLane lane)
{
  final spans = [
    for (final lesson in lane.lessons) (lesson.startMinutes, lesson.endMinutes),
    for (final activity in lane.activities) (activity.startMinutes, activity.endMinutes),
  ];

  final lessons = lane.lessons.length;
  final activities = lane.activities.length;

  return [
    if (spans.isNotEmpty)
      formatMinutesRange(
        spans.map((span) => span.$1).reduce((a, b) => a < b ? a : b),
        spans.map((span) => span.$2).reduce((a, b) => a > b ? a : b),
      ),
    if (lessons > 0) _countOf(lessons, tr('1 lezione', '1 lesson'), tr('$lessons lezioni', '$lessons lessons')),
    if (activities > 0)
      _countOf(activities, tr('1 attività', '1 activity'), tr('$activities attività', '$activities activities')),
  ].join(' · ');
}

class _TeacherNotesDialog extends StatefulWidget
{
  final String eyebrow;
  final List<TeacherLane> lanes;
  final Map<String, String> notes;
  final Future<bool> Function(Map<String, String> notes) onSave;

  const _TeacherNotesDialog({required this.eyebrow, required this.lanes, required this.notes, required this.onSave});

  @override
  State<_TeacherNotesDialog> createState() => _TeacherNotesDialogState();
}

class _TeacherNotesDialogState extends State<_TeacherNotesDialog>
{
  late final Map<String, TextEditingController> _texts = {
    for (final lane in widget.lanes) lane.teacherTaxCode: TextEditingController(text: widget.notes[lane.teacherTaxCode]),
  };

  bool _busy = false;

  @override
  void dispose()
  {
    for (final text in _texts.values)
    {
      text.dispose();
    }

    super.dispose();
  }

  Map<String, String> get _written => {
        for (final MapEntry(:key, :value) in _texts.entries)
          if (value.text.trim().isNotEmpty) key: value.text.trim(),
      };

  bool get _changed
  {
    final written = _written;
    final kept = {
      for (final lane in widget.lanes) lane.teacherTaxCode: ?widget.notes[lane.teacherTaxCode],
    };

    return written.length != kept.length || written.entries.any((entry) => kept[entry.key] != entry.value);
  }

  Future<void> _save() async
  {
    if (_busy)
    {
      return;
    }

    if (!_changed)
    {
      Navigator.of(context).pop();

      return;
    }

    setState(() => _busy = true);

    final kept = await widget.onSave(_written);

    if (!mounted)
    {
      return;
    }

    if (kept)
    {
      Navigator.of(context).pop();

      return;
    }

    setState(() => _busy = false);
  }

  Widget _buildWho(TeacherLane lane)
  {
    return Row(
      children: [
        PersonAvatar(person: lane.teacher, size: PersonAvatar.listSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lane.teacher.fullName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: AppTheme.trialOceanText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teacherNoteDetail(lane),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.trialMutedText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(TeacherLane lane)
  {
    return AppTextField(
      controller: _texts[lane.teacherTaxCode]!,
      label: calendarTeacherNoteField(lane.teacher.firstName),
      showLabel: false,
      hintText: kTeacherNotesHint,
      maxLength: FieldLimits.notes,
      minLines: 1,
      maxLines: 4,
    );
  }

  Widget _buildRow(TeacherLane lane, bool sideBySide)
  {
    if (!sideBySide)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWho(lane),
          const SizedBox(height: 10),
          _buildField(lane),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _whoWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildWho(lane),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(child: _buildField(lane)),
      ],
    );
  }

  Widget _buildList()
  {
    return AppScrollingDialogPill(
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final sideBySide = constraints.maxWidth >= _sideBySideWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, lane) in widget.lanes.indexed) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                  ),
                _buildRow(lane, sideBySide),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: widget.eyebrow,
      title: kCalendarTeacherNotesTitle,
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: tr('SALVA', 'SAVE'),
          icon: Icons.check_rounded,
          busy: _busy,
          height: 52,
          fontSize: 14,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: PersonEditGuide(question: kCalendarTeacherNotesQuestion, hint: kCalendarTeacherNotesHint),
        ),
        _buildList(),
      ],
    );
  }
}
