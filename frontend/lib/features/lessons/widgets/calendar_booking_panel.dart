import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_floating_panel.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/activity_item.dart';
import '../models/presence_item.dart';
import '../models/schedulable_booking.dart';
import '../utils/calendar_search.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import 'calendar_activity_card.dart';
import 'calendar_booking_card.dart';
import 'calendar_lesson_block.dart';
import 'calendar_request_details.dart';
import 'calendar_search_fade.dart';
import 'person_avatar.dart';


const String kAddActivityLabel = 'AGGIUNGI ATTIVITÀ';

const double _addHeight = 46;
const double _denseAddHeight = 32;

// Blocks stand side by side once each can be this wide.
const double _leastColumnWidth = 300;
const double _blockGap = 14;

int openBookingCount(List<PresenceBookingGroup> groups)
{
  return groups
      .expand((group) => group.bookings)
      .where((entry) => !entry.isFullyCovered)
      .length;
}

int openPanelCount(List<PresenceBookingGroup> groups, List<ActivityItem> activities)
{
  return openBookingCount(groups) + activities.length;
}

enum BookingPanelShape
{
  // Over the track, moved and sized by hand.
  floating,

  // Whole narrow screen, no track, cards open with a tap.
  page,
}

class _CloseButton extends StatefulWidget
{
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
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
            shape: BoxShape.circle,
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.trialTealDeep),
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
              DescenderRoom(
                child: Text(
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
              ),
              const SizedBox(height: 2),
              DescenderRoom(
                child: Text(
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
  final PresenceItem presence;

  const _PresenceBand({required this.presence});

  @override
  Widget build(BuildContext context)
  {
    final accent = lessonAccent(presence.mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: lessonSurface(presence.mode),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(lessonModeIcon(presence.mode), size: 14, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              modeLabel(presence.mode).toUpperCase(),
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
            formatTimeRange(presence.startTime, presence.endTime),
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

  // Floating shape only: shuts it.
  final VoidCallback? onClose;

  final void Function(SchedulableBooking entry)? onPlanRequested;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  final ValueListenable<CarriedPlacement>? carriedAt;

  // Absent when the band cannot be edited: published, or locked by another editor.
  final VoidCallback? onAddActivity;

  final void Function(ActivityItem activity)? onOpenActivity;

  // A card held still under the pointer opens these.
  final WidgetBuilder Function(SchedulableBooking entry)? requestDetails;

  // Requests the search finds light up, the rest steps back.
  final ValueListenable<CalendarSearch?>? search;

  const CalendarBookingPanel({
    super.key,
    required this.groups,
    required this.ministrySubjects,
    this.activities = const [],
    this.teacherNames = const {},
    required this.shape,
    this.onClose,
    this.onPlanRequested,
    this.onDragChanged,
    this.carriedAt,
    this.onAddActivity,
    this.onOpenActivity,
    this.requestDetails,
    this.search,
  });

  BookingDragMode get _dragMode
  {
    return switch (shape)
    {
      BookingPanelShape.floating => BookingDragMode.immediate,
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
        filtered.add(PresenceBookingGroup(presences: group.presences, bookings: open));
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

    return 'Tutte le lezioni sono pianificate.';
  }

  // [add] sits by the close when the panel is wide: short and docked at the bottom, it leaves the cards their height.
  Widget _buildHeader({Widget? add})
  {
    final close = onClose;

    final Widget heading = PageHeading(
      'Da pianificare',
      count: _openCount,
      trailing: add == null && close == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?add,
                if (add != null && close != null) const SizedBox(width: 12),
                if (close != null) _CloseButton(onTap: close),
              ],
            ),
    );

    if (shape != BookingPanelShape.floating)
    {
      return heading;
    }

    return AppFloatingGrip(
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded, size: 18, color: AppTheme.trialMutedText),
          Expanded(child: heading),
        ],
      ),
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
    final Widget card = CalendarBookingCard(
      entry: entry,
      ministrySubjects: ministrySubjects,
      teacherNames: teacherNames,
      dragMode: _dragMode,
      onPlanRequested: onPlanRequested == null ? null : () => onPlanRequested!(entry),
      onDragChanged: onDragChanged,
      carriedAt: carriedAt,
      search: search,
    );

    final details = requestDetails;

    return details == null ? card : CalendarDetailsHover(details: details(entry), child: card);
  }

  // Not placed yet, so nobody's: the search never finds one.
  Widget _buildActivityCard(ActivityItem activity)
  {
    return CalendarSearchFade(
      search: search,
      finds: (_) => false,
      child: CalendarActivityCard(
        activity: activity,
        dragMode: _dragMode,
        onOpen: onOpenActivity == null ? null : () => onOpenActivity!(activity),
        onDragChanged: onDragChanged,
        carriedAt: carriedAt,
      ),
    );
  }

  List<Widget> _buildActivityCards(int columns)
  {
    if (activities.isEmpty)
    {
      return const [];
    }

    return [
      const PageHeading('Attività'),
      _Columns(
        count: columns,
        children: [for (final activity in activities) _buildActivityCard(activity)],
      ),
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

    return AppGradientButton(
      label: kAddActivityLabel,
      icon: Icons.add_rounded,
      height: height,
      fontSize: dense ? 11 : 13,
      radius: height / 2,
      horizontalPadding: dense ? 16 : 30,
      onPressed: add,
    );
  }

  Widget _buildStudentBlock(StudentBookingGroup student)
  {
    // The pupil's name and hours step back with the last of their requests.
    Widget faded(Widget child) => CalendarSearchFade(
          search: search,
          finds: (found) => student.presences.any((group) => group.bookings.any(found.findsBooking)),
          child: child,
        );

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
          faded(_StudentHeader(student: student)),
          for (final group in student.presences) ...[
            const SizedBox(height: 12),
            for (final (i, presence) in group.presences.indexed) ...[
              if (i > 0) const SizedBox(height: 4),
              faded(_PresenceBand(presence: presence)),
            ],
            for (final entry in group.bookings) ...[
              const SizedBox(height: 8),
              _buildCard(entry),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildList(int columns)
  {
    final visible = _visibleStudents;

    final rows = <Widget>[
      if (visible.isNotEmpty)
        _Columns(
          count: columns,
          children: [for (final student in visible) _buildStudentBlock(student)],
        ),
      ..._buildActivityCards(columns),
    ];

    if (rows.isEmpty)
    {
      return ScrollEdgeFade(child: SingleChildScrollView(child: _buildEmpty()));
    }

    return CalendarSearchReveal(
      search: search,
      child: ScrollEdgeFade(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) const SizedBox(height: _blockGap),
                row,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumn({bool showTitle = true})
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final int columns = math.max(
          1,
          ((constraints.maxWidth + _blockGap) / (_leastColumnWidth + _blockGap)).floor(),
        );

        final bool addAbove = showTitle && columns > 1;
        final Widget? add = _buildAddActivity(dense: addAbove);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle) ...[
              _buildHeader(add: addAbove ? add : null),
              const SizedBox(height: kPageHeadingGap),
            ],
            Expanded(child: _buildList(columns)),
            if (!addAbove && add != null) ...[
              const SizedBox(height: 16),
              Center(child: add),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return switch (shape)
    {
      BookingPanelShape.floating => _buildColumn(),
      BookingPanelShape.page => _buildColumn(showTitle: false),
    };
  }
}

// Each block goes under the shortest column, so blocks of any height pack without holes.
// Changing the count moves no child to another parent: a card being dragged keeps its drag.
class _Columns extends MultiChildRenderObjectWidget
{
  final int count;

  const _Columns({required this.count, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderColumns(count);

  @override
  void updateRenderObject(BuildContext context, _RenderColumns renderObject) => renderObject.count = count;
}

class _ColumnsParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderColumns extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ColumnsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ColumnsParentData>
{
  int _count;

  _RenderColumns(this._count);

  set count(int value)
  {
    if (value != _count)
    {
      _count = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child)
  {
    if (child.parentData is! _ColumnsParentData)
    {
      child.parentData = _ColumnsParentData();
    }
  }

  Size _place(BoxConstraints constraints, {required bool dry})
  {
    final double width = constraints.maxWidth;
    final double column = (width - _blockGap * (_count - 1)) / _count;
    final List<double> heights = List.filled(_count, 0);
    final BoxConstraints tight = BoxConstraints.tightFor(width: column);

    for (RenderBox? child = firstChild; child != null; child = childAfter(child))
    {
      int shortest = 0;

      for (int i = 1; i < _count; i++)
      {
        if (heights[i] < heights[shortest] - precisionErrorTolerance)
        {
          shortest = i;
        }
      }

      final double height;

      if (dry)
      {
        height = child.getDryLayout(tight).height;
      }
      else
      {
        child.layout(tight, parentUsesSize: true);
        height = child.size.height;
        (child.parentData! as _ColumnsParentData).offset = Offset(shortest * (column + _blockGap), heights[shortest]);
      }

      heights[shortest] += height + _blockGap;
    }

    final double tallest = heights.reduce(math.max);

    return constraints.constrain(Size(width, math.max(0, tallest - _blockGap)));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _place(constraints, dry: true);

  @override
  void performLayout()
  {
    size = _place(constraints, dry: false);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position})
  {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
