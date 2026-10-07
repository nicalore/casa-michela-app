import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../mobile_palette.dart';
import 'mobile_notice.dart';
import 'mobile_select_parts.dart';

const double _gap = 6;
const double _radius = 14;
const double _border = 1.5;

const Duration _move = Duration(milliseconds: 200);

class MobileDayPicker extends StatelessWidget
{
  // Today up to the last unlocked Sunday.
  final List<DateTime> days;

  final bool Function(DateTime day) isOffered;
  final bool Function(DateTime day) isPicked;
  final String Function(DateTime day) refusalFor;

  final String? summary;

  final ValueChanged<DateTime> onToggle;

  const MobileDayPicker({
    super.key,
    required this.days,
    required this.isOffered,
    required this.isPicked,
    required this.refusalFor,
    this.summary,
    required this.onToggle,
  });

  List<DateTime> get _mondays
  {
    final List<DateTime> mondays = [];

    for (final day in days)
    {
      final DateTime monday = startOfWeek(day);

      if (!mondays.any((known) => isSameDate(known, monday)))
      {
        mondays.add(monday);
      }
    }

    return mondays;
  }

  Widget _buildWeek(BuildContext context, DateTime monday)
  {
    final List<DateTime> week = daysOfWeek(monday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            formatDateSpan(week.first, week.last).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: MobilePalette.mutedText,
            ),
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, day) in week.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: _buildTile(context, day)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(BuildContext context, DateTime day)
  {
    final bool listed = days.any((available) => isSameDate(available, day));
    final bool offered = listed && isOffered(day);
    final bool picked = offered && isPicked(day);

    final Color rest = offered ? Colors.white : AppTheme.trialInk.withValues(alpha: 0.04);
    final Color edge = picked
        ? AppTheme.trialTealDeep.withValues(alpha: 0)
        : (offered ? AppTheme.trialInk.withValues(alpha: 0.12) : AppTheme.trialInk.withValues(alpha: 0));
    final Color weekday = picked
        ? Colors.white.withValues(alpha: 0.8)
        : (offered ? MobilePalette.mutedText : AppTheme.trialInk.withValues(alpha: 0.3));
    final Color number = picked
        ? Colors.white
        : (offered ? AppTheme.trialInk : AppTheme.trialInk.withValues(alpha: 0.3));

    final Widget tile = AnimatedContainer(
      duration: _move,
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        gradient: mobileSelectFill(rest, picked ? 1 : 0),
        borderRadius: BorderRadius.circular(_radius),
        // One width for every state: a thicker edge would push the day down.
        border: Border.all(color: edge, width: _border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedDefaultTextStyle(
            duration: _move,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: weekday,
              decoration: offered ? null : TextDecoration.lineThrough,
              decorationThickness: MobilePalette.strikeThickness,
              decorationColor: weekday,
            ),
            child: Text(weekdayShortName(day.weekday).toUpperCase(), maxLines: 1),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: _move,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: number,
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: offered ? null : TextDecoration.lineThrough,
                decorationThickness: MobilePalette.strikeThickness,
                decorationColor: number,
              ),
              child: Text('${day.day}'),
            ),
          ),
        ],
      ),
    );

    // Days before today keep their place in the row, unseen.
    if (!listed)
    {
      return Visibility.maintain(visible: false, child: tile);
    }

    return Semantics(
      button: true,
      selected: picked,
      enabled: offered,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => offered ? onToggle(day) : MobileNotice.show(context, refusalFor(day), error: true),
        child: tile,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? summary = this.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final monday in _mondays) _buildWeek(context, monday),
        AnimatedSize(
          duration: _move,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null)
                _Rise(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      summary,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: MobilePalette.mutedText,
                      ),
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

class _Rise extends StatelessWidget
{
  final Widget child;

  const _Rise({required this.child});

  @override
  Widget build(BuildContext context)
  {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _move,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      child: child,
    );
  }
}
