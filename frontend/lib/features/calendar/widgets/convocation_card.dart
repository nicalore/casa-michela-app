import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import '../utils/teacher_band_call.dart';
import 'band_summary_card.dart';

class ConvocationCard extends StatelessWidget
{
  final TeacherBandCall call;

  final bool isFeminine;

  const ConvocationCard({super.key, required this.call, required this.isFeminine});

  String get _title
  {
    final inBuilding = call.byMode.where((span) => span.mode == kPresenceMode).firstOrNull;

    if (inBuilding == null)
    {
      return 'Lezioni online';
    }

    final word = isFeminine ? 'Convocata' : 'Convocato';

    return '$word dalle ${formatTimeOfDayShort(timeOfDayFromMinutes(inBuilding.startMinutes))} '
        'alle ${formatTimeOfDayShort(timeOfDayFromMinutes(inBuilding.endMinutes))}';
  }

  String get _summary
  {
    return [
      countOf(call.lessons.length, 'lezione', 'lezioni'),
      countOf(call.studentCount, 'studente', 'studenti'),
      if (call.activities.isNotEmpty) countOf(call.activities.length, 'attività', 'attività'),
      '${formatMinutes(call.lessonMinutes)} di lezione',
    ].join(' · ');
  }

  List<Widget> _buildChips()
  {
    final room = call.room;

    return [
      for (final span in call.byMode)
        BandChip(
          icon: lessonModeIcon(span.mode),
          label: modeLabel(span.mode),
          accent: lessonAccent(span.mode),
          surface: lessonSurface(span.mode),
        ),
      if (room != null)
        BandChip(
          icon: Icons.meeting_room_outlined,
          label: room.name,
          accent: AppTheme.trialTealDeep,
          surface: AppTheme.todaySurface,
        ),
      if (call.supervisions.isNotEmpty)
        const BandChip(
          icon: Icons.shield_rounded,
          label: kSupervisorLabel,
          accent: kSupervisorColor,
          filled: true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return BandSummaryCard(title: _title, summary: _summary, chips: _buildChips());
  }
}
