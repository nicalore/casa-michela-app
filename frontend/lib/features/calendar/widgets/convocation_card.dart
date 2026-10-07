import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import '../utils/calendar_strings.dart';
import '../utils/teacher_band_call.dart';
import 'band_summary_card.dart';

class ConvocationCard extends StatelessWidget
{
  final TeacherBandCall call;

  final bool isFeminine;

  const ConvocationCard({super.key, required this.call, required this.isFeminine});

  // In the building the room speaks for the mode; "In presenza" only while no room is set.
  List<Widget> _buildChips()
  {
    final room = call.room;
    final modes = {for (final span in call.byMode) span.mode};

    return [
      if (room != null)
        BandChip(
          icon: Icons.meeting_room_outlined,
          label: room.name,
          accent: AppTheme.trialTealDeep,
          surface: AppTheme.todaySurface,
        )
      else if (modes.contains(kPresenceMode))
        BandChip(
          icon: lessonModeIcon(kPresenceMode),
          label: modeLabel(kPresenceMode),
          accent: lessonAccent(kPresenceMode),
          surface: lessonSurface(kPresenceMode),
        ),
      if (call.supervisions.isNotEmpty)
        const BandChip(
          icon: Icons.shield_rounded,
          label: kSupervisorLabel,
          accent: kSupervisorColor,
          filled: true,
        ),
      if (modes.contains(kOnlineMode))
        BandChip(
          icon: lessonModeIcon(kOnlineMode),
          label: modeLabel(kOnlineMode),
          accent: lessonAccent(kOnlineMode),
          surface: lessonSurface(kOnlineMode),
        ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return BandSummaryCard(
      title: convocationTitle(call, feminine: isFeminine),
      summary: convocationSummary(call),
      chips: _buildChips(),
    );
  }
}
