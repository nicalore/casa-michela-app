import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/week_range.dart';
import '../utils/day_marks.dart';
import 'calendar_anchor.dart';
import 'carousel_arrow_button.dart';
import 'desktop_tour.dart';

const double _cellHeight = 44;
const double _dayDiameter = 36;
const double _dotSize = 5;

// Fading from Colors.transparent (black) would pass through grey.
final Color _goldSurfaceClear = AppTheme.trialGoldSurface.withValues(alpha: 0);

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

  // The month's days, for a tour to light; told when the popover comes up and when it goes.
  final String? tourDays;
  final void Function(BuildContext context, bool open)? onOpen;

  final double size;

  const AppCalendarButton({
    super.key,
    required this.selected,
    this.selectedEnd,
    this.today,
    required this.first,
    required this.last,
    required this.onPicked,
    this.loadMarks,
    this.tourDays,
    this.onOpen,
    this.size = CarouselArrowButton.defaultSize,
  });

  @override
  State<AppCalendarButton> createState() => _AppCalendarButtonState();
}

class _AppCalendarButtonState extends State<AppCalendarButton>
{
  // Read on hover, dropped on close so the next opening shows fresh closures.
  final ValueNotifier<Map<DateTime, DayMarks>> _marks = ValueNotifier(const {});
  final Set<DateTime> _reading = {};

  @override
  void dispose()
  {
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

  @override
  Widget build(BuildContext context)
  {
    return CalendarAnchor(
      size: widget.size,
      tooltip: kPickDayLabel,
      onPrefetch: () => _read(DateTime(widget.selected.year, widget.selected.month)),
      onOpen: widget.onOpen,
      onClosed: () => _marks.value = const {},
      popover: (context, close) => _MonthPopover(
        selected: widget.selected,
        selectedEnd: widget.selectedEnd ?? widget.selected,
        first: widget.first,
        last: widget.last,
        today: _dateOnly(widget.today ?? romeNow()),
        marks: _marks,
        tourDays: widget.tourDays,
        onMonth: _read,
        onPicked: (day)
        {
          close();
          widget.onPicked(day);
        },
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

  final String? tourDays;

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
    required this.tourDays,
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
      decoration: kCalendarPopoverDecoration,
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
              CalendarTodayButton(
                enabled: _hasToday,
                onTap: () => widget.onPicked(widget.today),
              ),
              const SizedBox(width: 8),
              CarouselArrowButton(
                icon: Icons.chevron_left_rounded,
                size: kCalendarArrowSize,
                iconSize: kCalendarArrowIconSize,
                isDisabled: !_hasPrevious,
                onTap: () => _turn(-1),
              ),
              const SizedBox(width: 6),
              CarouselArrowButton(
                icon: Icons.chevron_right_rounded,
                size: kCalendarArrowSize,
                iconSize: kCalendarArrowIconSize,
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
          DesktopTourTarget(
            id: widget.tourDays,
            child: ValueListenableBuilder<Map<DateTime, DayMarks>>(
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
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

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
            ? kCalendarDisabled
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
