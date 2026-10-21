import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
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
  // Changing room, each room has a section of its own below instead.
  List<Widget> _buildChips()
  {
    final room = call.room;
    final modes = {for (final span in call.byMode) span.mode};

    return [
      if (!call.changesRoom && room != null)
        _RoomChip(name: room.name)
      else if (room == null && modes.contains(kPresenceMode))
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

  Widget? _buildFooter()
  {
    if (call.changesRoom)
    {
      return _RoomSections(rooms: call.rooms);
    }

    final supervisors = call.rooms.firstOrNull?.supervisors ?? const <RoomSupervisor>[];

    return supervisors.isEmpty ? null : _RoomSupervisors(supervisors: supervisors);
  }

  @override
  Widget build(BuildContext context)
  {
    return BandSummaryCard(
      title: convocationTitle(call, feminine: isFeminine),
      summary: convocationSummary(call),
      chips: _buildChips(),
      footer: _buildFooter(),
    );
  }
}

class _RoomChip extends StatelessWidget
{
  final String name;

  const _RoomChip({required this.name});

  @override
  Widget build(BuildContext context)
  {
    return BandChip(
      icon: Icons.meeting_room_outlined,
      label: name,
      accent: AppTheme.trialTealDeep,
      surface: AppTheme.todaySurface,
    );
  }
}

const double _sectionGap = 40;

// Side by side while each section keeps this much room, else one under the other.
const double _sectionMinWidth = 320;

// One section per room: the room, its hours, then who supervises it meanwhile.
class _RoomSections extends StatelessWidget
{
  final List<RoomStay> rooms;

  const _RoomSections({required this.rooms});

  Widget _buildSection(RoomStay stay)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _RoomChip(name: stay.room.name)),
            const SizedBox(width: 12),
            Text(
              formatMinutesRange(stay.startMinutes, stay.endMinutes),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppTheme.trialOcean,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (stay.supervisors.isNotEmpty) ...[
          const SizedBox(height: 16),
          _RoomSupervisors(supervisors: stay.supervisors),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final sideBySide =
            constraints.maxWidth >= rooms.length * _sectionMinWidth + (rooms.length - 1) * (_sectionGap * 2 + 1);

        if (!sideBySide)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, stay) in rooms.indexed) ...[
                if (i > 0) const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                ),
                _buildSection(stay),
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, stay) in rooms.indexed) ...[
                if (i > 0) const Padding(
                  padding: EdgeInsets.symmetric(horizontal: _sectionGap),
                  child: VerticalDivider(width: 1, thickness: 1, color: AppTheme.trialLine),
                ),
                Flexible(child: _buildSection(stay)),
              ],
            ],
          ),
        );
      },
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
