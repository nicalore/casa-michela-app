import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/descender_room.dart';
import '../models/calendar_day.dart';
import '../models/room_day_plan.dart';
import '../utils/calendar_search.dart';
import 'calendar_lesson_block.dart';
import 'calendar_search_fade.dart';
import 'person_avatar.dart';
import 'teacher_exclusion_overlay.dart';

const double kLanePanelRadius = 20;

const double kLanePanelPadding = 11;

class CalendarLanePanel extends StatelessWidget
{
  final CalendarLane lane;

  final CalendarView view;

  final int bandStart;
  final int bandEnd;

  final LaneRoomLabel? room;

  final bool isExcluded;

  final VoidCallback? onToggleExcluded;

  // Whoever is found by name wears the gold ring.
  final ValueListenable<CalendarSearch?>? search;

  final Widget child;

  const CalendarLanePanel({
    super.key,
    required this.lane,
    required this.bandStart,
    required this.bandEnd,
    required this.child,
    this.view = CalendarView.byTeacher,
    this.room,
    this.isExcluded = false,
    this.onToggleExcluded,
    this.search,
  });

  Widget _buildFace()
  {
    final Widget face = PersonAvatar(person: lane.person, size: PersonAvatar.listSize);
    final finder = search;

    if (finder == null)
    {
      return face;
    }

    return ValueListenableBuilder<CalendarSearch?>(
      valueListenable: finder,
      child: face,
      builder: (context, found, face)
      {
        final bool isFound = found != null && found.findsPerson(lane.person);

        return AnimatedContainer(
          duration: kSearchFade,
          curve: Curves.easeOut,
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: isFound ? 1 : 0), width: 2),
          ),
          child: face,
        );
      },
    );
  }

  Widget _buildWhen()
  {
    final said = laneWhenLabel(lane, bandStart: bandStart, bandEnd: bandEnd, view: view);

    final TextStyle quiet = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialMutedText,
    );

    final label = room;

    if (label == null || label.roomName == null)
    {
      return DescenderRoom(child: Text(said, maxLines: 2, overflow: TextOverflow.ellipsis, style: quiet));
    }

    final named = quiet.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep);

    // Hours and the shield only for a lane changing room: with one, the band says it all.
    return DescenderRoom(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: said, style: quiet),
            for (final stay in label.stays) ...[
              TextSpan(text: ' · ', style: quiet),
              // A room the teacher answers for wears the shield in place of the door.
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: stay.isSupervisor
                      ? const AppTooltip(
                          message: kSupervisorLabel,
                          child: Icon(Icons.shield_rounded, size: 12, color: kSupervisorColor),
                        )
                      : const Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.trialTealDeep),
                ),
              ),
              TextSpan(text: stay.room.name, style: named),
              if (label.changesRoom) TextSpan(text: ' ${formatMinutesRange(stay.startMinutes, stay.endMinutes)}', style: quiet),
            ],
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildHeader()
  {
    return Row(
      children: [
        SizedBox(
          width: PersonAvatar.listSize,
          height: PersonAvatar.listSize,
          child: Stack(
            children: [
              AnimatedOpacity(
                duration: kExcludedLaneFade,
                curve: kExcludedLaneCurve,
                opacity: isExcluded ? kExcludedLaneOpacity : 1,
                child: _buildFace(),
              ),
              if (onToggleExcluded != null)
                Positioned.fill(
                  child: TeacherExclusionOverlay(
                    isExcluded: isExcluded,
                    onToggle: onToggleExcluded,
                    signSize: 20,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: AnimatedOpacity(
            duration: kExcludedLaneFade,
            curve: kExcludedLaneCurve,
            opacity: isExcluded ? kExcludedLaneOpacity : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: DescenderRoom(
                        child: Text(
                          lane.person.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppTheme.trialOcean,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _buildWhen(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(kLanePanelPadding, kLanePanelPadding, kLanePanelPadding, 13),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(kLanePanelRadius),
        border: Border.all(color: AppTheme.trialLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          child,
        ],
      ),
    );
  }
}

class CalendarLaneEmpty extends StatelessWidget
{
  const CalendarLaneEmpty({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Center(
      child: Text(
        'Nessuna lezione.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }
}
