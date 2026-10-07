import 'package:flutter/material.dart';

import '../../../core/utils/week_range.dart';
import '../../lessons/utils/opening_window.dart';
import '../utils/calendar_strings.dart';
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
      return kOnlineLessonsTitle;
    }

    return '$kPresentWord dalle ${formatTimeOfDayShort(timeOfDayFromMinutes(inBuilding.startMinutes))} '
        'alle ${formatTimeOfDayShort(timeOfDayFromMinutes(inBuilding.endMinutes))}';
  }

  @override
  Widget build(BuildContext context)
  {
    return BandSummaryCard(
      eyebrow: pupilName,
      title: _title,
      summary: presenceSummary(presence),
      compact: compact,
    );
  }
}
