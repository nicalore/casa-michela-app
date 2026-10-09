import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/calendar/widgets/own_lesson_block.dart' show kSharedLessonIcon;
import '../../../../features/calendar/widgets/own_lesson_dialog.dart';
import '../../../../features/calendar/widgets/teacher_note_dialog.dart' show lessonHasBegun;
import '../../../../features/lessons/models/calendar_day.dart';
import '../../../../features/lessons/models/activity_item.dart';
import '../../../../features/lessons/models/lesson_item.dart';
import '../../../../features/lessons/models/person_option_item.dart';
import '../../../../features/lessons/widgets/activity_details_dialog.dart';
import '../../../../features/lessons/widgets/calendar_activity_block.dart' show kActivityWord;
import '../../../../features/lessons/widgets/calendar_lesson_block.dart' show lessonTitle;
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/models/student_note_item.dart';
import '../../../../features/people/utils/student_notes_strings.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../../features/people/widgets/student_notes_card.dart' show noteDate;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_height_reporter.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_page_strip.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_teacher_note_page.dart';

// Matches the eyebrow, name and day beside it.
const double _faceSize = 72;

// Assumed page height until measured.
const double _unmeasured = 320;

// [onNotes]: a voice with notes opens them from its row.
List<DetailRowData> _rowsOf(List<LessonVoice> voices, {ValueChanged<LessonVoice>? onNotes})
{
  return [
    for (final voice in voices)
      if (voice.notes case final notes? when notes.isNotEmpty && onNotes != null)
        DetailRowData.drawn(voice.label, _NotesCount(voice.value), onTap: () => onNotes(voice))
      else if (voice.icon != null)
        DetailRowData.drawn(voice.label, voiceValueText(voice.value, mobileFactValueStyle(), icon: voice.icon))
      else
        DetailRowData(
          voice.label,
          voice.value,
          isSensitive: voice.sensitive && voice.value != kVoiceEmpty,
          hidesLength: true,
        ),
  ];
}

// [withStudent] false: the lesson's facts alone, as for a day gone by.
Future<void> showMobileLessonSheet({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  required PersonItem? student,
  bool withStudent = true,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _LessonSheet(
      lesson: lesson,
      ministrySubjects: ministrySubjects,
      title: lessonTitle(lesson),
      subtitle: formatWeekdayColumnLabel(lesson.date),
      face: lesson.bookings.firstOrNull?.presence.student,
      otherName: withStudent ? 'Studente' : null,
      otherVoices: student == null ? null : studentVoicesOf(student),
      otherFailedNote: kStudentFailedNote,
      takesNote: lessonHasBegun(lesson, romeNow()),
    ),
  );
}

Future<void> showMobilePupilLessonSheet({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  required PersonItem? teacher,
  String? pupilName,
})
{
  final String day = formatWeekdayColumnLabel(lesson.date);

  return showMobileSheet<void>(
    context: context,
    builder: (context) => _LessonSheet(
      lesson: lesson,
      ministrySubjects: ministrySubjects,
      title: lessonTitle(lesson, view: CalendarView.byStudent),
      subtitle: pupilName == null ? day : '$pupilName · $day',
      face: lesson.teacher,
      otherName: 'Docente',
      otherVoices: teacher == null ? null : teacherVoicesOf(teacher),
      otherFailedNote: kTeacherFailedNote,
      forPupil: true,
    ),
  );
}

class _LessonSheet extends StatefulWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;

  final String title;
  final String subtitle;
  final PersonOptionItem? face;

  // Null: no second page, the lesson's facts alone.
  final String? otherName;
  final List<LessonVoice>? otherVoices;
  final String otherFailedNote;

  final bool forPupil;

  // The teacher may write a note for the administrators from the lesson's start on.
  final bool takesNote;

  const _LessonSheet({
    required this.lesson,
    required this.ministrySubjects,
    required this.title,
    required this.subtitle,
    required this.face,
    required this.otherName,
    required this.otherVoices,
    required this.otherFailedNote,
    this.forPupil = false,
    this.takesNote = false,
  });

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet>
{
  late final List<String> _pageNames = ['Lezione', ?widget.otherName];

  final PageController _pages = PageController();

  // Null until the page has been laid out.
  final ValueNotifier<List<double?>> _heights = ValueNotifier(const [null, null]);

  @override
  void dispose()
  {
    _pages.dispose();
    _heights.dispose();

    super.dispose();
  }

  double get _page
  {
    return _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? 0 : 0;
  }

  void _measured(int index, double height)
  {
    final double? known = _heights.value[index];

    if (known != null && (known - height).abs() < 0.5)
    {
      return;
    }

    _heights.value = [
      for (var i = 0; i < _pageNames.length; i++) i == index ? height : _heights.value[i],
    ];
  }

  Widget _buildPage(int index, Widget card)
  {
    return SingleChildScrollView(
      child: MobileHeightReporter(
        onHeight: (height) => _measured(index, height),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding, 16, MobileSheet.sidePadding, 6),
          child: card,
        ),
      ),
    );
  }

  // Height interpolates between pages while swiping.
  Widget _buildPager()
  {
    final List<LessonVoice>? other = widget.otherVoices;

    return AnimatedBuilder(
      animation: Listenable.merge([_pages, _heights]),
      builder: (context, child)
      {
        final double page = _page.clamp(0, _pageNames.length - 1).toDouble();
        final int low = page.floor();
        final int high = page.ceil();

        final List<double?> heights = _heights.value;
        final double from = heights[low] ?? heights[high] ?? _unmeasured;
        final double to = heights[high] ?? from;

        return SizedBox(height: ui.lerpDouble(from, to, page - low), child: child);
      },
      child: PageView(
        controller: _pages,
        // Keeps the other page laid out, so its height is known before a swipe.
        allowImplicitScrolling: true,
        children: [
          _buildPage(0, _buildLessonCard()),
          _buildPage(
            1,
            MobileSheetCard(
              child: other == null
                  ? _Note(widget.otherFailedNote)
                  : MobileDetailRows(rows: _rowsOf(other, onNotes: _openNotes)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard()
  {
    return MobileSheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileDetailRows(
            rows: _rowsOf(lessonVoicesOf(widget.lesson, widget.ministrySubjects, where: widget.forPupil)),
          ),
          if (widget.forPupil && widget.lesson.isShared) _SharedLine(sharedLessonSentence(widget.lesson)),
        ],
      ),
    );
  }

  Widget? _buildFace()
  {
    final PersonOptionItem? face = widget.face;

    return face == null
        ? null
        : MobileAvatar(
            firstName: face.firstName,
            lastName: face.lastName,
            imageUrl: face.profileImageUrl,
            size: _faceSize,
          );
  }

  // The sheet turns to the notes, newest first; closing turns it back.
  void _openNotes(LessonVoice voice)
  {
    final PersonOptionItem? face = widget.face;

    showMobileSheet<void>(
      context: context,
      builder: (context) => MobileSheet(
        eyebrow: voice.label,
        title: face == null ? widget.title : '${face.firstName} ${face.lastName}',
        subtitle: voice.value,
        leading: _buildFace(),
        body: [
          const SizedBox(height: 16),
          MobileSheetCard(
            child: MobileDetailRows(
              rows: [
                for (final StudentNoteItem note in voice.notes ?? const [])
                  DetailRowData.drawn(noteDate(note.createdAt), Text(note.text, style: _noteStyle())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The sheet turns to the form; once sent it turns back to the lesson.
  void _writeNote()
  {
    showMobileSheet<void>(
      context: context,
      builder: (_) => MobileTeacherNotePage(
        lesson: widget.lesson,
        ministrySubjects: widget.ministrySubjects,
        onSent: ()
        {
          if (!mounted)
          {
            return;
          }

          returnToMobileSheetPage(context);
          MobileNotice.show(context, kNoteSent);
        },
      ),
    );
  }

  // Under the pages, so it stays put while they are swiped.
  Widget? _buildFooter()
  {
    if (!widget.takesNote)
    {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MobileGoldButton(label: kAddNoteLabel, icon: Icons.add_rounded, onPressed: _writeNote),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget? leading = _buildFace();

    if (widget.otherName == null)
    {
      return MobileSheet(
        eyebrow: 'Lezione',
        title: widget.title,
        subtitle: widget.subtitle,
        leading: leading,
        body: [
          const SizedBox(height: 16),
          _buildLessonCard(),
        ],
        footer: _buildFooter(),
      );
    }

    return MobileSheet(
      eyebrow: 'Lezione',
      title: widget.title,
      subtitle: widget.subtitle,
      leading: leading,
      subhead: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobilePageStrip(labels: _pageNames, controller: _pages, onLight: true),
      ),
      content: _buildPager(),
      footer: _buildFooter(),
    );
  }
}

Future<void> showMobileActivitySheet({
  required BuildContext context,
  required ActivityItem activity,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: kActivityWord,
      title: activity.name,
      subtitle: formatWeekdayColumnLabel(activity.date),
      body: [
        const SizedBox(height: 16),
        MobileSheetCard(
          child: MobileDetailRows(
            rows: [for (final voice in activityVoicesOf(activity)) DetailRowData(voice.label, voice.value)],
          ),
        ),
      ],
    ),
  );
}

// Lighter than a fact: a note runs for lines.
TextStyle _noteStyle()
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 15.5,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppTheme.trialInk,
  );
}

class _NotesCount extends StatelessWidget
{
  final String text;

  const _NotesCount(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Row(
      children: [
        Expanded(child: Text(text, style: mobileFactValueStyle())),
        Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialInk.withValues(alpha: 0.36)),
      ],
    );
  }
}

class _Note extends StatelessWidget
{
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }
}

class _SharedLine extends StatelessWidget
{
  final String text;

  const _SharedLine(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(kSharedLessonIcon, size: 18, color: AppTheme.trialTealDeep),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
