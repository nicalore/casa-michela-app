import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/availability/utils/availability_strings.dart';
import '../../../shared/mobile_palette.dart';
import '../mobile_availability_draft.dart';

const double _gap = 6;
const double _radius = 14;
const double _border = 1.5;

const Duration _move = Duration(milliseconds: 200);

// Today up to the last unlocked Sunday; an unpickable day says why when touched.
class MobileDayPicker extends StatelessWidget
{
  final MobileAvailabilityDraft draft;

  // The unpickable day last touched, whose reason shows under the rows.
  final DateTime? refused;

  final ValueChanged<DateTime> onToggle;
  final ValueChanged<DateTime> onRefused;

  const MobileDayPicker({
    super.key,
    required this.draft,
    required this.refused,
    required this.onToggle,
    required this.onRefused,
  });

  List<DateTime> get _mondays
  {
    final List<DateTime> mondays = [];

    for (final day in draft.availableDays)
    {
      final DateTime monday = startOfWeek(day);

      if (!mondays.any((known) => isSameDate(known, monday)))
      {
        mondays.add(monday);
      }
    }

    return mondays;
  }

  Widget _buildWeek(DateTime monday)
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
                Expanded(child: _buildTile(day)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(DateTime day)
  {
    final bool listed = draft.availableDays.any((available) => isSameDate(available, day));
    final bool offered = listed && draft.isOffered(day);
    final bool picked = offered && draft.isPicked(day);
    final bool touched = refused != null && isSameDate(refused!, day);

    final Color fill = picked
        ? AppTheme.trialTealDeep
        : (offered ? Colors.white : AppTheme.trialInk.withValues(alpha: 0.04));
    final Color edge = picked
        ? AppTheme.trialTealDeep
        : (touched
            ? AppTheme.trialGold
            : (offered ? AppTheme.trialInk.withValues(alpha: 0.12) : AppTheme.trialInk.withValues(alpha: 0)));
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
        color: fill,
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
        onTap: () => offered ? onToggle(day) : onRefused(day),
        child: tile,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime? refused = this.refused;
    final int count = draft.days.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final monday in _mondays) _buildWeek(monday),
        AnimatedSize(
          duration: _move,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refused != null) _Rise(child: _Refusal(text: draft.refusalFor(refused))),
              if (count > 1)
                _Rise(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      availabilityDaysSummary(count, split: draft.groups.length > 1),
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

class _Refusal extends StatelessWidget
{
  final String text;

  const _Refusal({required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.trialGoldSurface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppTheme.trialGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 17, color: AppTheme.modifiedAccent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppTheme.modifiedAccent,
              ),
            ),
          ),
        ],
      ),
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
