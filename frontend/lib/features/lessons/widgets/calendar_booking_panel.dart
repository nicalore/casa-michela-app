import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/activity_item.dart';
import '../models/schedulable_booking.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import 'calendar_activity_card.dart';
import 'calendar_booking_card.dart';
import 'calendar_lesson_block.dart';
import 'person_avatar.dart';

const double kBookingPanelWidth = 300;
const double kBookingStripHeight = 210;
const double kBookingBlockWidth = 288;

const String kAddActivityLabel = 'AGGIUNGI ATTIVITÀ';

const double _addHeight = 46;
const double _denseAddHeight = 32;

// Counted by request id, not by card: an unplanned request appears under every
// stretch of hours the pupil gave in that mode.
int openBookingCount(List<PresenceBookingGroup> groups)
{
  return groups
      .expand((group) => group.bookings)
      .where((entry) => !entry.isFullyCovered)
      .map((entry) => entry.id)
      .toSet()
      .length;
}

int openPanelCount(List<PresenceBookingGroup> groups, List<ActivityItem> activities)
{
  return openBookingCount(groups) + activities.length;
}

enum BookingPanelShape
{
  // Beside the track, full height.
  column,

  // Above the track on short windows; collapsible.
  strip,

  // Whole narrow screen, no track, cards open with a tap.
  page,
}

class _ExpandToggle extends StatefulWidget
{
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExpandToggle({required this.isExpanded, required this.onTap});

  @override
  State<_ExpandToggle> createState() => _ExpandToggleState();
}

class _ExpandToggleState extends State<_ExpandToggle>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return Tooltip(
      message: widget.isExpanded ? 'Nascondi le prenotazioni' : 'Mostra le prenotazioni',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hover ? AppTheme.trialGoldSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
                width: 1.5,
              ),
            ),
            child: Icon(
              widget.isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget
{
  final StudentBookingGroup student;

  const _StudentHeader({required this.student});

  String get _openLabel
  {
    final open = student.openCount;

    return switch (open)
    {
      0 => 'Tutto pianificato',
      1 => '1 prenotazione da pianificare',
      _ => '$open prenotazioni da pianificare',
    };
  }

  @override
  Widget build(BuildContext context)
  {
    final done = student.openCount == 0;

    return Row(
      children: [
        PersonAvatar(person: student.student, size: PersonAvatar.listSize),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.student.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppTheme.trialOcean,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _openLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: done ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresenceBand extends StatelessWidget
{
  final PresenceBookingGroup group;

  const _PresenceBand({required this.group});

  @override
  Widget build(BuildContext context)
  {
    final accent = lessonAccent(group.mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: lessonSurface(group.mode),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(lessonModeIcon(group.mode), size: 14, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              modeLabel(group.mode).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 1.1,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            group.hoursLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarBookingPanel extends StatelessWidget
{
  final List<PresenceBookingGroup> groups;
  final List<MinistrySubjectItem> ministrySubjects;

  // Only activities not yet assigned; assigned ones are drawn on the track.
  final List<ActivityItem> activities;

  final Map<String, String> teacherNames;

  final BookingPanelShape shape;

  // Strip shape only; ignored by the other shapes.
  final bool isExpanded;

  final ValueChanged<bool>? onExpandedChanged;

  final void Function(SchedulableBooking entry)? onPlanRequested;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  final ValueListenable<CarriedPlacement>? carriedAt;

  // Absent when the band cannot be edited: published, or locked by another editor.
  final VoidCallback? onAddActivity;

  final void Function(ActivityItem activity)? onOpenActivity;

  const CalendarBookingPanel({
    super.key,
    required this.groups,
    required this.ministrySubjects,
    this.activities = const [],
    this.teacherNames = const {},
    required this.shape,
    this.isExpanded = true,
    this.onExpandedChanged,
    this.onPlanRequested,
    this.onDragChanged,
    this.carriedAt,
    this.onAddActivity,
    this.onOpenActivity,
  });

  BookingDragMode get _dragMode
  {
    return switch (shape)
    {
      BookingPanelShape.column => BookingDragMode.immediate,
      BookingPanelShape.strip => BookingDragMode.longPress,
      BookingPanelShape.page => BookingDragMode.none,
    };
  }

  List<PresenceBookingGroup> get _visibleGroups
  {
    final filtered = <PresenceBookingGroup>[];

    for (final group in groups)
    {
      final open = group.bookings.where((entry) => !entry.isFullyCovered).toList();

      if (open.isNotEmpty)
      {
        filtered.add(PresenceBookingGroup(presence: group.presence, bookings: open));
      }
    }

    return filtered;
  }

  List<StudentBookingGroup> get _visibleStudents => groupByStudent(_visibleGroups);

  int get _openCount => openPanelCount(groups, activities);

  String get _emptyMessage
  {
    if (groups.isEmpty)
    {
      return 'Nessuna prenotazione.';
    }

    return 'Tutte le prenotazioni sono pianificate.';
  }

  Widget _buildHeader({required bool showToggle})
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Da pianificare',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        Text(
          '$_openCount',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialTealDeep,
          ),
        ),
        if (showToggle) ...[
          const SizedBox(width: 4),
          _buildExpandToggle(),
        ],
      ],
    );
  }

  Widget _buildExpandToggle()
  {
    return _ExpandToggle(
      isExpanded: isExpanded,
      onTap: () => onExpandedChanged?.call(!isExpanded),
    );
  }

  Widget _buildEmpty()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        _emptyMessage,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildCard(SchedulableBooking entry)
  {
    return CalendarBookingCard(
      entry: entry,
      ministrySubjects: ministrySubjects,
      teacherNames: teacherNames,
      dragMode: _dragMode,
      onPlanRequested: onPlanRequested == null ? null : () => onPlanRequested!(entry),
      onDragChanged: onDragChanged,
      carriedAt: carriedAt,
    );
  }

  Widget _buildActivityCard(ActivityItem activity)
  {
    return CalendarActivityCard(
      activity: activity,
      dragMode: _dragMode,
      onOpen: onOpenActivity == null ? null : () => onOpenActivity!(activity),
      onDragChanged: onDragChanged,
      carriedAt: carriedAt,
    );
  }

  List<Widget> _buildActivityCards({required bool named})
  {
    if (activities.isEmpty)
    {
      return const [];
    }

    return [
      if (named)
        Text(
          'ATTIVITÀ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: 1.1,
            color: AppTheme.trialMutedText,
          ),
        ),
      for (final activity in activities) _buildActivityCard(activity),
    ];
  }

  Widget? _buildAddActivity({bool dense = false})
  {
    final add = onAddActivity;

    if (add == null)
    {
      return null;
    }

    final double height = dense ? _denseAddHeight : _addHeight;

    return Center(
      child: AppGradientButton(
        label: kAddActivityLabel,
        icon: Icons.add_rounded,
        height: height,
        fontSize: dense ? 11 : 13,
        radius: height / 2,
        horizontalPadding: dense ? 16 : 30,
        onPressed: add,
      ),
    );
  }

  Widget _buildStudentBlock(StudentBookingGroup student)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 13),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StudentHeader(student: student),
          for (final group in student.presences) ...[
            const SizedBox(height: 12),
            _PresenceBand(group: group),
            for (final entry in group.bookings) ...[
              const SizedBox(height: 8),
              _buildCard(entry),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildColumn({bool showTitle = true})
  {
    final visible = _visibleStudents;
    final cards = _buildActivityCards(named: true);

    final rows = <Widget>[
      for (final student in visible) _buildStudentBlock(student),
      ...cards,
    ];

    final add = _buildAddActivity();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          _buildHeader(showToggle: false),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: rows.isEmpty
              ? SingleChildScrollView(child: _buildEmpty())
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => rows[index],
                ),
        ),
        if (add != null) ...[
          const SizedBox(height: 16),
          add,
        ],
      ],
    );
  }

  Widget _buildStrip()
  {
    final header = _buildHeader(showToggle: true);

    if (!isExpanded)
    {
      return header;
    }

    final visible = _visibleStudents;

    final rows = <Widget>[
      for (final student in visible) _buildStudentBlock(student),
      ..._buildActivityCards(named: false),
    ];

    final add = _buildAddActivity(dense: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 16),
        if (rows.isEmpty)
          _buildEmpty()
        else
          SizedBox(
            height: kBookingStripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: kBookingBlockWidth,
                child: SingleChildScrollView(child: rows[index]),
              ),
            ),
          ),
        if (add != null) ...[
          const SizedBox(height: 12),
          add,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return switch (shape)
    {
      BookingPanelShape.column => _buildColumn(),
      BookingPanelShape.strip => _buildStrip(),
      BookingPanelShape.page => _buildColumn(showTitle: false),
    };
  }
}
