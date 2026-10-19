import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import '../../lessons/widgets/person_avatar.dart';
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
      footer: call.roomSupervisors.isEmpty ? null : _RoomSupervisors(supervisors: call.roomSupervisors),
    );
  }
}

class _RoomSupervisors extends StatelessWidget
{
  final List<RoomSupervisor> supervisors;

  const _RoomSupervisors({required this.supervisors});

  Widget _buildSupervisor(RoomSupervisor supervisor)
  {
    final String? hours = supervisorHours(supervisor, count: supervisors.length);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonAvatar(person: supervisor.person, size: PersonAvatar.pickerSize),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  supervisor.person.fullName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppTheme.trialOcean,
                  ),
                ),
                if (supervisor.isSelf) ...[
                  const SizedBox(width: 8),
                  const _SelfBadge(),
                ],
              ],
            ),
            if (hours != null)
              Text(
                hours,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: AppTheme.trialMutedText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roomSupervisorsHeading(supervisors.length).toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 36,
          runSpacing: 12,
          children: [for (final supervisor in supervisors) _buildSupervisor(supervisor)],
        ),
      ],
    );
  }
}

class _SelfBadge extends StatelessWidget
{
  const _SelfBadge();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.trialTealDeep.withValues(alpha: 0.3)),
      ),
      child: Text(
        kSelfMark.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 1.1,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}
