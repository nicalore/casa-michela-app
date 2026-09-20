import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../people/models/person_item.dart';
import '../../lessons/models/booking_summary_item.dart';
import '../../lessons/models/presence_group.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/booking_fields_section.dart' show bookingTagLabels;

const double _radius = 24;
const EdgeInsets _padding = EdgeInsets.fromLTRB(26, 24, 26, 24);

const double _rimWidth = 2.5;

const double _pastOpacity = 0.55;

const double _dateWidth = 180;
const double _columnGap = 24;

const double _dividerGap = 18;

// Below these, lesson columns fold under the name, then the shut-day notice goes under the date.
const double _oneLineFrom = 1420;
const double _noticeBesideFrom = 700;
const double _stackedGap = 18;

const double _buttonHeight = 40;
const double _buttonFontSize = 12.5;
const double _buttonGap = 10;

const double _subjectWidth = 250;
const double _durationWidth = 66;
const double _gridGap = 14;
const double _rowGap = 8;

const EdgeInsets _rowPadding = EdgeInsets.fromLTRB(14, 10, 12, 10);
const double _rowRadius = 16;

const double _disciplinesFontSize = 14;
const double _disciplinesLineHeight = 1.35;
const double _disciplinesGap = 2;

const double _actionSize = 30;
const double _actionIconSize = 21;
const double _actionGap = 4;

// Two marks plus pencil, move and bin.
const double _trailingWidth = 2 * (_markSize + 2) + 3 * _actionSize + 2 * 2 + _actionGap;

const Duration _hoverFade = Duration(milliseconds: 150);

const double _chipHeight = 26;
const double _modeHeadingHeight = 16;

const double _laneHeaderHeight = 40;
const double _laneGap = 16;
const double _laneInnerGap = 12;

const double _modeRowGap = 8;
const double _modeGap = 18;

const double _markSize = 30;
const double _markIconSize = 21;

const double _tooltipMaxWidth = 380;

const List<String> _modes = [kPresenceMode, kOnlineMode];

class BookingLane
{
  final PersonItem pupil;
  final PresenceGroup? group;

  const BookingLane({required this.pupil, this.group});
}

class BookingDayRow extends StatefulWidget
{
  final DateTime day;

  final bool isToday;
  final bool isPast;

  // Never empty.
  final List<BookingLane> lanes;

  final List<OpeningDayItem> openingDays;

  final DateTime now;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final bool readOnly;

  final void Function(BookingLane lane, String mode) onAdd;
  final void Function(BookingLane lane, String mode) onEditHours;
  final void Function(BookingLane lane, String mode) onAddLesson;

  final void Function(BookingLane lane, BookingSummaryItem booking) onEditLesson;

  final bool Function(BookingLane lane, BookingSummaryItem booking) canMoveLesson;
  final void Function(BookingLane lane, BookingSummaryItem booking) onMoveLesson;

  final void Function(BookingLane lane, BookingSummaryItem booking) onDeleteLesson;

  // Null when the block can move; otherwise the reason shown on the disabled button.
  final String? Function(BookingLane lane, String mode) blockMoveRefusal;
  final void Function(BookingLane lane, String mode) onMoveBlock;

  final void Function(BookingLane lane, String mode) onDeleteMode;
  final ValueChanged<BookingLane> onDeleteDay;

  const BookingDayRow({
    super.key,
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.lanes,
    required this.openingDays,
    required this.now,
    required this.ministrySubjects,
    required this.teachers,
    this.readOnly = false,
    required this.onAdd,
    required this.onEditHours,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.canMoveLesson,
    required this.onMoveLesson,
    required this.onDeleteLesson,
    required this.blockMoveRefusal,
    required this.onMoveBlock,
    required this.onDeleteMode,
    required this.onDeleteDay,
  });

  @override
  State<BookingDayRow> createState() => _BookingDayRowState();
}

class _BookingDayRowState extends State<BookingDayRow>
{
  bool _hover = false;

  List<BookingLane> get _lanes => widget.lanes;

  bool get _named => _lanes.length > 1;

  bool _isOpenIn(TimeBucket bucket) => unionOpeningWindow(widget.openingDays, widget.day, bucket) != null;

  bool _hasClosed(TimeBucket bucket) => haveBookingsClosed(widget.day, bucket, widget.now);

  bool get _isShut => !TimeBucket.values.any(_isOpenIn);

  bool _isOpenFor(String mode)
  {
    return !widget.readOnly &&
        TimeBucket.values.any((bucket) =>
            !_hasClosed(bucket) && openingWindowFor(widget.openingDays, widget.day, mode, bucket) != null);
  }

  List<String> _addableModes(BookingLane lane)
  {
    return [
      for (final mode in _modes)
        if (_isOpenFor(mode) && (lane.group?.slotsFor(mode).isEmpty ?? true)) mode,
    ];
  }

  bool get _isEmpty => _lanes.every((lane) => lane.group == null);

  bool _slotClosed(PresenceItem slot)
  {
    final TimeBucket? bucket = bucketFor(slot.startTime);

    return bucket != null && haveBookingsClosed(widget.day, bucket, widget.now);
  }

  bool _canDeleteDay(BookingLane lane)
  {
    final PresenceGroup? group = lane.group;

    return !widget.readOnly && group != null && !group.slots.any(_slotClosed);
  }

  Widget _buildDate()
  {
    final bool lone = !_named && !(_isShut && _isEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEyebrow(weekdayFullName(widget.day.weekday)),
            if (widget.isToday) ...[
              const SizedBox(width: 8),
              const _TodayPill(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                formatDayMonthFull(widget.day),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: widget.isPast || _isShut ? AppTheme.trialMutedText : AppTheme.trialOcean,
                ),
              ),
            ),
            if (lone && _canDeleteDay(_lanes.single)) ...[
              const SizedBox(width: _actionGap),
              _HoverAction(
                visible: _hover,
                icon: Icons.delete_outline_rounded,
                color: AppTheme.trialDanger,
                tooltip: 'Elimina la giornata',
                onTap: () => widget.onDeleteDay(_lanes.single),
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<Widget> _buildAddButtons(BookingLane lane)
  {
    return [
      for (final mode in _addableModes(lane))
        AppGradientButton(
          label: mode == kOnlineMode ? 'AGGIUNGI ONLINE' : 'AGGIUNGI IN PRESENZA',
          icon: Icons.add_rounded,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          radius: _buttonHeight / 2,
          horizontalPadding: 18,
          onPressed: () => widget.onAdd(lane, mode),
        ),
    ];
  }

  Widget _buildLane(BookingLane lane, {required bool folded})
  {
    return _LaneView(
      lane: lane,
      folded: folded,
      named: _named,
      ministrySubjects: widget.ministrySubjects,
      teachers: widget.teachers,
      readOnly: widget.readOnly,
      addButtons: _buildAddButtons(lane),
      slotClosed: _slotClosed,
      modeOpen: _isOpenFor,
      canDeleteDay: _canDeleteDay(lane),
      onDeleteDay: () => widget.onDeleteDay(lane),
      onEditHours: (mode) => widget.onEditHours(lane, mode),
      onAddLesson: (mode) => widget.onAddLesson(lane, mode),
      onDeleteMode: (mode) => widget.onDeleteMode(lane, mode),
      onEditLesson: (booking) => widget.onEditLesson(lane, booking),
      canMoveLesson: (booking) => widget.canMoveLesson(lane, booking),
      onMoveLesson: (booking) => widget.onMoveLesson(lane, booking),
      onDeleteLesson: (booking) => widget.onDeleteLesson(lane, booking),
      blockMoveRefusal: (mode) => widget.blockMoveRefusal(lane, mode),
      onMoveBlock: (mode) => widget.onMoveBlock(lane, mode),
    );
  }

  Widget _buildLanes({required bool folded})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lane in _lanes) ...[
          if (lane != _lanes.first) ...[
            const SizedBox(height: _laneGap),
            Container(height: 1, color: AppTheme.trialLine),
            const SizedBox(height: _laneGap),
          ],
          _buildLane(lane, folded: folded),
        ],
      ],
    );
  }

  Color get _lineColor => _isShut && _isEmpty ? AppTheme.closedLine : AppTheme.trialLine;

  Widget _buildShutNotice()
  {
    return Row(
      children: [
        const Icon(Icons.event_busy_rounded, size: 20, color: AppTheme.trialMutedText),
        const SizedBox(width: 10),
        const Expanded(child: _Muted("L'Associazione è chiusa")),
      ],
    );
  }

  Widget _buildOneLine()
  {
    final bool shut = _isShut && _isEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _dateWidth,
            child: Align(alignment: Alignment.centerLeft, child: _buildDate()),
          ),
          _Divider(color: _lineColor),
          if (shut)
            Expanded(child: _buildShutNotice())
          else
            Expanded(child: _buildLanes(folded: false)),
        ],
      ),
    );
  }

  Widget _buildRule()
  {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: _stackedGap),
      color: _lineColor,
    );
  }

  Widget _buildStacked({required bool noticeBeside})
  {
    if (_isShut && _isEmpty)
    {
      if (noticeBeside)
      {
        return _buildOneLine();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDate(),
          _buildRule(),
          _buildShutNotice(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDate(),
        _buildRule(),
        _buildLanes(folded: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool shut = _isShut && _isEmpty;

    Widget content = LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;

        if (width >= _oneLineFrom)
        {
          return _buildOneLine();
        }

        return _buildStacked(noticeBeside: width >= _noticeBesideFrom);
      },
    );

    if (widget.isPast)
    {
      content = Opacity(opacity: _pastOpacity, child: content);
    }

    final Widget card = Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: shut ? AppTheme.closedSurface : Colors.white,
        borderRadius: BorderRadius.circular(_radius - _rimWidth),
      ),
      child: content,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.all(_rimWidth),
        decoration: BoxDecoration(
          gradient: widget.isToday ? AppTheme.greetingGradient : null,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: shut ? null : AppTheme.cardShadow,
        ),
        child: card,
      ),
    );
  }
}

class _Divider extends StatelessWidget
{
  final Color color;

  const _Divider({this.color = AppTheme.trialLine});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: _dividerGap),
      color: color,
    );
  }
}

class _LaneView extends StatefulWidget
{
  final BookingLane lane;

  final bool folded;

  final bool named;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final bool readOnly;

  final List<Widget> addButtons;

  final bool Function(PresenceItem slot) slotClosed;
  final bool Function(String mode) modeOpen;

  final bool canDeleteDay;

  final VoidCallback onDeleteDay;
  final ValueChanged<String> onEditHours;
  final ValueChanged<String> onAddLesson;
  final ValueChanged<String> onDeleteMode;
  final ValueChanged<BookingSummaryItem> onEditLesson;
  final bool Function(BookingSummaryItem booking) canMoveLesson;
  final ValueChanged<BookingSummaryItem> onMoveLesson;
  final ValueChanged<BookingSummaryItem> onDeleteLesson;
  final String? Function(String mode) blockMoveRefusal;
  final ValueChanged<String> onMoveBlock;

  const _LaneView({
    required this.lane,
    required this.folded,
    required this.named,
    required this.ministrySubjects,
    required this.teachers,
    required this.readOnly,
    required this.addButtons,
    required this.slotClosed,
    required this.modeOpen,
    required this.canDeleteDay,
    required this.onDeleteDay,
    required this.onEditHours,
    required this.onAddLesson,
    required this.onDeleteMode,
    required this.onEditLesson,
    required this.canMoveLesson,
    required this.onMoveLesson,
    required this.onDeleteLesson,
    required this.blockMoveRefusal,
    required this.onMoveBlock,
  });

  @override
  State<_LaneView> createState() => _LaneViewState();
}

class _LaneViewState extends State<_LaneView>
{
  bool _hover = false;

  Widget _buildHeader()
  {
    return SizedBox(
      height: _laneHeaderHeight,
      child: Row(
        children: [
          Expanded(
            child: !widget.named
                ? (widget.lane.group == null
                    ? const Align(alignment: Alignment.centerLeft, child: _Muted('Nessuna prenotazione'))
                    : const SizedBox.shrink())
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.lane.pupil.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppTheme.trialOcean,
                          ),
                        ),
                      ),
                      if (widget.canDeleteDay) ...[
                        const SizedBox(width: _actionGap),
                        _HoverAction(
                          visible: _hover,
                          icon: Icons.delete_outline_rounded,
                          color: AppTheme.trialDanger,
                          tooltip: 'Elimina la giornata',
                          onTap: widget.onDeleteDay,
                        ),
                      ],
                    ],
                  ),
          ),
          for (final button in widget.addButtons) ...[
            SizedBox(width: button == widget.addButtons.first ? _columnGap : _buttonGap),
            button,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final PresenceGroup? group = widget.lane.group;

    final List<String> booked = [
      if (group != null)
        for (final mode in _modes)
          if (group.slotsFor(mode).isNotEmpty) mode,
    ];

    final bool headed = widget.named || widget.addButtons.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headed) ...[
            _buildHeader(),
            if (group != null || widget.named) const SizedBox(height: _laneInnerGap),
          ],
          if (group == null)
            (headed && !widget.named ? const SizedBox.shrink() : const _Muted('Nessuna prenotazione'))
          else
            for (final mode in booked) ...[
              if (mode != booked.first) const SizedBox(height: _modeGap),
              _ModeBlock(
                mode: mode,
                group: group,
                folded: widget.folded,
                ministrySubjects: widget.ministrySubjects,
                teachers: widget.teachers,
                readOnly: widget.readOnly,
                slotClosed: widget.slotClosed,
                canChange: widget.modeOpen(mode),
                onEditHours: () => widget.onEditHours(mode),
                onAddLesson: () => widget.onAddLesson(mode),
                onDelete: () => widget.onDeleteMode(mode),
                onEditLesson: widget.onEditLesson,
                canMoveLesson: widget.canMoveLesson,
                onMoveLesson: widget.onMoveLesson,
                onDeleteLesson: widget.onDeleteLesson,
                blockMoveRefusal: widget.blockMoveRefusal(mode),
                onMoveBlock: () => widget.onMoveBlock(mode),
              ),
            ],
        ],
      ),
    );
  }
}

class _ModeBlock extends StatefulWidget
{
  final String mode;
  final PresenceGroup group;

  final bool folded;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final bool readOnly;

  final bool Function(PresenceItem slot) slotClosed;

  final bool canChange;

  final VoidCallback onEditHours;
  final VoidCallback onAddLesson;
  final VoidCallback onDelete;
  final ValueChanged<BookingSummaryItem> onEditLesson;
  final bool Function(BookingSummaryItem booking) canMoveLesson;
  final ValueChanged<BookingSummaryItem> onMoveLesson;
  final ValueChanged<BookingSummaryItem> onDeleteLesson;

  final String? blockMoveRefusal;
  final VoidCallback onMoveBlock;

  const _ModeBlock({
    required this.mode,
    required this.group,
    required this.folded,
    required this.ministrySubjects,
    required this.teachers,
    required this.readOnly,
    required this.slotClosed,
    required this.canChange,
    required this.onEditHours,
    required this.onAddLesson,
    required this.onDelete,
    required this.onEditLesson,
    required this.canMoveLesson,
    required this.onMoveLesson,
    required this.onDeleteLesson,
    required this.blockMoveRefusal,
    required this.onMoveBlock,
  });

  @override
  State<_ModeBlock> createState() => _ModeBlockState();
}

class _ModeBlockState extends State<_ModeBlock>
{
  bool _hover = false;

  String get _mode => widget.mode;

  bool get _online => _mode == kOnlineMode;

  List<PresenceItem> get _slots => widget.group.slotsFor(_mode);

  bool get _hasClosed => _slots.any(widget.slotClosed);

  bool get _deletable => !widget.readOnly && !_hasClosed;

  PresenceItem? _slotOf(BookingSummaryItem booking)
  {
    for (final slot in _slots)
    {
      if (slot.bookings.any((row) => row.id == booking.id))
      {
        return slot;
      }
    }

    return null;
  }

  bool _isClosed(BookingSummaryItem booking)
  {
    final PresenceItem? slot = _slotOf(booking);

    return slot == null || widget.slotClosed(slot);
  }

  bool _isEditable(BookingSummaryItem booking) => !widget.readOnly && !_isClosed(booking);

  bool _isMovable(BookingSummaryItem booking)
  {
    return _isEditable(booking) && widget.canMoveLesson(booking);
  }

  Widget _buildHeading()
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _online ? Icons.videocam_outlined : Icons.home_work_outlined,
          size: _modeHeadingHeight,
          color: AppTheme.trialMutedText,
        ),
        const SizedBox(width: 5),
        Text(
          modeLabel(_mode).toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
        if (_hasClosed) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'Prenotazioni chiuse',
            child: Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.trialMutedText),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions()
  {
    return [
      if (widget.canChange) ...[
        _HoverAction(
          visible: _hover,
          icon: Icons.edit_outlined,
          color: AppTheme.trialTealDeep,
          tooltip: 'Modifica gli orari',
          onTap: widget.onEditHours,
        ),
        const SizedBox(width: 2),
        _HoverAction(
          visible: _hover,
          icon: Icons.add_rounded,
          color: AppTheme.trialTealDeep,
          tooltip: 'Aggiungi una lezione',
          onTap: widget.onAddLesson,
        ),
        if (widget.group.requestsFor(_mode).isNotEmpty) ...[
          const SizedBox(width: 2),
          _HoverAction(
            visible: _hover,
            icon: Icons.swap_horiz_rounded,
            color: AppTheme.trialTealDeep,
            tooltip: 'Sposta tutte le lezioni',
            disabledReason: widget.blockMoveRefusal,
            onTap: widget.onMoveBlock,
          ),
        ],
      ],
      if (_deletable) ...[
        if (widget.canChange) const SizedBox(width: 2),
        _HoverAction(
          visible: _hover,
          icon: Icons.delete_outline_rounded,
          color: AppTheme.trialDanger,
          tooltip: 'Elimina la prenotazione ${_online ? kOnScreen : kInBuilding}',
          onTap: widget.onDelete,
        ),
      ],
    ];
  }

  Widget _buildChips()
  {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final slot in _slots)
          _HoursChip(slot: slot, locked: widget.slotClosed(slot)),
      ],
    );
  }

  Widget _buildModeRow()
  {
    final List<Widget> actions = _buildActions();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildHeading(),
        _buildChips(),
        if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    );
  }

  List<Widget> _buildRows()
  {
    final List<BookingSummaryItem> lessons = widget.group.requestsFor(_mode);

    return [
      for (final booking in lessons) ...[
        if (booking != lessons.first) const SizedBox(height: _rowGap),
        _LessonRow(
          booking: booking,
          folded: widget.folded,
          closed: _isClosed(booking),
          editable: _isEditable(booking),
          movable: _isMovable(booking),
          ministrySubjects: widget.ministrySubjects,
          teachers: widget.teachers,
          onEdit: () => widget.onEditLesson(booking),
          onMove: () => widget.onMoveLesson(booking),
          onDelete: () => widget.onDeleteLesson(booking),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeRow(),
          const SizedBox(height: _modeRowGap),
          ..._buildRows(),
        ],
      ),
    );
  }
}

class _HoursChip extends StatelessWidget
{
  final PresenceItem slot;
  final bool locked;

  const _HoursChip({required this.slot, required this.locked});

  @override
  Widget build(BuildContext context)
  {
    final bool online = slot.mode == kOnlineMode;

    final Color surface = locked
        ? Colors.white
        : (online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface);
    final Color ink = locked
        ? AppTheme.trialMutedText
        : (online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep);

    return Container(
      height: _chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_chipHeight / 2),
        border: locked ? Border.all(color: AppTheme.closedLine, width: 1.5) : null,
      ),
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: Text(
          formatTimeRange(slot.startTime, slot.endTime),
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: ink,
          ),
        ),
      ),
    );
  }
}

class _LessonRow extends StatefulWidget
{
  final BookingSummaryItem booking;
  final bool folded;

  final bool closed;
  final bool editable;
  final bool movable;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _LessonRow({
    required this.booking,
    required this.folded,
    required this.closed,
    required this.editable,
    required this.movable,
    required this.ministrySubjects,
    required this.teachers,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
  });

  @override
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow>
{
  bool _hover = false;

  BookingSummaryItem get _booking => widget.booking;

  String get _title => bookingTitle(_booking, widget.ministrySubjects);

  // A subject with a single discipline would only repeat its own name.
  List<String> get _disciplines
  {
    if (_booking.kind != BookingRequestKind.ministrySubject)
    {
      return const [];
    }

    for (final subject in widget.ministrySubjects)
    {
      if (subject.id == _booking.ministrySubjectId && subject.associationSubjects.length <= 1)
      {
        return const [];
      }
    }

    return [for (final subject in _booking.associationSubjects) subject.name];
  }

  List<PersonItem> get _preferredTeachers
  {
    return [
      for (final taxCode in _booking.preferredTeacherTaxCodes)
        for (final teacher in widget.teachers)
          if (teacher.fiscalCode == taxCode) teacher,
    ];
  }

  Widget _buildName()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: AppTheme.trialOcean,
          ),
        ),
        if (_disciplines.isEmpty)
          const SizedBox(height: _disciplinesGap + _disciplinesFontSize * _disciplinesLineHeight)
        else ...[
          const SizedBox(height: _disciplinesGap),
          Text(
            _disciplines.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _disciplinesFontSize,
              fontWeight: FontWeight.w600,
              height: _disciplinesLineHeight,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDuration()
  {
    return Text(
      formatMinutes(_booking.duration),
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppTheme.trialInk,
      ),
    );
  }

  Widget _buildTags()
  {
    final List<String> labels = bookingTagLabels(_booking.tags);

    if (labels.isEmpty)
    {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [for (final label in labels) _Tag(label)],
    );
  }

  Widget _buildTeachers()
  {
    final List<PersonItem> chosen = _preferredTeachers;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.thumb_up_outlined, size: 18, color: AppTheme.trialMutedText),
        ),
        const SizedBox(width: 8),
        if (chosen.isEmpty)
          const Expanded(child: _Muted('Nessuna preferenza'))
        else
          Expanded(
            child: Text(
              chosen.map((teacher) => '${teacher.firstName} ${teacher.lastName}').join(', '),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppTheme.trialInk,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrailing()
  {
    final bool shown = _hover && widget.editable;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _Mark(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Argomento',
          text: _booking.topic,
          muted: widget.closed,
        ),
        const SizedBox(width: 2),
        _Mark(
          icon: Icons.sticky_note_2_outlined,
          label: 'Note per il docente',
          text: _booking.notes,
          muted: widget.closed,
        ),
        const SizedBox(width: _actionGap),
        _HoverAction(
          visible: shown,
          icon: Icons.edit_outlined,
          color: AppTheme.trialTealDeep,
          tooltip: 'Modifica la lezione',
          onTap: widget.onEdit,
        ),
        if (widget.movable) ...[
          const SizedBox(width: 2),
          _HoverAction(
            visible: shown,
            icon: Icons.swap_horiz_rounded,
            color: AppTheme.trialTealDeep,
            tooltip: 'Sposta la lezione',
            onTap: widget.onMove,
          ),
        ],
        const SizedBox(width: 2),
        _HoverAction(
          visible: shown,
          icon: Icons.delete_outline_rounded,
          color: AppTheme.trialDanger,
          tooltip: 'Elimina la lezione',
          onTap: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildWide()
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _subjectWidth, child: _buildName()),
        const SizedBox(width: _gridGap),
        SizedBox(
          width: _durationWidth,
          child: Padding(padding: const EdgeInsets.only(top: 1), child: _buildDuration()),
        ),
        const SizedBox(width: _gridGap),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 1), child: _buildTags())),
        const SizedBox(width: _gridGap),
        Expanded(child: _buildTeachers()),
        const SizedBox(width: _gridGap),
        SizedBox(width: _trailingWidth, child: _buildTrailing()),
      ],
    );
  }

  Widget _buildFolded()
  {
    final bool tagged = _booking.tags.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildName()),
                  const SizedBox(width: 10),
                  Padding(padding: const EdgeInsets.only(top: 1), child: _buildDuration()),
                ],
              ),
              if (tagged) ...[
                const SizedBox(height: 7),
                _buildTags(),
              ],
              const SizedBox(height: 7),
              _buildTeachers(),
            ],
          ),
        ),
        const SizedBox(width: _gridGap),
        SizedBox(width: _trailingWidth, child: _buildTrailing()),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: _rowPadding,
        decoration: BoxDecoration(
          color: AppTheme.trialPaper,
          borderRadius: BorderRadius.circular(_rowRadius),
        ),
        child: widget.folded ? _buildFolded() : _buildWide(),
      ),
    );
  }
}

// Keeps its size while hidden so nothing shifts on hover.
class _HoverAction extends StatefulWidget
{
  final bool visible;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  final String? disabledReason;

  const _HoverAction({
    required this.visible,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.disabledReason,
  });

  @override
  State<_HoverAction> createState() => _HoverActionState();
}

class _HoverActionState extends State<_HoverAction>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final String? reason = widget.disabledReason;

    final Widget face = SizedBox(
      width: _actionSize,
      height: _actionSize,
      child: Icon(
        widget.icon,
        size: _actionIconSize,
        color: reason == null ? widget.color : AppTheme.trialMutedText.withValues(alpha: 0.5),
      ),
    );

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: _hoverFade,
        child: Tooltip(
          message: reason ?? widget.tooltip,
          child: reason != null
              ? face
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hover = true),
                  onExit: (_) => setState(() => _hover = false),
                  child: GestureDetector(
                    onTap: widget.onTap,
                    child: AnimatedContainer(
                      duration: _hoverFade,
                      decoration: BoxDecoration(
                        color: _hover ? AppTheme.trialGoldSurface : AppTheme.trialGoldSurface.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: face,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget
{
  final String label;

  const _Tag(this.label);

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.trialMutedText.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }
}

// Keeps its size when empty so rows keep their width.
class _Mark extends StatelessWidget
{
  final IconData icon;
  final String label;
  final String? text;

  final bool muted;

  const _Mark({required this.icon, required this.label, required this.text, required this.muted});

  @override
  Widget build(BuildContext context)
  {
    final String? said = text?.trim();

    if (said == null || said.isEmpty)
    {
      return const SizedBox(width: _markSize, height: _markSize);
    }

    final Widget face = SizedBox(
      width: _markSize,
      height: _markSize,
      child: Icon(
        icon,
        size: _markIconSize,
        color: muted ? AppTheme.trialMutedText.withValues(alpha: 0.5) : AppTheme.trialTealDeep,
      ),
    );

    return Tooltip(
      constraints: const BoxConstraints(maxWidth: _tooltipMaxWidth),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${label.toUpperCase()}\n',
            style: AppTheme.tooltipTextStyle.copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          TextSpan(text: said, style: AppTheme.tooltipTextStyle),
        ],
      ),
      child: face,
    );
  }
}

class _Muted extends StatelessWidget
{
  final String text;

  const _Muted(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        height: 1.35,
        color: AppTheme.trialMutedText,
      ),
    );
  }
}

class _TodayPill extends StatelessWidget
{
  const _TodayPill();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.trialTealDeep.withValues(alpha: 0.28)),
      ),
      child: Text(
        'OGGI',
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
