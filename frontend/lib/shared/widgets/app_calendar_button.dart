import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/week_range.dart';
import '../utils/day_marks.dart';
import 'carousel_arrow_button.dart';

const double _popoverWidth = 336;
const double _popoverGap = 8;

const double _cellHeight = 44;
const double _dayDiameter = 36;
const double _dotSize = 5;

const double _monthArrowSize = 32;
const double _monthArrowIconSize = 18;

const Color _disabledDay = Color(0xFFB4C0C7);

// Fading from Colors.transparent (black) would pass through grey.
final Color _goldSurfaceClear = AppTheme.trialGoldSurface.withValues(alpha: 0);

const Duration _revealIn = Duration(milliseconds: 200);
const Duration _revealOut = Duration(milliseconds: 120);

// No scaling: text scaled per frame shimmers and the shadows redraw every frame.
const double _revealRise = 6;

// Lowest drawn alpha: at 0 the first paint (blurs, glyphs) would stall the motion's first frame.
const double _primeOpacity = 1 / 255;

class AppCalendarButton extends StatefulWidget
{
  final DateTime selected;
  final DateTime? selectedEnd;

  final DateTime first;
  final DateTime last;

  // Ringed in gold; the clock's day when null.
  final DateTime? today;

  final ValueChanged<DateTime> onPicked;

  final DayMarksLoader? loadMarks;

  const AppCalendarButton({
    super.key,
    required this.selected,
    this.selectedEnd,
    this.today,
    required this.first,
    required this.last,
    required this.onPicked,
    this.loadMarks,
  });

  @override
  State<AppCalendarButton> createState() => _AppCalendarButtonState();
}

class _AppCalendarButtonState extends State<AppCalendarButton> with SingleTickerProviderStateMixin
{
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  // Built in initState: a late controller first touched in dispose() would be created there.
  late final AnimationController _reveal;
  late final Animation<double> _curve;
  late final Animation<double> _opacity;

  bool _isHovered = false;

  // Read on hover, dropped on close so the next opening shows fresh closures.
  final ValueNotifier<Map<DateTime, DayMarks>> _marks = ValueNotifier(const {});
  final Set<DateTime> _reading = {};

  bool get _isOpen => _portal.isShowing && _reveal.status != AnimationStatus.reverse;

  @override
  void initState()
  {
    super.initState();

    _reveal = AnimationController(vsync: this, duration: _revealIn, reverseDuration: _revealOut);
    _curve = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _opacity = Tween<double>(begin: _primeOpacity, end: 1).animate(_curve);
  }

  @override
  void dispose()
  {
    _reveal.dispose();
    _marks.dispose();
    super.dispose();
  }

  Future<void> _read(DateTime month) async
  {
    final loader = widget.loadMarks;

    if (loader == null || _marks.value.containsKey(month) || !_reading.add(month))
    {
      return;
    }

    final marks = await loader(month, DateTime(month.year, month.month + 1, 0));

    _reading.remove(month);

    if (mounted)
    {
      _marks.value = {..._marks.value, month: marks};
    }
  }

  void _toggle()
  {
    if (_isOpen)
    {
      _close();

      return;
    }

    _read(DateTime(widget.selected.year, widget.selected.month));
    setState(_portal.show);

    // After the month's costly first frame, so the motion does not start with a stall.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted && _portal.isShowing)
      {
        _reveal.forward();
      }
    });
  }

  Future<void> _close() async
  {
    if (!_isOpen)
    {
      return;
    }

    setState(() {});

    await _reveal.reverse();

    // Reopened while leaving: it stays.
    if (mounted && _reveal.isDismissed)
    {
      setState(_portal.hide);
      _marks.value = const {};
    }
  }

  void _pick(DateTime day)
  {
    _close();
    widget.onPicked(day);
  }

  Widget _buildPopover(BuildContext context)
  {
    return Positioned(
      width: _popoverWidth,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomCenter,
        followerAnchor: Alignment.topCenter,
        offset: const Offset(0, _popoverGap),
        child: TapRegion(
          groupId: _link,
          onTapOutside: (_) => _close(),
          child: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
            child: Focus(
              autofocus: true,
              child: FadeTransition(
                opacity: _opacity,
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -_revealRise * (1 - _curve.value)),
                    child: child,
                  ),
                  // Painted once; the frames of the motion only move it.
                  child: RepaintBoundary(
                    child: _MonthPopover(
                      selected: widget.selected,
                      selectedEnd: widget.selectedEnd ?? widget.selected,
                      first: widget.first,
                      last: widget.last,
                      today: _dateOnly(widget.today ?? romeNow()),
                      marks: _marks,
                      onMonth: _read,
                      onPicked: _pick,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool lit = _isHovered || _isOpen;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildPopover,
        child: TapRegion(
          groupId: _link,
          child: Tooltip(
            message: kPickDayLabel,
            waitDuration: const Duration(milliseconds: 400),
            decoration: AppTheme.tooltipDecoration,
            textStyle: AppTheme.tooltipTextStyle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_)
              {
                setState(() => _isHovered = true);
                _read(DateTime(widget.selected.year, widget.selected.month));
              },
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: CarouselArrowButton.defaultSize,
                  height: CarouselArrowButton.defaultSize,
                  decoration: BoxDecoration(
                    color: lit ? AppTheme.trialTealDeep : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 21,
                    color: lit ? Colors.white : AppTheme.trialTealDeep,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthPopover extends StatefulWidget
{
  final DateTime selected;
  final DateTime selectedEnd;
  final DateTime first;
  final DateTime last;
  final DateTime today;

  final ValueListenable<Map<DateTime, DayMarks>> marks;

  // Asks for a month's marks as it comes into view.
  final ValueChanged<DateTime> onMonth;

  final ValueChanged<DateTime> onPicked;

  const _MonthPopover({
    required this.selected,
    required this.selectedEnd,
    required this.first,
    required this.last,
    required this.today,
    required this.marks,
    required this.onMonth,
    required this.onPicked,
  });

  @override
  State<_MonthPopover> createState() => _MonthPopoverState();
}

class _MonthPopoverState extends State<_MonthPopover>
{
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  // The day before the 1st is the previous month's last.
  bool get _hasPrevious => !DateTime(_month.year, _month.month, 0).isBefore(_dateOnly(widget.first));

  bool get _hasNext => !DateTime(_month.year, _month.month + 1).isAfter(widget.last);

  bool get _hasToday => !widget.today.isBefore(_dateOnly(widget.first)) && !widget.today.isAfter(_dateOnly(widget.last));


  void _turn(int months)
  {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    widget.onMonth(_month);
  }

  bool _isInShown(DateTime day)
  {
    return !day.isBefore(_dateOnly(widget.selected)) && !day.isAfter(_dateOnly(widget.selectedEnd));
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime today = widget.today;
    final bool single = isSameDate(widget.selected, widget.selectedEnd);

    final TextStyle weekdayStyle = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppTheme.trialMutedText,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          ...AppTheme.overlayShadow,
          BoxShadow(color: Color(0x29081E2C), offset: Offset(0, 18), blurRadius: 40),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMonthYear(_month),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              _TodayButton(
                enabled: _hasToday,
                onTap: () => widget.onPicked(widget.today),
              ),
              const SizedBox(width: 8),
              CarouselArrowButton(
                icon: Icons.chevron_left_rounded,
                size: _monthArrowSize,
                iconSize: _monthArrowIconSize,
                isDisabled: !_hasPrevious,
                onTap: () => _turn(-1),
              ),
              const SizedBox(width: 6),
              CarouselArrowButton(
                icon: Icons.chevron_right_rounded,
                size: _monthArrowSize,
                iconSize: _monthArrowIconSize,
                isDisabled: !_hasNext,
                onTap: () => _turn(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final initial in kWeekdayInitials)
                Expanded(child: Center(child: Text(initial, style: weekdayStyle))),
            ],
          ),
          const SizedBox(height: 6),
          // Only the days rebuild when marks arrive.
          ValueListenableBuilder<Map<DateTime, DayMarks>>(
            valueListenable: widget.marks,
            builder: (context, all, _)
            {
              final DayMarks marks = all[_month] ?? DayMarks.none;

              return Column(
                children: [
                  for (final week in _weeks(monthGridDays(_month)))
                    Row(
                      children: [
                        for (final day in week)
                          Expanded(
                            child: day == null
                                ? const SizedBox(height: _cellHeight)
                                : _DayCell(
                                    day: day,
                                    enabled: !day.isBefore(_dateOnly(widget.first)) &&
                                        !day.isAfter(_dateOnly(widget.last)),
                                    shown: _isInShown(day),
                                    filled: single,
                                    today: isSameDate(day, today),
                                    closed: marks.closed.contains(day),
                                    busy: marks.busy.contains(day),
                                    onTap: () => widget.onPicked(day),
                                  ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

class _TodayButton extends StatefulWidget
{
  final bool enabled;
  final VoidCallback onTap;

  const _TodayButton({required this.enabled, required this.onTap});

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final bool lit = _isHovered && widget.enabled;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _monthArrowSize,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !widget.enabled
                ? AppTheme.arrowDisabledSurface
                : (lit ? AppTheme.trialTealDeep : Colors.white),
            borderRadius: BorderRadius.circular(_monthArrowSize / 2),
            boxShadow: widget.enabled ? AppTheme.cardShadow : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: !widget.enabled
                  ? AppTheme.trialMutedText.withValues(alpha: 0.5)
                  : (lit ? Colors.white : AppTheme.trialTealDeep),
            ),
            child: const Text(kTodayLabel, maxLines: 1),
          ),
        ),
      ),
    );
  }
}

List<List<DateTime?>> _weeks(List<DateTime?> days)
{
  return [for (var i = 0; i < days.length; i += 7) days.sublist(i, i + 7)];
}

class _DayCell extends StatefulWidget
{
  final DateTime day;
  final bool enabled;

  // Within the day or week on screen: filled when a single day, tinted when a week.
  final bool shown;
  final bool filled;

  final bool today;
  final bool closed;
  final bool busy;

  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.enabled,
    required this.shown,
    required this.filled,
    required this.today,
    required this.closed,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final bool solid = widget.shown && widget.filled;
    final bool tinted = widget.shown && !widget.filled;

    final Color background = solid
        ? AppTheme.trialTealDeep
        : tinted
            ? AppTheme.todaySurface
            : (_isHovered && widget.enabled ? AppTheme.trialGoldSurface : _goldSurfaceClear);

    final Color number = solid
        ? Colors.white
        : !widget.enabled
            ? _disabledDay
            : widget.closed
                ? AppTheme.trialMutedText
                : (tinted ? AppTheme.trialTealDeep : AppTheme.trialInk);

    final Widget cell = SizedBox(
      height: _cellHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: _dayDiameter,
            height: _dayDiameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: widget.today ? Border.all(color: AppTheme.trialGold, width: 2) : null,
            ),
            child: Text(
              '${widget.day.day}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: widget.enabled && !widget.closed ? FontWeight.w700 : FontWeight.w600,
                color: number,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.busy && widget.enabled ? AppTheme.trialTurquoise : Colors.transparent,
            ),
          ),
        ],
      ),
    );

    if (!widget.enabled)
    {
      return cell;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: cell,
      ),
    );
  }
}
