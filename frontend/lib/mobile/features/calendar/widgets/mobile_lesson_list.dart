import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/mobile_palette.dart';
import 'mobile_calendar_timeline.dart' show MobileNowPill;
import 'mobile_lesson_card.dart';

const double _rowGap = 12;
const double _tabletRowGap = 14;

const double _nowGap = 32;

const double _nowStroke = 2;

class MobileLessonList extends StatelessWidget
{
  final List<MobileCalendarEntry> entries;

  // Minute of the day; null unless the day shown is today.
  final int? nowMinutes;
  final bool pastDay;

  final bool tablet;

  final Key? nowKey;

  const MobileLessonList({
    super.key,
    required this.entries,
    required this.nowMinutes,
    required this.pastDay,
    required this.tablet,
    this.nowKey,
  });

  static List<MobileCalendarEntry> _ordered(List<MobileCalendarEntry> entries)
  {
    return [...entries]
      ..sort((a, b) => a.startMinutes != b.startMinutes
          ? a.startMinutes.compareTo(b.startMinutes)
          : a.endMinutes.compareTo(b.endMinutes));
  }

  // Before the lesson at that index, with every earlier one over.
  static int? _nowBefore(List<MobileCalendarEntry> ordered, int? now)
  {
    if (now == null || ordered.isEmpty)
    {
      return null;
    }

    var over = ordered.first.endMinutes;

    for (var i = 1; i < ordered.length; i++)
    {
      if (now < over)
      {
        return null;
      }

      if (now < ordered[i].startMinutes)
      {
        return i;
      }

      over = math.max(over, ordered[i].endMinutes);
    }

    return null;
  }

  static bool showsNow(List<MobileCalendarEntry> entries, int? nowMinutes, {required bool pastDay})
  {
    return _nowBefore(_ordered(entries), nowMinutes) != null ||
        entries.any((entry) => entry.timeAt(nowMinutes, pastDay: pastDay) == MobileEntryTime.running);
  }

  Widget _buildNow()
  {
    return SizedBox(
      height: _nowGap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: (_nowGap - _nowStroke) / 2,
            height: _nowStroke,
            child: ColoredBox(color: MobilePalette.nowLine),
          ),
          Positioned(
            left: 0,
            top: _nowGap / 2,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: MobileNowPill(key: nowKey, minutes: nowMinutes!),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<MobileCalendarEntry> ordered = _ordered(entries);

    final int? nowBefore = _nowBefore(ordered, nowMinutes);

    // The key goes to the present: the gap, or else the first lesson under way.
    final int running = nowBefore != null
        ? -1
        : ordered.indexWhere((entry) => entry.timeAt(nowMinutes, pastDay: pastDay) == MobileEntryTime.running);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, entry) in ordered.indexed) ...[
          if (i > 0)
            if (i == nowBefore) _buildNow() else SizedBox(height: tablet ? _tabletRowGap : _rowGap),
          MobileLessonListCard(
            key: i == running ? nowKey : null,
            entry: entry,
            time: entry.timeAt(nowMinutes, pastDay: pastDay),
            scale: tablet ? kMobileTabletCardScale : kMobilePhoneCardScale,
          ),
        ],
      ],
    );
  }
}
