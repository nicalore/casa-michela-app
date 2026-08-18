import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../utils/opening_window.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

// The band read as a list, for the widths where it cannot be read as a track.
//
// Kept by teacher and not by hour, which is the decision the whole file turns
// on. A day sorted by the clock is the shorter list and the easier one to
// scan — but it can only show the hours that exist, and half of what somebody
// composing a day is looking for is the hours that do not: the teacher who
// offered four hours and has nothing on them. The lanes of the timeline, laid
// one under the next, carry both. What the track drew as an empty row this
// draws as a block that says so in words.

// The paper block a teacher gets, the same one a pupil gets in the panel: the
// two lists stand one switch apart and reading as two different screens would
// be reading as two different days.
const double _blockRadius = 20;

// The bar in the colour of the mode down the left of an hour, and how far in it
// stands. The same shape and the same inset the card in the panel wears, so a
// request and the hour it became are the same object in two lists.
const double _modeBarWidth = 4;
const double _modeBarInset = 9;

// Everything already written into the band, teacher by teacher.
//
// A row opens exactly what a block on the track opens — the window on the
// request the hour is part of — because it is the same hour, and there is one
// window for it whichever list it was reached from.
class CalendarDayAgenda extends StatelessWidget
{
  // The lanes of the band, teachers and all. Not the lessons alone: a teacher
  // with nothing planned on them is invisible in a list of what is planned, and
  // that is exactly who is being looked for. They keep the order the track gave
  // them — in the building first, then by name — so the two views of the day
  // are read in the same sequence.
  final List<TeacherLane> lanes;

  final int bandStart;
  final int bandEnd;

  // Which hours landed on a teacher the pupil would rather avoid, and which on
  // one they asked for.
  //
  // Worked out by whoever is calling, the way the track has it. Not read off
  // `LessonItem.warnings`: that field is filled by the answer to a write and is
  // empty by the next read, so an agenda that trusted it would show the marks
  // once and never again.
  final Set<int> warnedLessonIds;
  final Set<int> preferredLessonIds;

  final void Function(LessonItem lesson)? onLessonTap;

  const CalendarDayAgenda({
    super.key,
    required this.lanes,
    required this.bandStart,
    required this.bandEnd,
    this.warnedLessonIds = const {},
    this.preferredLessonIds = const {},
    this.onLessonTap,
  });

  int get _lessonCount => lanes.fold<int>(0, (total, lane) => total + lane.lessons.length);

  // The head of the list, said the way the panel says its own: the name on the
  // left and the count on the right, in the same two sizes and the same two
  // colours. The two are siblings one switch apart and have to read as such.
  Widget _buildHeader()
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            'In calendario',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        Text(
          '$_lessonCount',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialTealDeep,
          ),
        ),
      ],
    );
  }

  // One teacher: who they are, when they offered, and what has been written on
  // them so far.
  Widget _buildLaneBlock(TeacherLane lane)
  {
    final lessons = [...lane.lessons]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 13),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(_blockRadius),
        border: Border.all(color: AppTheme.trialLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLaneHeader(lane),
          if (lessons.isEmpty) ...[
            const SizedBox(height: 10),
            _buildLaneEmpty(),
          ],
          for (final lesson in lessons) ...[
            const SizedBox(height: 8),
            _AgendaRow(
              lesson: lesson,
              hasWarning: warnedLessonIds.contains(lesson.id),
              isPreferred: preferredLessonIds.contains(lesson.id),
              // The same guard the track puts on its own blocks: an hour this
              // client drew and the server has not answered for yet has no id,
              // so the window would be opened on a lesson that does not exist.
              // The wait is one round trip long and the row simply does not
              // answer until then.
              onTap: onLessonTap == null || lesson.isProvisional ? null : () => onLessonTap!(lesson),
            ),
          ],
        ],
      ),
    );
  }

  // The teacher, and the hours they put up in this band.
  //
  // The hours are the thing the track said with the length of a stretch and a
  // list has no way of drawing, so here they are written out. Both modes where
  // both were offered: a teacher available in the building until four and at a
  // screen after it is two different answers to "can this go here", and the
  // panel's cards carry the mode they need.
  Widget _buildLaneHeader(TeacherLane lane)
  {
    final windows = [
      for (final mode in const [kPresenceMode, kOnlineMode])
        for (final span in lane.spansIn(mode, bandStart, bandEnd))
          '${modeLabel(mode)} ${formatMinutesRange(span.$1, span.$2)}',
    ];

    return Row(
      children: [
        PersonAvatar(person: lane.teacher, size: PersonAvatar.listSize),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lane.teacher.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppTheme.trialOcean,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                windows.isEmpty ? 'Nessuna disponibilità' : windows.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // The line that says this teacher is free, which is the one thing a list of
  // lessons cannot say by itself and half of what this screen is for.
  Widget _buildLaneEmpty()
  {
    return Text(
      'Nessuna lezione.',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        fontStyle: FontStyle.italic,
        color: AppTheme.trialMutedText,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: lanes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _buildLaneBlock(lanes[index]),
          ),
        ),
      ],
    );
  }
}

// One hour, as a row.
//
// Drawn in the colours the same hour wears on the track — the bar of the mode
// down its left, the accent on its times, gold along its edge under the
// pointer — because it *is* that block, on a screen with no room to draw it
// against an axis. Somebody who has used the wide calendar should recognise
// the thing they are about to tap.
class _AgendaRow extends StatefulWidget
{
  final LessonItem lesson;
  final bool hasWarning;
  final bool isPreferred;
  final VoidCallback? onTap;

  const _AgendaRow({
    required this.lesson,
    required this.hasWarning,
    required this.isPreferred,
    this.onTap,
  });

  @override
  State<_AgendaRow> createState() => _AgendaRowState();
}

class _AgendaRowState extends State<_AgendaRow>
{
  bool _hover = false;

  LessonItem get _lesson => widget.lesson;

  // The disciplines and the room, in one line that ends in an ellipsis rather
  // than in a second line: the rows are scanned down and a list whose items are
  // two lines tall sometimes and three others has no rhythm to scan by.
  //
  // The teacher is not in it. They are the head of the block this row stands
  // in, and saying them again on every hour under it is the block's own title
  // repeated four times.
  String get _details
  {
    return [
      if (_lesson.disciplineNames.isNotEmpty) _lesson.disciplineNames.join(', ') else 'Servizio',
      if (_lesson.room != null) _lesson.room!.name,
    ].join(' · ');
  }

  Color get _borderColor
  {
    if (_hover && widget.onTap != null)
    {
      return AppTheme.trialGold;
    }

    return lessonAccent(_lesson.mode).withValues(alpha: 0.35);
  }

  // The hour, its length, and the marks the track puts on it.
  Widget _buildTopRow()
  {
    final accent = lessonAccent(_lesson.mode);

    return Row(
      children: [
        Icon(lessonModeIcon(_lesson.mode), size: 13, color: accent),
        const SizedBox(width: 5),
        Text(
          formatTimeRange(_lesson.startTime, _lesson.endTime),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: accent,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '· ${formatMinutes(_lesson.minutes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        // The same three marks the block wears and in the same order, so that
        // what a colour means is learnt once. See the note above lessonAccent
        // for what each of them is allowed to say.
        if (widget.isPreferred) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Docente richiesto dall\'alunno',
            child: Icon(Icons.star_rounded, size: 14, color: kPreferredTeacherColor),
          ),
        ],
        if (widget.hasWarning) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Docente che l\'alunno preferirebbe evitare',
            child: Icon(Icons.circle, size: 9, color: kAvoidedTeacherColor),
          ),
        ],
        if (_lesson.isPublished) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Orario pubblicato: non modificabile',
            child: Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.trialMutedText),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final onTap = widget.onTap;

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor, width: 1.5),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                bottom: 10,
                left: _modeBarInset,
                width: _modeBarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: lessonAccent(_lesson.mode),
                    borderRadius: BorderRadius.circular(_modeBarWidth / 2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_modeBarInset + _modeBarWidth + 9, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lessonTitle(_lesson),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: AppTheme.trialOcean,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  color: AppTheme.trialMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // What says the row opens something, and the reason the
                        // cursor is not enough on its own: the cursor answers
                        // once the pointer is already on the row, and on the
                        // screens this list is for there is no pointer at all.
                        if (onTap != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.trialMutedText),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
