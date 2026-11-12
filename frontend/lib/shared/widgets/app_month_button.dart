import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/rome_clock.dart';
import 'calendar_anchor.dart';
import 'carousel_arrow_button.dart';

const String kPickMonthLabel = 'Scegli il mese';

const List<String> _monthNames = [
  'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
  'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
];

const int _monthsPerRow = 4;

const double _cellHeight = 52;
const double _cellRadius = 16;
const double _cellGap = 8;
const double _dotSize = 5;

// Fading from Colors.transparent (black) would pass through grey.
final Color _goldSurfaceClear = AppTheme.trialGoldSurface.withValues(alpha: 0);

// As AppCalendarButton, with the twelve months of a year instead of the days of a month.
class AppMonthButton extends StatelessWidget
{
  final DateTime selected;

  final DateTime first;
  final DateTime last;

  final ValueChanged<DateTime> onPicked;

  // Dotted, by their first day.
  final Set<DateTime> marked;

  final double size;

  // False where the button stands away from the page's left edge: the popover centres on it.
  final bool startAligned;

  const AppMonthButton({
    super.key,
    required this.selected,
    required this.first,
    required this.last,
    required this.onPicked,
    this.marked = const {},
    this.size = CarouselArrowButton.defaultSize,
    this.startAligned = true,
  });

  @override
  Widget build(BuildContext context)
  {
    return CalendarAnchor(
      size: size,
      tooltip: kPickMonthLabel,
      startAligned: startAligned,
      popover: (context, close) => _YearPopover(
        selected: selected,
        first: first,
        last: last,
        marked: marked,
        onPicked: (month)
        {
          close();
          onPicked(month);
        },
      ),
    );
  }
}

class _YearPopover extends StatefulWidget
{
  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final Set<DateTime> marked;
  final ValueChanged<DateTime> onPicked;

  const _YearPopover({
    required this.selected,
    required this.first,
    required this.last,
    required this.marked,
    required this.onPicked,
  });

  @override
  State<_YearPopover> createState() => _YearPopoverState();
}

class _YearPopoverState extends State<_YearPopover>
{
  late int _year = widget.selected.year;

  late final DateTime _now = romeNow();

  DateTime get _firstMonth => DateTime(widget.first.year, widget.first.month);

  DateTime get _lastMonth => DateTime(widget.last.year, widget.last.month);

  bool _reachable(DateTime month) => !month.isBefore(_firstMonth) && !month.isAfter(_lastMonth);

  @override
  Widget build(BuildContext context)
  {
    final DateTime shown = DateTime(widget.selected.year, widget.selected.month);
    final DateTime current = DateTime(_now.year, _now.month);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: kCalendarPopoverDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_year',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              CalendarTodayButton(
                enabled: _reachable(current),
                onTap: () => widget.onPicked(current),
              ),
              const SizedBox(width: 8),
              CarouselArrowButton(
                icon: Icons.chevron_left_rounded,
                size: kCalendarArrowSize,
                iconSize: kCalendarArrowIconSize,
                isDisabled: _year <= _firstMonth.year,
                onTap: () => setState(() => _year--),
              ),
              const SizedBox(width: 6),
              CarouselArrowButton(
                icon: Icons.chevron_right_rounded,
                size: kCalendarArrowSize,
                iconSize: kCalendarArrowIconSize,
                isDisabled: _year >= _lastMonth.year,
                onTap: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var row = 0; row < _monthNames.length; row += _monthsPerRow) ...[
            if (row > 0) const SizedBox(height: _cellGap),
            Row(
              children: [
                for (var column = 0; column < _monthsPerRow; column++) ...[
                  if (column > 0) const SizedBox(width: _cellGap),
                  Expanded(child: _cell(DateTime(_year, row + column + 1), shown, current)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(DateTime month, DateTime shown, DateTime current)
  {
    return _MonthCell(
      label: _monthNames[month.month - 1],
      enabled: _reachable(month),
      selected: month == shown,
      current: month == current,
      marked: widget.marked.contains(month),
      onTap: () => widget.onPicked(month),
    );
  }
}

class _MonthCell extends StatefulWidget
{
  final String label;
  final bool enabled;
  final bool selected;
  final bool current;
  final bool marked;
  final VoidCallback onTap;

  const _MonthCell({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.current,
    required this.marked,
    required this.onTap,
  });

  @override
  State<_MonthCell> createState() => _MonthCellState();
}

class _MonthCellState extends State<_MonthCell>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final bool selected = widget.selected;

    final Color background = selected
        ? AppTheme.trialTealDeep
        : (_isHovered && widget.enabled ? AppTheme.trialGoldSurface : _goldSurfaceClear);

    final Color text = selected
        ? Colors.white
        : (widget.enabled ? AppTheme.trialInk : kCalendarDisabled);

    final Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: _cellHeight,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_cellRadius),
        border: widget.current ? Border.all(color: AppTheme.trialGold, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: _dotSize + 2),
          Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: widget.enabled ? FontWeight.w700 : FontWeight.w600,
              color: text,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !widget.marked || !widget.enabled
                  ? Colors.transparent
                  : (selected ? Colors.white : AppTheme.trialTurquoise),
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
