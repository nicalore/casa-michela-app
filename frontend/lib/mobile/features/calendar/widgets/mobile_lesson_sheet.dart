import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/calendar/widgets/own_lesson_dialog.dart';
import '../../../../features/lessons/models/activity_item.dart';
import '../../../../features/lessons/models/lesson_item.dart';
import '../../../../features/lessons/widgets/activity_details_dialog.dart';
import '../../../../features/lessons/widgets/calendar_activity_block.dart' show kActivityWord;
import '../../../../features/lessons/widgets/calendar_lesson_block.dart' show lessonTitle;
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_height_reporter.dart';
import '../../../shared/widgets/mobile_page_strip.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../profile/widgets/mobile_detail_card.dart';

// Matches the eyebrow, name and day beside it.
const double _faceSize = 72;

// Assumed page height until measured.
const double _unmeasured = 320;

List<DetailRowData> _rowsOf(List<LessonVoice> voices)
{
  return [
    for (final voice in voices)
      DetailRowData(
        voice.label,
        voice.value,
        isSensitive: voice.sensitive && voice.value != kVoiceEmpty,
        hidesLength: true,
      ),
  ];
}

Future<void> showMobileLessonSheet({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  required PersonItem? student,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _LessonSheet(lesson: lesson, ministrySubjects: ministrySubjects, student: student),
  );
}

class _LessonSheet extends StatefulWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;
  final PersonItem? student;

  const _LessonSheet({
    required this.lesson,
    required this.ministrySubjects,
    required this.student,
  });

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet>
{
  static const List<String> _pageNames = ['Lezione', 'Studente'];

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
    final PersonItem? student = widget.student;

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
          _buildPage(
            0,
            MobileSheetCard(
              child: MobileDetailRows(rows: _rowsOf(lessonVoicesOf(widget.lesson, widget.ministrySubjects))),
            ),
          ),
          _buildPage(
            1,
            MobileSheetCard(
              child: student == null
                  ? const _Note(kStudentFailedNote)
                  : MobileDetailRows(rows: _rowsOf(studentVoicesOf(student))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final face = widget.lesson.bookings.firstOrNull?.presence.student;

    return MobileSheet(
      eyebrow: 'Lezione',
      title: lessonTitle(widget.lesson),
      subtitle: formatWeekdayColumnLabel(widget.lesson.date),
      closable: false,
      trailing: face == null
          ? null
          : MobileAvatar(
              firstName: face.firstName,
              lastName: face.lastName,
              imageUrl: face.profileImageUrl,
              size: _faceSize,
            ),
      subhead: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobilePageStrip(labels: _pageNames, controller: _pages, onLight: true),
      ),
      content: _buildPager(),
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
      closable: false,
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
