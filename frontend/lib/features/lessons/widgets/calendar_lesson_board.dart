import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/activity_item.dart';
import '../models/calendar_day.dart';
import '../models/lesson_item.dart';
import '../models/room_day_plan.dart';
import 'calendar_activity_block.dart';
import 'calendar_lane_panel.dart';
import 'calendar_lesson_block.dart';

const double kBoardCardMin = 232;
const double kBoardCardMax = 320;

const double _cardGap = 6;

double _boardCardWidth(double available)
{
  final columns = math.max(1, ((available + _cardGap) / (kBoardCardMin + _cardGap)).floor());
  final fitted = (available - (columns - 1) * _cardGap) / columns;

  return columns == 1 ? fitted : math.min(fitted, kBoardCardMax);
}

// Hours kept beside the widget: the "now" line needs to find the card a minute falls in.
typedef _BoardCard = ({int startMinutes, int endMinutes, Widget card});

const double _nowLineWidth = 2;
const double _nowLineBleed = 4;

class CalendarLaneNowLine extends StatelessWidget
{
  const CalendarLaneNowLine({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const IgnorePointer(child: CustomPaint(painter: _NowLinePainter()));
  }
}

class _NowLinePainter extends CustomPainter
{
  const _NowLinePainter();

  @override
  void paint(Canvas canvas, Size size)
  {
    final x = size.width / 2;

    canvas.drawRRect(
      RRect.fromLTRBR(
        x - _nowLineWidth / 2,
        0,
        x + _nowLineWidth / 2,
        size.height,
        Radius.circular(_nowLineWidth / 2),
      ),
      Paint()..color = AppTheme.trialDanger,
    );
  }

  @override
  bool shouldRepaint(_NowLinePainter oldDelegate) => false;
}

class CalendarLessonBoard extends StatelessWidget
{
  final List<CalendarLane> lanes;

  final CalendarView view;

  final List<MinistrySubjectItem> ministrySubjects;

  final int bandStart;
  final int bandEnd;

  final Set<int> warnedLessonIds;
  final Set<int> preferredLessonIds;

  final Set<int> pastLessonIds;

  final Map<String, LaneRoomLabel> roomByTeacher;

  final int? nowMinutes;

  final void Function(LessonItem lesson)? onLessonTap;

  final void Function(ActivityItem activity)? onActivityTap;

  const CalendarLessonBoard({
    super.key,
    required this.lanes,
    required this.bandStart,
    required this.bandEnd,
    this.nowMinutes,
    this.view = CalendarView.byTeacher,
    this.ministrySubjects = const [],
    this.warnedLessonIds = const {},
    this.preferredLessonIds = const {},
    this.pastLessonIds = const {},
    this.roomByTeacher = const {},
    this.onLessonTap,
    this.onActivityTap,
  });

  // Lessons and activities in one list, in clock order.
  List<_BoardCard> _cardsOf(CalendarLane lane, double cardWidth)
  {
    final cards = <_BoardCard>[
      for (final lesson in lane.lessons)
        (
          startMinutes: lesson.startMinutes,
          endMinutes: lesson.endMinutes,
          card: CalendarLessonBlock(
            lesson: lesson,
            width: cardWidth,
            view: view,
            ministrySubjects: ministrySubjects,
            hasWarning: warnedLessonIds.contains(lesson.id),
            isPreferred: preferredLessonIds.contains(lesson.id),
            isPast: pastLessonIds.contains(lesson.id),
            onTap: onLessonTap == null || lesson.isProvisional ? null : () => onLessonTap!(lesson),
          ),
        ),
      for (final scheduled in lane.activities)
        (
          startMinutes: scheduled.startMinutes,
          endMinutes: scheduled.endMinutes,
          card: CalendarActivityBlock(
            scheduled: scheduled,
            width: cardWidth,
            onTap: onActivityTap == null ? null : () => onActivityTap!(scheduled.activity),
          ),
        ),
    ];

    return cards..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  Widget _buildLane(CalendarLane lane, double cardWidth, double available)
  {
    final cards = _cardsOf(lane, cardWidth);

    if (cards.isEmpty)
    {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: CalendarLaneEmpty(),
      );
    }

    return _buildCards(cards, cardWidth, available);
  }

  int _perRun(double cardWidth, double available)
  {
    return math.max(1, ((available + _cardGap) / (cardWidth + _cardGap)).floor());
  }

  ({double left, double top})? _nowLineAt(
    List<_BoardCard> cards,
    double cardWidth,
    double available,
  )
  {
    final now = nowMinutes;

    if (now == null || now < cards.first.startMinutes)
    {
      return null;
    }

    final perRun = _perRun(cardWidth, available);
    final height = lessonBlockHeight(view);

    ({double left, double top}) at(int index, double withinCard)
    {
      return (
        left: (index % perRun) * (cardWidth + _cardGap) + withinCard,
        top: (index ~/ perRun) * (height + _cardGap),
      );
    }

    for (var index = 0; index < cards.length; index++)
    {
      final card = cards[index];

      if (now < card.startMinutes)
      {
        return at(index - 1, cardWidth + _cardGap / 2);
      }

      if (now < card.endMinutes)
      {
        final span = card.endMinutes - card.startMinutes;
        final through = span <= 0 ? 0.0 : (now - card.startMinutes) / span;

        return at(index, cardWidth * through);
      }
    }

    return null;
  }

  Widget _buildCards(List<_BoardCard> cards, double cardWidth, double available)
  {
    final now = _nowLineAt(cards, cardWidth, available);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Stack(
        children: [
          _buildWrap(cards, cardWidth),
          if (now != null)
            Positioned(
              left: now.left - _nowLineWidth,
              top: now.top - _nowLineBleed,
              width: _nowLineWidth * 2,
              height: lessonBlockHeight(view) + 2 * _nowLineBleed,
              child: const CalendarLaneNowLine(),
            ),
        ],
      ),
    );
  }

  Widget _buildWrap(List<_BoardCard> cards, double cardWidth)
  {
    return Wrap(
      spacing: _cardGap,
      runSpacing: _cardGap,
      children: [
        for (final entry in cards)
          SizedBox(
            width: cardWidth,
            height: lessonBlockHeight(view),
            child: entry.card,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final available = constraints.maxWidth - 2 * kLanePanelPadding;
        final cardWidth = _boardCardWidth(available);

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: lanes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index)
          {
            final lane = lanes[index];

            return CalendarLanePanel(
              lane: lane,
              view: view,
              bandStart: bandStart,
              bandEnd: bandEnd,
              room: roomByTeacher[lane.personTaxCode],
              child: _buildLane(lane, cardWidth, available),
            );
          },
        );
      },
    );
  }
}
