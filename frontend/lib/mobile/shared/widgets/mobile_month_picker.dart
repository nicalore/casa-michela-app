import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/utils/day_marks.dart';
import '../mobile_palette.dart';
import 'mobile_sheet.dart';

const double _rowHeight = 48;
const double _dayDiameter = 38;
const double _dotSize = 5;
const double _arrowSize = 36;

const Color _disabledDay = Color(0xFFA9B6BE);
const Color _closedDay = Color(0xFF7F909B);

const Duration _turnDuration = Duration(milliseconds: 300);

Future<DateTime?> showMobileMonthPicker({
  required BuildContext context,
  required DateTime selected,
  required DateTime today,
  required DateTime first,
  required DateTime last,
  DayMarksLoader? loadMarks,
})
{
  return showMobileSheet<DateTime>(
    context: context,
    builder: (context) => _MonthPicker(
      selected: _dateOnly(selected),
      today: _dateOnly(today),
      first: _dateOnly(first),
      last: _dateOnly(last),
      loadMarks: loadMarks,
    ),
  );
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

int _monthsBetween(DateTime from, DateTime to) => (to.year - from.year) * 12 + to.month - from.month;

class _MonthPicker extends StatefulWidget
{
  final DateTime selected;
  final DateTime today;
  final DateTime first;
  final DateTime last;
  final DayMarksLoader? loadMarks;

  const _MonthPicker({
    required this.selected,
    required this.today,
    required this.first,
    required this.last,
    required this.loadMarks,
  });

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker>
{
  late final int _count = _monthsBetween(widget.first, widget.last) + 1;

  late int _index = _monthsBetween(widget.first, widget.selected).clamp(0, _count - 1);

  late final PageController _pages = PageController(initialPage: _index);

  // Read once per month while the sheet is up.
  final Map<DateTime, DayMarks> _marks = {};

  @override
  void initState()
  {
    super.initState();
    _read(_monthAt(_index));
  }

  @override
  void dispose()
  {
    _pages.dispose();
    super.dispose();
  }

  DateTime _monthAt(int index) => DateTime(widget.first.year, widget.first.month + index);

  Future<void> _read(DateTime month) async
  {
    final loader = widget.loadMarks;

    if (loader == null || _marks.containsKey(month))
    {
      return;
    }

    _marks[month] = DayMarks.none;

    final marks = await loader(month, DateTime(month.year, month.month + 1, 0));

    if (mounted)
    {
      setState(() => _marks[month] = marks);
    }
  }

  void _turn(int by)
  {
    _pages.animateToPage(_index + by, duration: _turnDuration, curve: Curves.easeInOutCubic);
  }

  Widget _buildArrows()
  {
    Widget arrow(IconData icon, bool enabled, int by)
    {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _turn(by) : null,
        child: Container(
          width: _arrowSize,
          height: _arrowSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.trialInk.withValues(alpha: 0.06),
          ),
          child: Icon(
            icon,
            size: 24,
            color: enabled ? AppTheme.trialTealDeep : AppTheme.trialInk.withValues(alpha: 0.22),
          ),
        ),
      );
    }

    final bool hasToday = !widget.today.isBefore(widget.first) && !widget.today.isAfter(widget.last);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Semantics(
            button: true,
            enabled: hasToday,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasToday ? () => finishMobileSheet(context, widget.today) : null,
              child: Container(
                height: _arrowSize,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_arrowSize / 2),
                  color: AppTheme.trialInk.withValues(alpha: 0.06),
                ),
                child: Text(
                  kTodayLabel.toUpperCase(),
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: hasToday ? AppTheme.trialTealDeep : AppTheme.trialInk.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          arrow(Icons.chevron_left_rounded, _index > 0, -1),
          const SizedBox(width: 8),
          arrow(Icons.chevron_right_rounded, _index < _count - 1, 1),
        ],
      ),
    );
  }

  Widget _buildMonth(DateTime month)
  {
    final DayMarks marks = _marks[month] ?? DayMarks.none;
    final List<DateTime?> days = monthGridDays(month);

    return Column(
      children: [
        for (var week = 0; week < 6; week++)
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                for (final day in days.sublist(week * 7, week * 7 + 7))
                  Expanded(
                    child: day == null
                        ? const SizedBox.shrink()
                        : _DayCell(
                            day: day,
                            enabled: !day.isBefore(widget.first) && !day.isAfter(widget.last),
                            selected: isSameDate(day, widget.selected),
                            today: isSameDate(day, widget.today),
                            closed: marks.closed.contains(day),
                            busy: marks.busy.contains(day),
                            onTap: () => finishMobileSheet(context, day),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle weekdayStyle = GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: MobilePalette.mutedText,
    );

    return MobileSheet(
      eyebrow: kPickDayLabel,
      title: formatMonthYear(_monthAt(_index)),
      subhead: _buildArrows(),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding - 4, 14, MobileSheet.sidePadding - 4, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final initial in kWeekdayInitials)
                  Expanded(child: Center(child: Text(initial, style: weekdayStyle))),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 6 * _rowHeight,
              child: PageView.builder(
                controller: _pages,
                itemCount: _count,
                onPageChanged: (index)
                {
                  setState(() => _index = index);
                  _read(_monthAt(index));
                },
                itemBuilder: (context, index) => _buildMonth(_monthAt(index)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget
{
  final DateTime day;
  final bool enabled;
  final bool selected;
  final bool today;
  final bool closed;
  final bool busy;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.enabled,
    required this.selected,
    required this.today,
    required this.closed,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color number = selected
        ? Colors.white
        : !enabled
            ? _disabledDay
            : (closed ? _closedDay : AppTheme.trialInk);

    final Widget cell = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: _dayDiameter,
          height: _dayDiameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppTheme.trialTealDeep : null,
            border: today
                ? Border.all(
                    color: MobilePalette.currentRim,
                    width: MobilePalette.currentRimWidth,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  )
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${day.day}',
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: enabled && !closed ? FontWeight.w700 : FontWeight.w600,
                color: number,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy && enabled ? AppTheme.trialTurquoise : Colors.transparent,
          ),
        ),
      ],
    );

    if (!enabled)
    {
      return cell;
    }

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: cell),
    );
  }
}
