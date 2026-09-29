import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_hours_parts.dart';

const Duration _selectDuration = Duration(milliseconds: 220);

const double _gap = 6;
const double _radius = 16;
const double _dotSize = 7;
const double _dotGap = 4;
const double _ringWidth = 1.5;

const List<BoxShadow> _liftedShadow = [
  BoxShadow(color: Color(0x38000000), offset: Offset(0, 10), blurRadius: 24),
];

// Same length as the lifted one, so the shadow fades rather than jumps.
const List<BoxShadow> _flatShadow = [
  BoxShadow(color: Color(0x00000000), offset: Offset(0, 10), blurRadius: 24),
];

// Dots per day, presence then online: filled when open, hollow for any closure.
class MobileWeekRibbon extends StatelessWidget
{
  final List<CombinedDay> days;
  final DateTime selected;
  final DateTime today;

  // Days outside are not kept or not generated yet.
  final DateTime first;
  final DateTime last;

  final bool tablet;
  final ValueChanged<DateTime> onSelect;

  const MobileWeekRibbon({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.first,
    required this.last,
    required this.tablet,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context)
  {
    return Row(
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(
            child: _DayCell(
              day: day,
              selected: isSameDate(day.date, selected),
              today: isSameDate(day.date, today),
              past: day.date.isBefore(today),
              enabled: !day.date.isBefore(first) && !day.date.isAfter(last),
              tablet: tablet,
              onTap: () => onSelect(day.date),
            ),
          ),
        ],
      ],
    );
  }
}

enum _DotState { open, shut, unknown }

class _DayCell extends StatelessWidget
{
  final CombinedDay day;
  final bool selected;
  final bool today;
  final bool past;
  final bool enabled;
  final bool tablet;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.past,
    required this.enabled,
    required this.tablet,
    required this.onTap,
  });

  // Unknown while the week loads: no rows yet says nothing either way.
  _DotState _stateOf(String mode)
  {
    final hours = day.of(mode);

    if (hours.isClosed)
    {
      return _DotState.shut;
    }

    return hours.bands.isEmpty ? _DotState.unknown : _DotState.open;
  }

  Color _numberColor()
  {
    if (!enabled)
    {
      return Colors.white.withValues(alpha: 0.26);
    }

    if (selected)
    {
      return past ? MobilePalette.mutedText : AppTheme.trialInk;
    }

    return past ? Colors.white.withValues(alpha: 0.6) : Colors.white;
  }

  Widget _buildDot(String mode)
  {
    final _DotState state = enabled ? _stateOf(mode) : _DotState.unknown;
    final Color onSea = mode == kOnlineMode ? MobilePalette.onlineOnSea : MobilePalette.presenceOnSea;

    final Color fill = state == _DotState.open ? (selected ? hoursInk(mode) : onSea) : Colors.transparent;
    final Color ring = state == _DotState.shut
        ? (selected ? MobilePalette.mutedText.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.55))
        : Colors.transparent;

    return AnimatedContainer(
      duration: _selectDuration,
      width: _dotSize,
      height: _dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: ring, width: _ringWidth),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final BorderRadius radius = BorderRadius.circular(_radius);

    final Widget cell = AnimatedContainer(
      duration: _selectDuration,
      curve: Curves.easeOutCubic,
      height: tablet ? 76 : 66,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: selected ? MobileGlassPanel.cardAlpha : 0.12),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.62 : 0.24)),
        boxShadow: selected ? _liftedShadow : _flatShadow,
      ),
      foregroundDecoration: today
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: MobilePalette.currentRim,
                width: MobilePalette.currentRimWidth,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            )
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: _selectDuration,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 11 : 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: selected ? MobilePalette.mutedText : Colors.white.withValues(alpha: enabled ? 0.72 : 0.26),
              ),
              child: Text(kWeekdayInitials[day.date.weekday - 1]),
            ),
            AnimatedDefaultTextStyle(
              duration: _selectDuration,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 22 : 19,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: _numberColor(),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              child: Text('${day.date.day}'),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(kHoursModes.first),
                const SizedBox(width: _dotGap),
                _buildDot(kHoursModes.last),
              ],
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: enabled,
      selected: selected,
      label: formatWeekdayColumnLabel(day.date),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: cell,
      ),
    );
  }
}
