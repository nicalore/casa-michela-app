import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_density.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../people/models/person_item.dart';
import '../../lessons/models/booking_summary_item.dart';
import '../../lessons/models/presence_group.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/booking_fields_section.dart' show bookingTagLabels;
import '../../lessons/widgets/calendar_lesson_block.dart' show lessonModeIcon;
import '../bookings_tour.dart';
import '../utils/booking_strings.dart' show deleteBand, moveBandLessons;

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

const double _subjectWidth = 320;
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

// Below the wide window: a smaller card, the date beside the pupils while they have room, a lesson on one line.
const double _denseRadius = 20;
const EdgeInsets _densePadding = EdgeInsets.fromLTRB(16, 14, 16, 14);
const double _denseRimWidth = 2;
const double _denseDateWidth = 128;
const double _denseGap = 18;
const double _denseOneLineFrom = 640;
const double _denseLessonOneLineFrom = 540;

// Name, «Nessuna prenotazione» and both add buttons need about this much of a pupil's line.
const double _denseButtonsBesideFrom = 680;

// The pupils' names make a column as wide as the longest of the day, up to this.
const double _denseNameMaxWidth = 160;
const double _denseNameGap = 10;

TextStyle get _denseNameStyle => GoogleFonts.plusJakartaSans(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  height: 1.2,
  color: AppTheme.trialOcean,
);

const double _denseButtonHeight = 36;
const double _denseButtonGap = 8;

const double _denseLaneHeaderHeight = 36;
const double _denseLaneGap = 10;
const double _denseLaneInnerGap = 6;
const double _denseModeGap = 10;
const double _denseModeRowGap = 5;
const double _denseRowGap = 5;

const EdgeInsets _denseRowPadding = EdgeInsets.fromLTRB(12, 7, 6, 7);
const double _denseRowRadius = 12;
const double _denseDurationWidth = 58;

const double _denseChipHeight = 22;
const double _denseActionSize = 28;
const double _denseActionIconSize = 19;
const double _denseMarkSize = 28;
const double _denseMarkIconSize = 18;
const double _denseTrailingWidth = 2 * (_denseMarkSize + 2) + 3 * _denseActionSize + 2 * 2 + _actionGap;
const double _denseMarksWidth = 2 * _denseMarkSize + 2;

class BookingLane
{
  final PersonItem pupil;
  final PresenceGroup? group;

  const BookingLane({required this.pupil, this.group});
}

// A band of a pupil's day, by the pupil's tax code.
typedef BookingTourBlock = (String pupil, String mode, TimeBucket band);

// Where a day row lights each mark of the tour: the first lane, band or lesson showing it.
class BookingsTourPlaces
{
  final String? add;
  final BookingTourBlock? lock;
  final List<BookingTourBlock> modes;
  final int? lesson;
  final int? topic;
  final int? notes;
  final int? lessonActions;
  final BookingTourBlock? bandActions;
  final String? dayBin;

  // Marks at their best here: both add buttons, a lesson that can still change.
  final Set<BookingsTourMark> best;

  const BookingsTourPlaces({
    this.add,
    this.lock,
    this.modes = const [],
    this.lesson,
    this.topic,
    this.notes,
    this.lessonActions,
    this.bandActions,
    this.dayBin,
    this.best = const {},
  });

  Set<BookingsTourMark> get marks => {
        if (add != null) BookingsTourMark.add,
        if (lock != null) BookingsTourMark.lock,
        if (modes.isNotEmpty) BookingsTourMark.modes,
        if (lesson != null) BookingsTourMark.lesson,
        if (topic != null) BookingsTourMark.topic,
        if (notes != null) BookingsTourMark.notes,
        if (lessonActions != null) BookingsTourMark.lessonActions,
        if (bandActions != null) BookingsTourMark.bandActions,
        if (dayBin != null) BookingsTourMark.dayBin,
      };

  // Only [kept]: the page gives each mark to one day.
  BookingsTourPlaces only(Set<BookingsTourMark> kept)
  {
    return BookingsTourPlaces(
      add: kept.contains(BookingsTourMark.add) ? add : null,
      lock: kept.contains(BookingsTourMark.lock) ? lock : null,
      modes: kept.contains(BookingsTourMark.modes) ? modes : const [],
      lesson: kept.contains(BookingsTourMark.lesson) ? lesson : null,
      topic: kept.contains(BookingsTourMark.topic) ? topic : null,
      notes: kept.contains(BookingsTourMark.notes) ? notes : null,
      lessonActions: kept.contains(BookingsTourMark.lessonActions) ? lessonActions : null,
      bandActions: kept.contains(BookingsTourMark.bandActions) ? bandActions : null,
      dayBin: kept.contains(BookingsTourMark.dayBin) ? dayBin : null,
    );
  }
}

bool _said(String? text) => text != null && text.trim().isNotEmpty;

// The row's own rules, read for the tour: add buttons, locks, coloured hours, hover buttons.
BookingsTourPlaces bookingsTourPlacesOf({
  required DateTime day,
  required List<BookingLane> lanes,
  required List<OpeningDayItem> openingDays,
  required DateTime now,
  required bool readOnly,
})
{
  bool closedIn(TimeBucket band) => haveBookingsClosed(day, band, now);

  // One only looking has nothing closed to them, as the row shows it.
  bool slotClosed(PresenceItem slot)
  {
    final TimeBucket? band = bucketFor(slot.startTime);

    return !readOnly && band != null && closedIn(band);
  }

  int addable(BookingLane lane)
  {
    final PresenceGroup? group = lane.group;

    return readOnly
        ? 0
        : _modes
            .where((mode) => TimeBucket.values.any((band) =>
                !closedIn(band) &&
                openingWindowFor(openingDays, day, mode, band) != null &&
                (group == null || _modes.every((either) => group.slotsFor(either, band: band).isEmpty))))
            .length;
  }

  final List<BookingTourBlock> blocks = [
    for (final lane in lanes)
      if (lane.group case final PresenceGroup group)
        for (final mode in _modes)
          for (final band in group.bandsFor(mode)) (lane.pupil.fiscalCode, mode, band),
  ];

  PresenceGroup groupOf(BookingTourBlock block) => lanes.firstWhere((lane) => lane.pupil.fiscalCode == block.$1).group!;

  List<PresenceItem> slotsOf(BookingTourBlock block) => groupOf(block).slotsFor(block.$2, band: block.$3);

  bool locked(BookingTourBlock block) => slotsOf(block).any(slotClosed);

  bool coloured(BookingTourBlock block) => slotsOf(block).any((slot) => !slotClosed(slot));

  bool changeable(BookingTourBlock block) => !readOnly && !closedIn(block.$3);

  BookingTourBlock? firstBlock(bool Function(BookingTourBlock block) test) => blocks.where(test).firstOrNull;

  final List<(BookingTourBlock, BookingSummaryItem, bool)> lessons = [
    for (final block in blocks)
      for (final slot in slotsOf(block))
        for (final booking in slot.bookings) (block, booking, !readOnly && !slotClosed(slot)),
  ];

  final BookingTourBlock? presence = firstBlock((block) => block.$2 == kPresenceMode && coloured(block));
  final BookingTourBlock? online = firstBlock((block) => block.$2 == kOnlineMode && coloured(block));

  final String? bin = lanes
      .where((lane) => !readOnly && lane.group != null && !lane.group!.slots.any(slotClosed))
      .firstOrNull
      ?.pupil
      .fiscalCode;

  final BookingLane? both = lanes.where((lane) => addable(lane) > 1).firstOrNull;
  final (BookingTourBlock, BookingSummaryItem, bool)? changing = lessons.where((lesson) => lesson.$3).firstOrNull;

  return BookingsTourPlaces(
    add: (both ?? lanes.where((lane) => addable(lane) > 0).firstOrNull)?.pupil.fiscalCode,
    lock: firstBlock(locked),
    modes: [?presence, ?online],
    lesson: (changing ?? lessons.firstOrNull)?.$2.id,
    topic: lessons.where((lesson) => _said(lesson.$2.topic)).firstOrNull?.$2.id,
    notes: lessons.where((lesson) => _said(lesson.$2.notes)).firstOrNull?.$2.id,
    lessonActions: lessons.where((lesson) => lesson.$3).firstOrNull?.$2.id,
    bandActions: firstBlock((block) => changeable(block) || (!readOnly && !locked(block))),
    dayBin: bin,
    best: {
      if (both != null) BookingsTourMark.add,
      if (changing != null) BookingsTourMark.lesson,
      if (presence != null && online != null) BookingsTourMark.modes,
    },
  );
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

  final Set<BookingsTourMark> tourMarks;

  final void Function(BookingLane lane, String mode) onAdd;
  final void Function(BookingLane lane, String mode, TimeBucket band) onEditHours;
  final void Function(BookingLane lane, String mode, TimeBucket band) onAddLesson;

  final void Function(BookingLane lane, BookingSummaryItem booking) onEditLesson;

  final bool Function(BookingLane lane, BookingSummaryItem booking) canMoveLesson;
  final void Function(BookingLane lane, BookingSummaryItem booking) onMoveLesson;

  final void Function(BookingLane lane, BookingSummaryItem booking) onDeleteLesson;

  // Null when the block can move; otherwise the reason shown on the disabled button.
  final String? Function(BookingLane lane, String mode, TimeBucket band) blockMoveRefusal;
  final void Function(BookingLane lane, String mode, TimeBucket band) onMoveBlock;

  final void Function(BookingLane lane, String mode, TimeBucket band) onDeleteBand;
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
    this.tourMarks = const {},
    required this.onAdd,
    required this.onEditHours,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.canMoveLesson,
    required this.onMoveLesson,
    required this.onDeleteLesson,
    required this.blockMoveRefusal,
    required this.onMoveBlock,
    required this.onDeleteBand,
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

  BookingsTourPlaces get _tour
  {
    if (widget.tourMarks.isEmpty)
    {
      return const BookingsTourPlaces();
    }

    return bookingsTourPlacesOf(
      day: widget.day,
      lanes: _lanes,
      openingDays: widget.openingDays,
      now: widget.now,
      readOnly: widget.readOnly,
    ).only(widget.tourMarks);
  }

  bool _isOpenIn(TimeBucket bucket) => unionOpeningWindow(widget.openingDays, widget.day, bucket) != null;

  bool _hasClosed(TimeBucket bucket) => haveBookingsClosed(widget.day, bucket, widget.now);

  bool get _isShut => !TimeBucket.values.any(_isOpenIn);

  List<String> _addableModes(BookingLane lane)
  {
    final PresenceGroup? group = lane.group;

    bool free(String mode, TimeBucket bucket) =>
        !_hasClosed(bucket) &&
        openingWindowFor(widget.openingDays, widget.day, mode, bucket) != null &&
        (group == null || _modes.every((either) => group.slotsFor(either, band: bucket).isEmpty));

    return [
      for (final mode in _modes)
        if (!widget.readOnly && TimeBucket.values.any((bucket) => free(mode, bucket))) mode,
    ];
  }

  bool get _isEmpty => _lanes.every((lane) => lane.group == null);

  // One only looking changes nothing: no padlock, no closed hours, no muted lessons.
  bool _slotClosed(PresenceItem slot)
  {
    final TimeBucket? bucket = bucketFor(slot.startTime);

    return !widget.readOnly && bucket != null && haveBookingsClosed(widget.day, bucket, widget.now);
  }

  bool _canDeleteDay(BookingLane lane)
  {
    final PresenceGroup? group = lane.group;

    return !widget.readOnly && group != null && !group.slots.any(_slotClosed);
  }

  Widget _buildDate(BookingsTourPlaces tour)
  {
    final bool lone = !_named && !(_isShut && _isEmpty);
    final String? bin = lone && tour.dayBin == _lanes.single.pupil.fiscalCode ? kTourBookingsDayBin : null;

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
              child: DescenderRoom(
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
            ),
            if (lone && _canDeleteDay(_lanes.single)) ...[
              const SizedBox(width: _actionGap),
              DesktopTourTarget(
                id: bin,
                child: _HoverAction(
                  visible: _hover,
                  litBy: bin,
                  icon: Icons.delete_outline_rounded,
                  color: AppTheme.trialDanger,
                  tooltip: 'Elimina la giornata',
                  onTap: () => widget.onDeleteDay(_lanes.single),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<Widget> _buildAddButtons(BookingLane lane, {bool dense = false})
  {
    final double height = dense ? _denseButtonHeight : _buttonHeight;

    return [
      for (final mode in _addableModes(lane))
        AppGradientButton(
          label: mode == kOnlineMode ? 'AGGIUNGI ONLINE' : 'AGGIUNGI IN PRESENZA',
          icon: Icons.add_rounded,
          height: height,
          fontSize: _buttonFontSize,
          radius: height / 2,
          horizontalPadding: 18,
          onPressed: () => widget.onAdd(lane, mode),
        ),
    ];
  }

  // Dense: the names' column, so «Nessuna prenotazione» lines up under the day; a bin after a name widens it.
  double _denseNameColumn(BuildContext context)
  {
    double widest = 0;

    for (final lane in _lanes)
    {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: lane.pupil.firstName, style: DefaultTextStyle.of(context).style.merge(_denseNameStyle)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();

      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    final bool bins = _lanes.any(_canDeleteDay);

    return math.min(widest, _denseNameMaxWidth) + (bins ? _actionGap + _denseActionSize : 0);
  }

  Widget _buildLane(
    BookingLane lane, {
    required bool folded,
    required BookingsTourPlaces tour,
    bool dense = false,
    bool buttonsBelow = false,
  })
  {
    return _LaneView(
      lane: lane,
      folded: folded,
      dense: dense,
      nameWidth: dense && _named ? _denseNameColumn(context) : 0,
      buttonsBelow: buttonsBelow,
      named: _named,
      tour: tour,
      ministrySubjects: widget.ministrySubjects,
      teachers: widget.teachers,
      readOnly: widget.readOnly,
      addButtons: _buildAddButtons(lane, dense: dense),
      slotClosed: _slotClosed,
      bandClosed: (band) => widget.readOnly || _hasClosed(band),
      canDeleteDay: _canDeleteDay(lane),
      onDeleteDay: () => widget.onDeleteDay(lane),
      onEditHours: (mode, band) => widget.onEditHours(lane, mode, band),
      onAddLesson: (mode, band) => widget.onAddLesson(lane, mode, band),
      onDeleteBand: (mode, band) => widget.onDeleteBand(lane, mode, band),
      onEditLesson: (booking) => widget.onEditLesson(lane, booking),
      canMoveLesson: (booking) => widget.canMoveLesson(lane, booking),
      onMoveLesson: (booking) => widget.onMoveLesson(lane, booking),
      onDeleteLesson: (booking) => widget.onDeleteLesson(lane, booking),
      blockMoveRefusal: (mode, band) => widget.blockMoveRefusal(lane, mode, band),
      onMoveBlock: (mode, band) => widget.onMoveBlock(lane, mode, band),
    );
  }

  Widget _buildLanes({
    required bool folded,
    required BookingsTourPlaces tour,
    bool dense = false,
    bool buttonsBelow = false,
  })
  {
    final double gap = dense ? _denseLaneGap : _laneGap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lane in _lanes) ...[
          if (lane != _lanes.first) ...[
            SizedBox(height: gap),
            Container(height: 1, color: AppTheme.trialLine),
            SizedBox(height: gap),
          ],
          _buildLane(lane, folded: folded, tour: tour, dense: dense, buttonsBelow: buttonsBelow),
        ],
      ],
    );
  }

  Widget _buildDenseDayName()
  {
    return DescenderRoom(
      child: Text(
        formatDayMonthFull(widget.day),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: widget.isPast || _isShut ? AppTheme.trialMutedText : AppTheme.trialOcean,
        ),
      ),
    );
  }

  // The bin of a lone pupil's day sits by the date, as in the wide card.
  Widget? _buildDenseDayBin(BookingsTourPlaces tour)
  {
    final bool lone = !_named && !(_isShut && _isEmpty);

    if (!lone || !_canDeleteDay(_lanes.single))
    {
      return null;
    }

    final String? bin = tour.dayBin == _lanes.single.pupil.fiscalCode ? kTourBookingsDayBin : null;

    return DesktopTourTarget(
      id: bin,
      child: _HoverAction(
        visible: _hover,
        litBy: bin,
        dense: true,
        icon: Icons.delete_outline_rounded,
        color: AppTheme.trialDanger,
        tooltip: 'Elimina la giornata',
        onTap: () => widget.onDeleteDay(_lanes.single),
      ),
    );
  }

  Widget _buildDenseDateColumn(BookingsTourPlaces tour)
  {
    final Widget? bin = _buildDenseDayBin(tour);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppEyebrow(weekdayFullName(widget.day.weekday)),
            if (widget.isToday) const _TodayPill(),
            ?bin,
          ],
        ),
        const SizedBox(height: 2),
        _buildDenseDayName(),
      ],
    );
  }

  Widget _buildDenseDateLine(BookingsTourPlaces tour)
  {
    final Widget? bin = _buildDenseDayBin(tour);

    return Wrap(
      spacing: 8,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppEyebrow(weekdayFullName(widget.day.weekday)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _buildDenseDayName()),
            if (bin != null) ...[const SizedBox(width: _actionGap), bin],
          ],
        ),
        if (widget.isToday) const _TodayPill(),
      ],
    );
  }

  // The date beside the pupils while there is room, else over them; lessons fold onto two lines when narrow.
  Widget _buildDense(double width, BookingsTourPlaces tour)
  {
    if (_isShut && _isEmpty)
    {
      return Row(
        children: [
          Flexible(child: _buildDenseDateLine(tour)),
          const SizedBox(width: 16),
          const Icon(Icons.event_busy_rounded, size: 17, color: AppTheme.trialMutedText),
          const SizedBox(width: 8),
          const Expanded(child: _Muted("L'Associazione è chiusa", dense: true)),
        ],
      );
    }

    if (width >= _denseOneLineFrom)
    {
      final double lanes = width - _denseDateWidth - _denseGap;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _denseDateWidth, child: _buildDenseDateColumn(tour)),
          const SizedBox(width: _denseGap),
          Expanded(
            child: _buildLanes(
              folded: lanes < _denseLessonOneLineFrom,
              tour: tour,
              dense: true,
              buttonsBelow: lanes < _denseButtonsBesideFrom,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDenseDateLine(tour),
        const SizedBox(height: 10),
        _buildLanes(folded: width < _denseLessonOneLineFrom, tour: tour, dense: true, buttonsBelow: true),
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

  Widget _buildOneLine(BookingsTourPlaces tour)
  {
    final bool shut = _isShut && _isEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _dateWidth,
            child: Align(alignment: Alignment.centerLeft, child: _buildDate(tour)),
          ),
          _Divider(color: _lineColor),
          if (shut)
            Expanded(child: _buildShutNotice())
          else
            Expanded(child: _buildLanes(folded: false, tour: tour)),
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

  Widget _buildStacked({required bool noticeBeside, required BookingsTourPlaces tour})
  {
    if (_isShut && _isEmpty)
    {
      if (noticeBeside)
      {
        return _buildOneLine(tour);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDate(tour),
          _buildRule(),
          _buildShutNotice(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDate(tour),
        _buildRule(),
        _buildLanes(folded: true, tour: tour),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool shut = _isShut && _isEmpty;
    final BookingsTourPlaces tour = _tour;
    final bool dense = AppPageDensity.of(context);
    final double radius = dense ? _denseRadius : _radius;
    final double rim = dense ? _denseRimWidth : _rimWidth;

    Widget content = LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;

        if (dense)
        {
          return _buildDense(width, tour);
        }

        if (width >= _oneLineFrom)
        {
          return _buildOneLine(tour);
        }

        return _buildStacked(noticeBeside: width >= _noticeBesideFrom, tour: tour);
      },
    );

    if (widget.isPast)
    {
      content = Opacity(opacity: _pastOpacity, child: content);
    }

    final Widget card = Container(
      padding: dense ? (shut ? _densePadding.copyWith(top: 10, bottom: 10) : _densePadding) : _padding,
      decoration: BoxDecoration(
        color: shut ? AppTheme.closedSurface : Colors.white,
        borderRadius: BorderRadius.circular(radius - rim),
      ),
      child: content,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: EdgeInsets.all(rim),
        decoration: BoxDecoration(
          gradient: widget.isToday ? AppTheme.greetingGradient : null,
          borderRadius: BorderRadius.circular(radius),
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

  // Dense sizes; the add buttons under the name instead of at the end of its line.
  final bool dense;
  final bool buttonsBelow;

  // Dense: the width of the names' column shared by the day's pupils.
  final double nameWidth;

  final bool named;

  final BookingsTourPlaces tour;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final bool readOnly;

  final List<Widget> addButtons;

  final bool Function(PresenceItem slot) slotClosed;

  // Closed to the reader: no action on the band's block.
  final bool Function(TimeBucket band) bandClosed;

  final bool canDeleteDay;

  final VoidCallback onDeleteDay;
  final void Function(String mode, TimeBucket band) onEditHours;
  final void Function(String mode, TimeBucket band) onAddLesson;
  final void Function(String mode, TimeBucket band) onDeleteBand;
  final ValueChanged<BookingSummaryItem> onEditLesson;
  final bool Function(BookingSummaryItem booking) canMoveLesson;
  final ValueChanged<BookingSummaryItem> onMoveLesson;
  final ValueChanged<BookingSummaryItem> onDeleteLesson;
  final String? Function(String mode, TimeBucket band) blockMoveRefusal;
  final void Function(String mode, TimeBucket band) onMoveBlock;

  const _LaneView({
    required this.lane,
    required this.folded,
    this.dense = false,
    this.buttonsBelow = false,
    this.nameWidth = 0,
    required this.named,
    required this.tour,
    required this.ministrySubjects,
    required this.teachers,
    required this.readOnly,
    required this.addButtons,
    required this.slotClosed,
    required this.bandClosed,
    required this.canDeleteDay,
    required this.onDeleteDay,
    required this.onEditHours,
    required this.onAddLesson,
    required this.onDeleteBand,
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

  String get _pupil => widget.lane.pupil.fiscalCode;

  Widget _buildHeader()
  {
    final String? bin = widget.tour.dayBin == _pupil ? kTourBookingsDayBin : null;

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
                        child: DescenderRoom(
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
                      ),
                      if (widget.canDeleteDay) ...[
                        const SizedBox(width: _actionGap),
                        DesktopTourTarget(
                          id: bin,
                          child: _HoverAction(
                            visible: _hover,
                            litBy: bin,
                            icon: Icons.delete_outline_rounded,
                            color: AppTheme.trialDanger,
                            tooltip: 'Elimina la giornata',
                            onTap: widget.onDeleteDay,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          if (widget.addButtons.isNotEmpty) ...[
            const SizedBox(width: _columnGap),
            DesktopTourTarget(
              id: widget.tour.add == _pupil ? kTourBookingsAdd : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final button in widget.addButtons) ...[
                    if (button != widget.addButtons.first) const SizedBox(width: _buttonGap),
                    button,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddRow({required bool wrap})
  {
    final List<Widget> buttons = widget.addButtons;

    return DesktopTourTarget(
      id: widget.tour.add == _pupil ? kTourBookingsAdd : null,
      child: wrap
          ? Wrap(spacing: _denseButtonGap, runSpacing: _denseButtonGap, children: buttons)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final button in buttons) ...[
                  if (button != buttons.first) const SizedBox(width: _denseButtonGap),
                  button,
                ],
              ],
            ),
    );
  }

  // The name, «Nessuna prenotazione» beside it, the add buttons at the end of the line or under it.
  Widget _buildDenseHeader()
  {
    final String? bin = widget.tour.dayBin == _pupil ? kTourBookingsDayBin : null;
    final bool empty = widget.lane.group == null;
    final bool buttonsBeside = widget.addButtons.isNotEmpty && !widget.buttonsBelow;

    // The name in the day's names column, «Nessuna prenotazione» after it on one line, the buttons at the end.
    final Widget line = SizedBox(
      height: _denseLaneHeaderHeight,
      child: Row(
        children: [
          if (widget.named) ...[
            SizedBox(
              width: widget.nameWidth,
              child: Row(
                children: [
                  Flexible(
                    child: DescenderRoom(
                      child: Text(
                        widget.lane.pupil.firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _denseNameStyle,
                      ),
                    ),
                  ),
                  if (widget.canDeleteDay) ...[
                    const SizedBox(width: _actionGap),
                    DesktopTourTarget(
                      id: bin,
                      child: _HoverAction(
                        visible: _hover,
                        litBy: bin,
                        dense: true,
                        icon: Icons.delete_outline_rounded,
                        color: AppTheme.trialDanger,
                        tooltip: 'Elimina la giornata',
                        onTap: widget.onDeleteDay,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _denseNameGap),
          ],
          Expanded(
            child: empty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: _Muted('Nessuna prenotazione', dense: true, lines: 1),
                  )
                : const SizedBox.shrink(),
          ),
          if (buttonsBeside) ...[
            const SizedBox(width: _denseGap),
            _buildAddRow(wrap: false),
          ],
        ],
      ),
    );

    if (widget.addButtons.isEmpty || buttonsBeside)
    {
      return line;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        const SizedBox(height: 4),
        _buildAddRow(wrap: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final PresenceGroup? group = widget.lane.group;
    final bool dense = widget.dense;

    // One block per mode and band: each band has its own hours, subjects and deadline.
    final List<(String, TimeBucket)> blocks = [
      if (group != null)
        for (final mode in _modes)
          for (final band in group.bandsFor(mode)) (mode, band),
    ];

    final bool headed = widget.named || widget.addButtons.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dense && (headed || group == null)) ...[
            _buildDenseHeader(),
            if (group != null) const SizedBox(height: _denseLaneInnerGap),
          ]
          else if (headed) ...[
            _buildHeader(),
            if (group != null || widget.named) const SizedBox(height: _laneInnerGap),
          ],
          if (group == null)
            (dense || (headed && !widget.named) ? const SizedBox.shrink() : const _Muted('Nessuna prenotazione'))
          else
            for (final (i, (mode, band)) in blocks.indexed) ...[
              if (i > 0) SizedBox(height: dense ? _denseModeGap : _modeGap),
              _ModeBlock(
                dense: dense,
                mode: mode,
                band: band,
                group: group,
                tour: widget.tour,
                block: (_pupil, mode, band),
                folded: widget.folded,
                ministrySubjects: widget.ministrySubjects,
                teachers: widget.teachers,
                readOnly: widget.readOnly,
                slotClosed: widget.slotClosed,
                canChange: !widget.bandClosed(band),
                onEditHours: () => widget.onEditHours(mode, band),
                onAddLesson: () => widget.onAddLesson(mode, band),
                onDelete: () => widget.onDeleteBand(mode, band),
                onEditLesson: widget.onEditLesson,
                canMoveLesson: widget.canMoveLesson,
                onMoveLesson: widget.onMoveLesson,
                onDeleteLesson: widget.onDeleteLesson,
                blockMoveRefusal: widget.blockMoveRefusal(mode, band),
                onMoveBlock: () => widget.onMoveBlock(mode, band),
              ),
            ],
        ],
      ),
    );
  }
}

class _ModeBlock extends StatefulWidget
{
  final bool dense;

  final String mode;
  final TimeBucket band;
  final PresenceGroup group;

  final BookingsTourPlaces tour;
  final BookingTourBlock block;

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
    this.dense = false,
    required this.mode,
    required this.band,
    required this.group,
    required this.tour,
    required this.block,
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

  List<PresenceItem> get _slots => widget.group.slotsFor(_mode, band: widget.band);

  List<BookingSummaryItem> get _lessons => widget.group.requestsFor(_mode, band: widget.band);

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

  String? get _modesTour => widget.tour.modes.contains(widget.block) ? kTourBookingsModes : null;

  String? get _actionsTour => widget.tour.bandActions == widget.block ? kTourBookingsBandActions : null;

  Widget _buildHeading()
  {
    final bool dense = widget.dense;

    final Widget heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          lessonModeIcon(_mode),
          size: dense ? 14 : _modeHeadingHeight,
          color: AppTheme.trialMutedText,
        ),
        const SizedBox(width: 5),
        Text(
          '${modeLabel(_mode)} · ${bandLabel(widget.band)}'.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 10.5 : 12,
            fontWeight: FontWeight.w700,
            letterSpacing: dense ? 1.1 : 1.4,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
        if (_hasClosed) ...[
          const SizedBox(width: 6),
          DesktopTourTarget(
            id: widget.tour.lock == widget.block ? kTourBookingsLock : null,
            child: AppTooltip(
              message: 'Prenotazioni chiuse',
              child: Icon(Icons.lock_outline_rounded, size: dense ? 13 : 15, color: AppTheme.trialMutedText),
            ),
          ),
        ],
      ],
    );

    return heading;
  }

  List<Widget> _buildActions()
  {
    return [
      if (widget.canChange) ...[
        _HoverAction(
          visible: _hover,
          dense: widget.dense,
          litBy: _actionsTour,
          icon: Icons.edit_outlined,
          color: AppTheme.trialTealDeep,
          tooltip: 'Modifica gli orari',
          onTap: widget.onEditHours,
        ),
        const SizedBox(width: 2),
        _HoverAction(
          visible: _hover,
          dense: widget.dense,
          litBy: _actionsTour,
          icon: Icons.add_rounded,
          color: AppTheme.trialTealDeep,
          tooltip: 'Aggiungi una lezione',
          onTap: widget.onAddLesson,
        ),
        if (_lessons.isNotEmpty) ...[
          const SizedBox(width: 2),
          _HoverAction(
            visible: _hover,
            dense: widget.dense,
            litBy: _actionsTour,
            icon: Icons.swap_horiz_rounded,
            color: AppTheme.trialTealDeep,
            tooltip: moveBandLessons(widget.band),
            disabledReason: widget.blockMoveRefusal,
            onTap: widget.onMoveBlock,
          ),
        ],
      ],
      if (_deletable) ...[
        if (widget.canChange) const SizedBox(width: 2),
        _HoverAction(
          visible: _hover,
          dense: widget.dense,
          litBy: _actionsTour,
          icon: Icons.delete_outline_rounded,
          color: AppTheme.trialDanger,
          tooltip: deleteBand(widget.band),
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
          _HoursChip(slot: slot, locked: widget.slotClosed(slot), dense: widget.dense),
      ],
    );
  }

  Widget _buildModeRow()
  {
    final List<Widget> actions = _buildActions();
    final double gap = widget.dense ? 8 : 12;

    return Wrap(
      spacing: gap,
      runSpacing: widget.dense ? 4 : 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // The band's name and its hours, lit by the tour as one part.
        DesktopTourTarget(
          id: _modesTour,
          child: Wrap(
            spacing: gap,
            runSpacing: widget.dense ? 4 : 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildHeading(),
              _buildChips(),
            ],
          ),
        ),
        if (actions.isNotEmpty)
          DesktopTourTarget(
            id: _actionsTour,
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
      ],
    );
  }

  List<Widget> _buildRows()
  {
    final List<BookingSummaryItem> lessons = _lessons;

    return [
      for (final booking in lessons) ...[
        if (booking != lessons.first) SizedBox(height: widget.dense ? _denseRowGap : _rowGap),
        _LessonRow(
          dense: widget.dense,
          booking: booking,
          tour: widget.tour,
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
          SizedBox(height: widget.dense ? _denseModeRowGap : _modeRowGap),
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
  final bool dense;

  const _HoursChip({required this.slot, required this.locked, this.dense = false});

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

    final double height = dense ? _denseChipHeight : _chipHeight;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(height / 2),
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
            fontSize: dense ? 11.5 : 13.5,
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
  final BookingsTourPlaces tour;
  final bool folded;

  // Dense: one line, or two when folded (subject and duration, then tags and teachers).
  final bool dense;

  final bool closed;
  final bool editable;
  final bool movable;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<PersonItem> teachers;

  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _LessonRow({
    this.dense = false,
    required this.booking,
    required this.tour,
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
          DescenderRoom(
            child: Text(
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

  // A dense row on two lines that cannot change drops its hidden actions altogether.
  bool _folds = false;

  bool get _keepsActions => !(widget.dense && _folds && !widget.editable);

  Widget _buildTrailing()
  {
    final bool shown = _hover && widget.editable;
    final String? lit = widget.editable && widget.tour.lessonActions == _booking.id ? kTourBookingsLessonActions : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DesktopTourTarget(
          id: widget.tour.topic == _booking.id ? kTourBookingsTopic : null,
          child: _Mark(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Argomento',
            text: _booking.topic,
            muted: widget.closed,
            dense: widget.dense,
          ),
        ),
        const SizedBox(width: 2),
        DesktopTourTarget(
          id: widget.tour.notes == _booking.id ? kTourBookingsNotes : null,
          child: _Mark(
            icon: Icons.sticky_note_2_outlined,
            label: 'Note per il docente',
            text: _booking.notes,
            muted: widget.closed,
            dense: widget.dense,
          ),
        ),
        if (_keepsActions) ...[
          const SizedBox(width: _actionGap),
          DesktopTourTarget(
            id: lit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HoverAction(
                  visible: shown,
                  litBy: lit,
                  dense: widget.dense,
                  icon: Icons.edit_outlined,
                  color: AppTheme.trialTealDeep,
                  tooltip: 'Modifica la lezione',
                  onTap: widget.onEdit,
                ),
                if (widget.movable) ...[
                  const SizedBox(width: 2),
                  _HoverAction(
                    visible: shown,
                    litBy: lit,
                    dense: widget.dense,
                    icon: Icons.swap_horiz_rounded,
                    color: AppTheme.trialTealDeep,
                    tooltip: 'Sposta la lezione',
                    onTap: widget.onMove,
                  ),
                ],
                const SizedBox(width: 2),
                _HoverAction(
                  visible: shown,
                  litBy: lit,
                  dense: widget.dense,
                  icon: Icons.delete_outline_rounded,
                  color: AppTheme.trialDanger,
                  tooltip: 'Elimina la lezione',
                  onTap: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
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

  TextStyle get _denseTitleStyle => GoogleFonts.plusJakartaSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppTheme.trialOcean,
  );

  TextStyle get _denseDisciplinesStyle => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppTheme.trialMutedText,
  );

  TextStyle get _densePreferenceStyle => GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppTheme.trialInk,
  );

  // The subject with its disciplines after it in grey.
  TextSpan get _denseNameSpan
  {
    final List<String> disciplines = _disciplines;

    return TextSpan(
      children: [
        TextSpan(text: _title, style: _denseTitleStyle),
        if (disciplines.isNotEmpty) TextSpan(text: '  ${disciplines.join(' · ')}', style: _denseDisciplinesStyle),
      ],
    );
  }

  String? get _preferenceText
  {
    final List<PersonItem> chosen = _preferredTeachers;

    return chosen.isEmpty ? null : chosen.map((teacher) => '${teacher.firstName} ${teacher.lastName}').join(', ');
  }

  double _spanWidth(BuildContext context, InlineSpan span)
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(style: DefaultTextStyle.of(context).style, children: [span]),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = painter.width;
    painter.dispose();

    return width;
  }

  // On one line only while subject, tags and preferences all keep their whole words in their columns.
  bool _denseFitsOneLine(BuildContext context, double width)
  {
    final double room = width - 12 - _denseDurationWidth - 12 - 8 - _denseTrailingWidth;
    final List<String> tags = bookingTagLabels(_booking.tags);

    double right = 15 + 6 + _spanWidth(
      context,
      TextSpan(text: _preferenceText ?? 'Nessuna preferenza', style: _densePreferenceStyle),
    );

    for (final label in tags)
    {
      right += _Tag.denseWidth(_spanWidth(context, TextSpan(text: label, style: _Tag.denseStyle))) + 4;
    }

    if (tags.isNotEmpty)
    {
      right += 4;
    }

    return _spanWidth(context, _denseNameSpan) <= room / 2 && right <= room / 2;
  }

  Widget _buildDenseName()
  {
    return Text.rich(
      _denseNameSpan,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(height: 1.3),
    );
  }

  Widget _buildDenseDuration()
  {
    return Text(
      formatMinutes(_booking.duration),
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppTheme.trialInk,
      ),
    );
  }

  // As wide as its words: in a wrap it shares a line with the tags while they fit.
  Widget _buildDenseTeachers()
  {
    final String? text = _preferenceText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.thumb_up_outlined, size: 15, color: AppTheme.trialMutedText),
        const SizedBox(width: 6),
        Flexible(
          child: text == null
              ? const _Muted('Nessuna preferenza', dense: true)
              : Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: _densePreferenceStyle),
        ),
      ],
    );
  }

  List<Widget> _buildDenseTags()
  {
    return [for (final label in bookingTagLabels(_booking.tags)) _Tag(label, dense: true)];
  }

  Widget _buildDenseLine()
  {
    final List<Widget> tags = _buildDenseTags();

    return Row(
      children: [
        Expanded(child: _buildDenseName()),
        const SizedBox(width: 12),
        SizedBox(width: _denseDurationWidth, child: _buildDenseDuration()),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              for (final tag in tags) ...[tag, const SizedBox(width: 4)],
              if (tags.isNotEmpty) const SizedBox(width: 4),
              Flexible(child: _buildDenseTeachers()),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: _denseTrailingWidth, child: _buildTrailing()),
      ],
    );
  }

  // Subject and duration, then tags and preferences side by side while they fit.
  Widget _buildDenseFolded()
  {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: _buildDenseName()),
                  const SizedBox(width: 10),
                  _buildDenseDuration(),
                ],
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [..._buildDenseTags(), _buildDenseTeachers()],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: _keepsActions ? _denseTrailingWidth : _denseMarksWidth, child: _buildTrailing()),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = widget.dense;
    final Widget content = dense
        ? LayoutBuilder(
            builder: (context, constraints)
            {
              _folds = widget.folded || !_denseFitsOneLine(context, constraints.maxWidth);

              return _folds ? _buildDenseFolded() : _buildDenseLine();
            },
          )
        : (widget.folded ? _buildFolded() : _buildWide());

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DesktopTourTarget(
        id: widget.tour.lesson == _booking.id ? kTourBookingsLesson : null,
        child: Container(
          padding: dense ? _denseRowPadding : _rowPadding,
          decoration: BoxDecoration(
            color: AppTheme.trialPaper,
            borderRadius: BorderRadius.circular(dense ? _denseRowRadius : _rowRadius),
          ),
          child: content,
        ),
      ),
    );
  }
}

// Sized while hidden so nothing shifts on hover; [litBy] shows it while the tour lights that part.
class _HoverAction extends StatefulWidget
{
  final bool visible;
  final String? litBy;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  final String? disabledReason;

  final bool dense;

  const _HoverAction({
    required this.visible,
    this.litBy,
    this.dense = false,
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
    final String? lit = widget.litBy;

    if (lit == null)
    {
      return _build(widget.visible);
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: desktopTourLit,
      builder: (context, ids, _) => _build(widget.visible || ids.contains(lit)),
    );
  }

  Widget _build(bool visible)
  {
    final String? reason = widget.disabledReason;

    final double size = widget.dense ? _denseActionSize : _actionSize;

    final Widget face = SizedBox(
      width: size,
      height: size,
      child: Icon(
        widget.icon,
        size: widget.dense ? _denseActionIconSize : _actionIconSize,
        color: reason == null ? widget.color : AppTheme.trialMutedText.withValues(alpha: 0.5),
      ),
    );

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: _hoverFade,
        child: AppTooltip(
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
  final bool dense;

  const _Tag(this.label, {this.dense = false});

  static TextStyle get denseStyle => GoogleFonts.plusJakartaSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppTheme.trialMutedText,
  );

  // Padding and border around a dense label of that width.
  static double denseWidth(double label) => label + 2 * 7 + 2;

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.trialMutedText.withValues(alpha: 0.35)),
      ),
      child: DescenderRoom(
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: dense
              ? denseStyle
              : GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.trialMutedText,
                ),
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

  final bool dense;

  const _Mark({required this.icon, required this.label, required this.text, required this.muted, this.dense = false});

  @override
  Widget build(BuildContext context)
  {
    final String? said = text?.trim();
    final double size = dense ? _denseMarkSize : _markSize;

    if (said == null || said.isEmpty)
    {
      return SizedBox(width: size, height: size);
    }

    final Widget face = SizedBox(
      width: size,
      height: size,
      child: Icon(
        icon,
        size: dense ? _denseMarkIconSize : _markIconSize,
        color: muted ? AppTheme.trialMutedText.withValues(alpha: 0.5) : AppTheme.trialTealDeep,
      ),
    );

    return AppTooltip(
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
  final bool dense;

  // Dense lines are narrow: the words take a second line rather than an ellipsis, unless kept to one.
  final int? lines;

  const _Muted(this.text, {this.dense = false, this.lines});

  @override
  Widget build(BuildContext context)
  {
    return DescenderRoom(
      child: Text(
        text,
        maxLines: lines ?? (dense ? 2 : 1),
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 12.5 : 15,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          height: 1.35,
          color: AppTheme.trialMutedText,
        ),
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
