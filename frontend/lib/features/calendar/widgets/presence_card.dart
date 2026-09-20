import 'package:flutter/material.dart';

import '../../../core/utils/week_range.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import '../utils/pupil_band_presence.dart';
import 'band_summary_card.dart';

class PresenceCard extends StatelessWidget
{
  final PupilBandPresence presence;

  final String? pupilName;

  final bool compact;

  const PresenceCard({super.key, required this.presence, this.pupilName, this.compact = false});

  String get _title
  {
    final inBuilding = presence.byMode.where((span) => span.mode == kPresenceMode).firstOrNull;

    if (inBuilding == null)
    {
      return 'Lezioni online';
    }

    return 'Presente dalle ${formatTimeOfDayShort(timeOfDayFromMinutes(inBuilding.startMinutes))} '
        'alle ${formatTimeOfDayShort(timeOfDayFromMinutes(inBuilding.endMinutes))}';
  }

  String get _summary
  {
    return [
      countOf(presence.lessons.length, 'lezione', 'lezioni'),
      '${formatMinutes(presence.lessonMinutes)} di lezione',
    ].join(' · ');
  }

  List<Widget> _buildChips()
  {
    return [
      for (final span in presence.byMode)
        BandChip(
          icon: lessonModeIcon(span.mode),
          label: modeLabel(span.mode),
          accent: lessonAccent(span.mode),
          surface: lessonSurface(span.mode),
        ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return BandSummaryCard(
      eyebrow: pupilName,
      title: _title,
      summary: _summary,
      chips: _buildChips(),
      compact: compact,
    );
  }
}
