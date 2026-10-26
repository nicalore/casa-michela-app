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
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/calendar_lesson_block.dart' show lessonModeIcon;
import '../availability_tour.dart';

const double _radius = 24;
const EdgeInsets _padding = EdgeInsets.fromLTRB(26, 24, 26, 24);

const double _rimWidth = 2.5;

const double _pastOpacity = 0.55;

const double _dateWidth = 180;
const double _actionWidth = 150;
const double _columnGap = 24;

const double _dividerGap = 18;

// Below these, date and button take their own line, then the bands stack.
const double _oneLineFrom = 1420;
const double _threeColumnsFrom = 700;
const double _stackedGap = 18;

const double _buttonHeight = 40;
const double _buttonFontSize = 12.5;

const double _binSize = 26;
const double _binGap = 4;

// The badge overhang is part of the chip's own box, so hover holds while over it.
const double _badgeSize = 27;
const double _badgeOverhangRight = 14;
const double _badgeOverhangTop = 7;

const double _chipSpacing = 2;
const double _chipRunSpacing = 3;

const double _chipLineHeight = _chipHeight + _badgeOverhangTop;

const Duration _binFade = Duration(milliseconds: 150);

// One line's room is kept under each mode heading so a first stretch does not grow the row.
const double _chipHeight = 32;

const double _modeHeadingHeight = 14;

const double _groupGap = 14;
const double _titleGap = 10;

const List<String> _modes = [kPresenceMode, kOnlineMode];

// Below the wide window: a smaller card, the date beside the bands while they have room, the mode in each chip.
const double _denseRadius = 20;
const EdgeInsets _densePadding = EdgeInsets.fromLTRB(16, 14, 16, 14);
const double _denseRimWidth = 2;
const double _denseDateWidth = 124;
const double _denseActionWidth = 140;
const double _denseGap = 12;
const double _denseButtonHeight = 36;

// A band keeps a chip and its bin badge; three of them, date and button need the first width, three alone the second.
const double _denseBandWidth = 142;
const double _denseOneLineFrom = _denseDateWidth + _denseActionWidth + 4 * _denseGap + 3 * _denseBandWidth;
const double _denseColumnsFrom = 2 * _denseGap + 3 * _denseBandWidth;

const double _denseChipHeight = 26;
const double _denseBadgeSize = 22;
const double _denseBadgeOverhangRight = 10;
const double _denseBadgeOverhangTop = 6;
const double _denseChipLineHeight = _denseChipHeight + _denseBadgeOverhangTop;

// What a day can show the tour; the page gives each mark to the first day having it.
Set<AvailabilityTourMark> availabilityTourMarksOf({
  required DateTime day,
  required List<AvailabilityItem> slots,
  required List<OpeningDayItem> openingDays,
  required DateTime now,
})
{
  bool open(TimeBucket bucket) => unionOpeningWindow(openingDays, day, bucket) != null;
  bool closed(TimeBucket bucket) => haveBookingsClosed(day, bucket, now);

  final bool editable = TimeBucket.values.any((bucket) => open(bucket) && !closed(bucket));
  final bool heldEditable = slots.any((slot)
  {
    final TimeBucket? bucket = bucketFor(slot.startTime);

    return bucket != null && open(bucket) && !closed(bucket);
  });

  return {
    if (heldEditable) AvailabilityTourMark.modes,
    if (editable && slots.isEmpty) AvailabilityTourMark.add,
    if (editable && slots.isNotEmpty) AvailabilityTourMark.edit,
    if (TimeBucket.values.any((bucket) => open(bucket) && closed(bucket))) AvailabilityTourMark.lock,
    if (heldEditable) AvailabilityTourMark.bins,
  };
}

class AvailabilityDayRow extends StatefulWidget
{
  final DateTime day;

  final bool isToday;
  final bool isPast;

  final List<AvailabilityItem> slots;

  final List<OpeningDayItem> openingDays;

  final DateTime now;

  final VoidCallback onOpen;

  final ValueChanged<AvailabilityItem> onDeleteSlot;
  final void Function(TimeBucket band, List<AvailabilityItem> slots) onDeleteBand;
  final VoidCallback onDeleteDay;

  final Set<AvailabilityTourMark> tourMarks;

  const AvailabilityDayRow({
    super.key,
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.slots,
    required this.openingDays,
    required this.now,
    required this.onOpen,
    required this.onDeleteSlot,
    required this.onDeleteBand,
    required this.onDeleteDay,
    this.tourMarks = const {},
  });

  @override
  State<AvailabilityDayRow> createState() => _AvailabilityDayRowState();
}

class _AvailabilityDayRowState extends State<AvailabilityDayRow>
{
  bool _hover = false;

  // The tour shows the bins the mouse would.
  bool _binsLit = false;

  @override
  void initState()
  {
    super.initState();
    _binsLit = _isBinsLit;
    desktopTourLit.addListener(_onLit);
  }

  @override
  void didUpdateWidget(AvailabilityDayRow oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    _binsLit = _isBinsLit;
  }

  @override
  void dispose()
  {
    desktopTourLit.removeListener(_onLit);
    super.dispose();
  }

  bool get _isBinsLit =>
      widget.tourMarks.contains(AvailabilityTourMark.bins) && desktopTourLit.value.contains(kTourAvailabilityBins);

  void _onLit()
  {
    if (_isBinsLit != _binsLit)
    {
      setState(() => _binsLit = _isBinsLit);
    }
  }

  String? _tourId(AvailabilityTourMark mark, String id) => widget.tourMarks.contains(mark) ? id : null;

  // The band whose colours the tour shows, and the one whose lock it shows.
  TimeBucket? get _modesBand => TimeBucket.values
      .where((bucket) => _isOpenIn(bucket) && !_hasClosed(bucket) && _slotsIn(bucket).isNotEmpty)
      .firstOrNull;

  TimeBucket? get _lockBand => TimeBucket.values.where((bucket) => _isOpenIn(bucket) && _hasClosed(bucket)).firstOrNull;

  bool _isOpenIn(TimeBucket bucket) => unionOpeningWindow(widget.openingDays, widget.day, bucket) != null;

  bool _isOpenFor(TimeBucket bucket, String mode)
  {
    return openingWindowFor(widget.openingDays, widget.day, mode, bucket) != null;
  }

  bool _hasClosed(TimeBucket bucket) => haveBookingsClosed(widget.day, bucket, widget.now);

  bool get _isShut => !TimeBucket.values.any(_isOpenIn);

  bool get _isEditable => TimeBucket.values.any((bucket) => _isOpenIn(bucket) && !_hasClosed(bucket));

  List<AvailabilityItem> _slotsIn(TimeBucket bucket)
  {
    return widget.slots.where((slot) => bucketFor(slot.startTime) == bucket).toList();
  }

  // As in the bookings, the whole day goes only when nothing on it is locked.
  bool get _canDeleteDay
  {
    return widget.slots.isNotEmpty &&
        widget.slots.every((slot)
        {
          final TimeBucket? bucket = bucketFor(slot.startTime);

          return bucket != null && _isOpenIn(bucket) && !_hasClosed(bucket);
        });
  }

  Widget _buildDate()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The pill goes under the weekday when the column is too narrow for both.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppEyebrow(weekdayFullName(widget.day.weekday)),
            if (widget.isToday) const _TodayPill(),
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
            if (_canDeleteDay) ...[
              const SizedBox(width: _binGap),
              _Bin(
                visible: _hover || _binsLit,
                tooltip: 'Elimina la giornata',
                onTap: widget.onDeleteDay,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAction({bool dense = false})
  {
    if (_isEditable)
    {
      final bool empty = widget.slots.isEmpty;
      final double height = dense ? _denseButtonHeight : _buttonHeight;

      return DesktopTourTarget(
        id: empty
            ? _tourId(AvailabilityTourMark.add, kTourAvailabilityAdd)
            : _tourId(AvailabilityTourMark.edit, kTourAvailabilityEdit),
        child: AppGradientButton(
          label: empty ? 'AGGIUNGI' : 'MODIFICA',
          icon: empty ? Icons.add_rounded : Icons.edit_outlined,
          height: height,
          fontSize: _buttonFontSize,
          radius: height / 2,
          horizontalPadding: 18,
          onPressed: widget.onOpen,
        ),
      );
    }

    if (_isShut && widget.slots.isEmpty)
    {
      return const SizedBox.shrink();
    }

    return _buildLockedNote(dense: dense);
  }

  Widget _buildLockedNote({bool dense = false})
  {
    return Text(
      'Non modificabile',
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 11.5 : 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppTheme.trialMutedText,
      ),
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

  Widget? _buildDayBin()
  {
    if (!_canDeleteDay)
    {
      return null;
    }

    return _Bin(visible: _hover || _binsLit, tooltip: 'Elimina la giornata', onTap: widget.onDeleteDay);
  }

  // Beside the bands: weekday (and the day's bin) over the date, the note of a day no longer editable under it.
  Widget _buildDenseDateColumn()
  {
    final Widget? bin = _buildDayBin();

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
        if (!_isEditable && !(_isShut && widget.slots.isEmpty)) ...[
          const SizedBox(height: 2),
          _buildLockedNote(dense: true),
        ],
      ],
    );
  }

  // Over the bands: weekday, date and the today pill on one line.
  Widget _buildDenseDateLine()
  {
    final Widget? bin = _buildDayBin();

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
            if (bin != null) ...[const SizedBox(width: _binGap), bin],
          ],
        ),
        if (widget.isToday) const _TodayPill(),
      ],
    );
  }

  Widget _buildDenseShut()
  {
    return Row(
      children: [
        Flexible(child: _buildDenseDateLine()),
        const SizedBox(width: 16),
        const Icon(Icons.event_busy_rounded, size: 17, color: AppTheme.trialMutedText),
        const SizedBox(width: 8),
        const Expanded(child: _Muted("L'Associazione è chiusa", dense: true)),
      ],
    );
  }

  List<Widget> _buildDenseBands({required bool columns})
  {
    return [
      for (final bucket in TimeBucket.values) ...[
        if (bucket != TimeBucket.values.first) SizedBox(width: _denseGap, height: columns ? 0 : 12),
        if (columns) Expanded(child: _buildBand(bucket, dense: true)) else _buildBand(bucket, dense: true),
      ],
    ];
  }

  Widget _buildDense(double width)
  {
    if (_isShut && widget.slots.isEmpty)
    {
      return _buildDenseShut();
    }

    if (width >= _denseOneLineFrom)
    {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: _denseDateWidth, child: _buildDenseDateColumn()),
          const SizedBox(width: _denseGap),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: _buildDenseBands(columns: true)),
          ),
          const SizedBox(width: _denseGap),
          SizedBox(
            width: _denseActionWidth,
            child: Align(alignment: Alignment.centerRight, child: _isEditable ? _buildAction(dense: true) : null),
          ),
        ],
      );
    }

    final bool columns = width >= _denseColumnsFrom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _buildDenseDateLine()),
            const SizedBox(width: _denseGap),
            _buildAction(dense: true),
          ],
        ),
        const SizedBox(height: 10),
        if (columns)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: _buildDenseBands(columns: true))
        else
          ..._buildDenseBands(columns: false),
      ],
    );
  }

  List<Widget> _buildMiddle()
  {
    if (_isShut && widget.slots.isEmpty)
    {
      return [Expanded(child: _buildShutNotice())];
    }

    return [
      for (final bucket in TimeBucket.values) ...[
        if (bucket != TimeBucket.values.first) const _Divider(),
        Expanded(child: _buildBand(bucket)),
      ],
    ];
  }

  Widget _buildBand(TimeBucket bucket, {bool dense = false})
  {
    return _BandCell(
      dense: dense,
      bucket: bucket,
      day: widget.day,
      slots: _slotsIn(bucket),
      openModes: {for (final mode in _modes) if (_isOpenFor(bucket, mode)) mode},
      hasClosed: _hasClosed(bucket),
      onDeleteSlot: widget.onDeleteSlot,
      onDeleteBand: widget.onDeleteBand,
      showBins: _binsLit,
      modesTour: bucket == _modesBand ? _tourId(AvailabilityTourMark.modes, kTourAvailabilityModes) : null,
      lockTour: bucket == _lockBand ? _tourId(AvailabilityTourMark.lock, kTourAvailabilityLock) : null,
    );
  }

  Color get _lineColor => _isShut && widget.slots.isEmpty ? AppTheme.closedLine : AppTheme.trialLine;

  Widget _buildOneLine()
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _dateWidth,
            child: Align(alignment: Alignment.centerLeft, child: _buildDate()),
          ),
          _Divider(color: _lineColor),
          ..._buildMiddle(),
          const SizedBox(width: _columnGap),
          SizedBox(
            width: _actionWidth,
            child: Align(alignment: Alignment.centerRight, child: _buildAction()),
          ),
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

  Widget _buildStacked({required bool columns})
  {
    if (_isShut && widget.slots.isEmpty)
    {
      if (columns)
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
        Row(
          children: [
            Expanded(child: _buildDate()),
            const SizedBox(width: _columnGap),
            _buildAction(),
          ],
        ),
        _buildRule(),
        if (columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildMiddle(),
            ),
          )
        else
          for (final bucket in TimeBucket.values) ...[
            if (bucket != TimeBucket.values.first) _buildRule(),
            _buildBand(bucket),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool shut = _isShut && widget.slots.isEmpty;
    final bool dense = AppPageDensity.of(context);
    final double radius = dense ? _denseRadius : _radius;
    final double rim = dense ? _denseRimWidth : _rimWidth;

    Widget content = LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;

        if (dense)
        {
          return _buildDense(width);
        }

        if (width >= _oneLineFrom)
        {
          return _buildOneLine();
        }

        return _buildStacked(columns: width >= _threeColumnsFrom);
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

    return DesktopTourTarget(
      id: _tourId(AvailabilityTourMark.bins, kTourAvailabilityBins),
      child: MouseRegion(
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

class _BandCell extends StatefulWidget
{
  // Dense: the mode rides in each chip instead of a heading per mode.
  final bool dense;

  final TimeBucket bucket;
  final DateTime day;
  final List<AvailabilityItem> slots;

  final Set<String> openModes;
  final bool hasClosed;

  final ValueChanged<AvailabilityItem> onDeleteSlot;
  final void Function(TimeBucket band, List<AvailabilityItem> slots) onDeleteBand;

  // The tour shows every bin, and lights the cell or its lock.
  final bool showBins;
  final String? modesTour;
  final String? lockTour;

  const _BandCell({
    this.dense = false,
    required this.bucket,
    required this.day,
    required this.slots,
    required this.openModes,
    required this.hasClosed,
    required this.onDeleteSlot,
    required this.onDeleteBand,
    this.showBins = false,
    this.modesTour,
    this.lockTour,
  });

  bool get isOpen => openModes.isNotEmpty;

  @override
  State<_BandCell> createState() => _BandCellState();
}

class _BandCellState extends State<_BandCell>
{
  bool _hover = false;

  bool get _deletable => widget.isOpen && !widget.hasClosed && widget.slots.isNotEmpty;

  @override
  Widget build(BuildContext context)
  {
    final bool locked = widget.hasClosed || !widget.isOpen;

    return DesktopTourTarget(
      id: widget.modesTour,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    bandLabel(widget.bucket),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: widget.dense ? 13 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppTheme.trialOcean,
                    ),
                  ),
                ),
                if (widget.isOpen && widget.hasClosed) ...[
                  SizedBox(width: widget.dense ? 4 : 6),
                  DesktopTourTarget(
                    id: widget.lockTour,
                    child: AppTooltip(
                      message: 'Disponibilità chiuse',
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: widget.dense ? 13 : 15,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ),
                ],
                if (_deletable) ...[
                  const SizedBox(width: _binGap),
                  _Bin(
                    visible: _hover || widget.showBins,
                    onTap: () => widget.onDeleteBand(widget.bucket, widget.slots),
                  ),
                ],
              ],
            ),
            SizedBox(height: widget.dense ? 2 : _titleGap),
            if (widget.dense)
              _buildDenseChips(locked)
            else if (!widget.isOpen && widget.slots.isEmpty)
              const _Muted('Associazione chiusa')
            else
              for (final mode in _modes) ...[
                if (mode != _modes.first) const SizedBox(height: _groupGap),
                _buildGroup(mode, locked),
              ],
          ],
        ),
      ),
    );
  }

  // Every slot of the band in one wrap, each chip showing its mode; one line's room kept so rows line up.
  Widget _buildDenseChips(bool locked)
  {
    final Widget content;

    if (widget.slots.isEmpty)
    {
      content = Padding(
        padding: const EdgeInsets.only(top: _denseBadgeOverhangTop),
        child: _Muted(widget.isOpen ? 'Nessuna disponibilità' : 'Associazione chiusa', dense: true),
      );
    }
    else
    {
      content = Wrap(
        spacing: _chipSpacing,
        runSpacing: _chipRunSpacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final slot in widget.slots)
            _HoursChip(
              slot: slot,
              dense: true,
              locked: locked || !widget.openModes.contains(slot.mode),
              showBin: widget.showBins,
              onDelete: locked ? null : () => widget.onDeleteSlot(slot),
            ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _denseChipLineHeight),
      child: Align(alignment: Alignment.topLeft, child: content),
    );
  }

  Widget _buildGroup(String mode, bool locked)
  {
    final List<AvailabilityItem> held = widget.slots.where((slot) => slot.mode == mode).toList();

    final Widget content;

    if (held.isNotEmpty)
    {
      content = Wrap(
        spacing: _chipSpacing,
        runSpacing: _chipRunSpacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final slot in held)
            _HoursChip(
              slot: slot,
              locked: locked || !widget.openModes.contains(mode),
              showBin: widget.showBins,
              onDelete: locked ? null : () => widget.onDeleteSlot(slot),
            ),
        ],
      );
    }
    else
    {
      content = Padding(
        padding: const EdgeInsets.only(top: _badgeOverhangTop),
        child: _Muted(widget.openModes.contains(mode) ? 'Nessuna disponibilità' : 'Associazione chiusa'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lessonModeIcon(mode),
              size: _modeHeadingHeight,
              color: AppTheme.trialMutedText,
            ),
            const SizedBox(width: 5),
            Text(
              modeLabel(mode).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1.2,
                color: AppTheme.trialMutedText,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _chipLineHeight),
          child: Align(alignment: Alignment.topLeft, child: content),
        ),
      ],
    );
  }
}

class _HoursChip extends StatefulWidget
{
  final AvailabilityItem slot;
  final bool locked;

  final bool showBin;

  final VoidCallback? onDelete;

  // Dense: smaller, with the mode's icon before the hours.
  final bool dense;

  const _HoursChip({required this.slot, required this.locked, this.showBin = false, this.onDelete, this.dense = false});

  @override
  State<_HoursChip> createState() => _HoursChipState();
}

class _HoursChipState extends State<_HoursChip>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final AvailabilityItem slot = widget.slot;
    final bool online = slot.mode == kOnlineMode;

    final Color surface = widget.locked
        ? AppTheme.trialPaper
        : (online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface);
    final Color ink = widget.locked
        ? AppTheme.trialMutedText
        : (online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep);

    final bool dense = widget.dense;
    final double height = dense ? _denseChipHeight : _chipHeight;

    final Widget hours = Text(
      formatTimeRange(slot.startTime, slot.endTime),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 12.5 : 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
      ),
    );

    // Sized on the text: an aligned Container would stretch to the Wrap's width.
    final Widget chip = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: dense
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(lessonModeIcon(slot.mode), size: 14, color: ink),
                  const SizedBox(width: 5),
                  Flexible(child: hours),
                ],
              )
            : hours,
      ),
    );

    final VoidCallback? onDelete = widget.onDelete;

    // Same box with or without a badge, so lines stay aligned.
    final Widget boxed = Padding(
      padding: EdgeInsets.only(
        top: dense ? _denseBadgeOverhangTop : _badgeOverhangTop,
        right: dense ? _denseBadgeOverhangRight : _badgeOverhangRight,
      ),
      child: chip,
    );

    if (onDelete == null)
    {
      return boxed;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        children: [
          boxed,
          Positioned(
            top: 0,
            right: 0,
            child: _BinBadge(
              visible: _hover || widget.showBin,
              size: dense ? _denseBadgeSize : _badgeSize,
              onTap: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _BinBadge extends StatefulWidget
{
  final bool visible;
  final double size;
  final VoidCallback onTap;

  const _BinBadge({required this.visible, this.size = _badgeSize, required this.onTap});

  @override
  State<_BinBadge> createState() => _BinBadgeState();
}

class _BinBadgeState extends State<_BinBadge>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: _binFade,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: _binFade,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _hover ? AppTheme.trialGoldSurface : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _hover ? AppTheme.trialGold : AppTheme.trialLine, width: 1.5),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Icon(Icons.delete_outline_rounded, size: widget.size * 2 / 3, color: AppTheme.trialDanger),
            ),
          ),
        ),
      ),
    );
  }
}

// Sized whether shown or not, so nothing shifts when it appears.
class _Bin extends StatefulWidget
{
  final bool visible;
  final String? tooltip;
  final VoidCallback onTap;

  const _Bin({required this.visible, this.tooltip, required this.onTap});

  @override
  State<_Bin> createState() => _BinState();
}

class _BinState extends State<_Bin>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final Widget face = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _binFade,
          width: _binSize,
          height: _binSize,
          decoration: BoxDecoration(
            color: _hover ? AppTheme.trialGoldSurface : AppTheme.trialGoldSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.trialDanger),
        ),
      ),
    );

    final String? tooltip = widget.tooltip;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: _binFade,
        child: tooltip == null ? face : AppTooltip(message: tooltip, child: face),
      ),
    );
  }
}

class _Muted extends StatelessWidget
{
  final String text;
  final bool dense;

  const _Muted(this.text, {this.dense = false});

  @override
  Widget build(BuildContext context)
  {
    // Dense columns are narrow: the words take a second line rather than an ellipsis.
    return DescenderRoom(
      child: Text(
        text,
        maxLines: dense ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 12.5 : 14,
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
