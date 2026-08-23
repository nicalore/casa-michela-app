import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/calendar_day.dart';
import '../models/room_day_plan.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

const double kLanePanelRadius = 20;

const double kLanePanelPadding = 11;

class CalendarLanePanel extends StatelessWidget
{
  final CalendarLane lane;

  final CalendarView view;

  final int bandStart;
  final int bandEnd;

  final LaneRoomLabel? room;

  final Widget child;

  const CalendarLanePanel({
    super.key,
    required this.lane,
    required this.bandStart,
    required this.bandEnd,
    required this.child,
    this.view = CalendarView.byTeacher,
    this.room,
  });

  Widget _buildWhen()
  {
    final said = laneWhenLabel(lane, bandStart: bandStart, bandEnd: bandEnd, view: view);

    final TextStyle quiet = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppTheme.trialMutedText,
    );

    final roomName = room?.roomName;

    if (roomName == null)
    {
      return Text(said, maxLines: 2, overflow: TextOverflow.ellipsis, style: quiet);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$said · ', style: quiet),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.trialTealDeep),
            ),
          ),
          TextSpan(
            text: roomName,
            style: quiet.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildHeader()
  {
    final isSupervisor = room?.isSupervisor ?? false;

    return Row(
      children: [
        PersonAvatar(person: lane.person, size: PersonAvatar.listSize),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
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
                  if (isSupervisor) ...[
                    const SizedBox(width: 6),
                    const Tooltip(
                      message: kSupervisorLabel,
                      child: Icon(Icons.shield_rounded, size: 14, color: kSupervisorColor),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              _buildWhen(),
            ],
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
}
