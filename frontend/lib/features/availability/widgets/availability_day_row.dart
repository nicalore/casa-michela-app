import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/utils/opening_window.dart';

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

class AvailabilityDayRow extends StatelessWidget
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
  });

  bool _isOpenIn(TimeBucket bucket) => unionOpeningWindow(openingDays, day, bucket) != null;

  bool _isOpenFor(TimeBucket bucket, String mode)
  {
    return openingWindowFor(openingDays, day, mode, bucket) != null;
  }

  bool _hasClosed(TimeBucket bucket) => haveBookingsClosed(day, bucket, now);

  bool get _isShut => !TimeBucket.values.any(_isOpenIn);

  bool get _isEditable => TimeBucket.values.any((bucket) => _isOpenIn(bucket) && !_hasClosed(bucket));

  List<AvailabilityItem> _slotsIn(TimeBucket bucket)
  {
    return slots.where((slot) => bucketFor(slot.startTime) == bucket).toList();
  }

  Widget _buildDate()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEyebrow(weekdayFullName(day.weekday)),
            if (isToday) ...[
              const SizedBox(width: 8),
              const _TodayPill(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatDayMonthFull(day),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: isPast || _isShut ? AppTheme.trialMutedText : AppTheme.trialOcean,
          ),
        ),
      ],
    );
  }

  Widget _buildAction()
  {
    if (_isEditable)
    {
      final bool empty = slots.isEmpty;

      return AppGradientButton(
        label: empty ? 'AGGIUNGI' : 'MODIFICA',
        icon: empty ? Icons.add_rounded : Icons.edit_outlined,
        height: _buttonHeight,
        fontSize: _buttonFontSize,
        radius: _buttonHeight / 2,
        horizontalPadding: 18,
        onPressed: onOpen,
      );
    }

    if (_isShut && slots.isEmpty)
    {
      return const SizedBox.shrink();
    }

    return Text(
      'Non modificabile',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppTheme.trialMutedText,
      ),
    );
  }

  List<Widget> _buildMiddle()
  {
    if (_isShut && slots.isEmpty)
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

  Widget _buildBand(TimeBucket bucket)
  {
    return _BandCell(
      bucket: bucket,
      day: day,
      slots: _slotsIn(bucket),
      openModes: {for (final mode in _modes) if (_isOpenFor(bucket, mode)) mode},
      hasClosed: _hasClosed(bucket),
      onDeleteSlot: onDeleteSlot,
      onDeleteBand: onDeleteBand,
    );
  }

  Color get _lineColor => _isShut && slots.isEmpty ? AppTheme.closedLine : AppTheme.trialLine;

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
    if (_isShut && slots.isEmpty)
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
    final bool shut = _isShut && slots.isEmpty;

    Widget content = LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;

        if (width >= _oneLineFrom)
        {
          return _buildOneLine();
        }

        return _buildStacked(columns: width >= _threeColumnsFrom);
      },
    );

    if (isPast)
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

    return Container(
      padding: const EdgeInsets.all(_rimWidth),
      decoration: BoxDecoration(
        gradient: isToday ? AppTheme.greetingGradient : null,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: shut ? null : AppTheme.cardShadow,
      ),
      child: card,
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
  final TimeBucket bucket;
  final DateTime day;
  final List<AvailabilityItem> slots;

  final Set<String> openModes;
  final bool hasClosed;

  final ValueChanged<AvailabilityItem> onDeleteSlot;
  final void Function(TimeBucket band, List<AvailabilityItem> slots) onDeleteBand;

  const _BandCell({
    required this.bucket,
    required this.day,
    required this.slots,
    required this.openModes,
    required this.hasClosed,
    required this.onDeleteSlot,
    required this.onDeleteBand,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bandLabel(widget.bucket),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: AppTheme.trialOcean,
                ),
              ),
              if (widget.isOpen && widget.hasClosed) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Disponibilità chiuse',
                  child: const Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.trialMutedText),
                ),
              ],
              if (_deletable) ...[
                const SizedBox(width: _binGap),
                _Bin(
                  visible: _hover,
                  onTap: () => widget.onDeleteBand(widget.bucket, widget.slots),
                ),
              ],
            ],
          ),
          const SizedBox(height: _titleGap),
          if (!widget.isOpen && widget.slots.isEmpty)
            const _Muted('Associazione chiusa')
          else
            for (final mode in _modes) ...[
              if (mode != _modes.first) const SizedBox(height: _groupGap),
              _buildGroup(mode, locked),
            ],
        ],
      ),
    );
  }

  Widget _buildGroup(String mode, bool locked)
  {
    final bool online = mode == kOnlineMode;
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
              online ? Icons.videocam_outlined : Icons.home_work_outlined,
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

  final VoidCallback? onDelete;

  const _HoursChip({required this.slot, required this.locked, this.onDelete});

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

    // Sized on the text: an aligned Container would stretch to the Wrap's width.
    final Widget chip = Container(
      height: _chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_chipHeight / 2),
      ),
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: Text(
          formatTimeRange(slot.startTime, slot.endTime),
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: ink,
          ),
        ),
      ),
    );

    final VoidCallback? onDelete = widget.onDelete;

    // Same box with or without a badge, so lines stay aligned.
    final Widget boxed = Padding(
      padding: const EdgeInsets.only(top: _badgeOverhangTop, right: _badgeOverhangRight),
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
            child: _BinBadge(visible: _hover, onTap: onDelete),
          ),
        ],
      ),
    );
  }
}

class _BinBadge extends StatefulWidget
{
  final bool visible;
  final VoidCallback onTap;

  const _BinBadge({required this.visible, required this.onTap});

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
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: _hover ? AppTheme.trialGoldSurface : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _hover ? AppTheme.trialGold : AppTheme.trialLine, width: 1.5),
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.trialDanger),
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
  final VoidCallback onTap;

  const _Bin({required this.visible, required this.onTap});

  @override
  State<_Bin> createState() => _BinState();
}

class _BinState extends State<_Bin>
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
              width: _binSize,
              height: _binSize,
              decoration: BoxDecoration(
                color: _hover ? AppTheme.trialGoldSurface : AppTheme.trialGoldSurface.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.trialDanger),
            ),
          ),
        ),
      ),
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
        fontSize: 14,
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
