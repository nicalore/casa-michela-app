import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/association/tabs/opening_hours/mode_hours_parts.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';
import 'mobile_hours_parts.dart';

const double _radius = 22;

class MobileHoursDayCard extends StatelessWidget
{
  final CombinedDay day;
  final DateTime today;
  final bool tablet;

  final bool sideBySide;

  const MobileHoursDayCard({
    super.key,
    required this.day,
    required this.today,
    required this.tablet,
    this.sideBySide = false,
  });

  bool get _past => day.date.isBefore(today);

  String get _title
  {
    final String label = formatWeekdayColumnLabel(day.date);

    return day.date.year == today.year ? label : '$label ${day.date.year}';
  }

  // A day shut in both modes shows one «Chiuso», so both reasons go under it.
  String? get _allDayNote
  {
    final notes = <String>[];

    for (final mode in kHoursModes)
    {
      final String? note = day.of(mode).note;

      if (note != null && !notes.contains(note))
      {
        notes.add(note);
      }
    }

    return notes.isEmpty ? null : notes.join(' · ');
  }

  Widget _buildTitle()
  {
    return Row(
      children: [
        Flexible(
          child: Text(
            _title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 21 : 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.2,
              color: _past ? MobilePalette.mutedText : AppTheme.trialInk,
            ),
          ),
        ),
        if (isSameDate(day.date, today)) ...[
          const SizedBox(width: 10),
          const MobilePill('Oggi', tone: MobilePillTone.teal),
        ],
      ],
    );
  }

  Widget _buildClosed({required bool decided})
  {
    return MobileClosedTag(decided: decided, fontSize: tablet ? 17 : 16, height: tablet ? 36 : 34);
  }

  Widget _buildNote(String note)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MobileHoursNote(note: note, fontSize: tablet ? 14 : 13.5),
    );
  }

  Widget _buildMode(String mode)
  {
    final ModeDayHours hours = day.of(mode);
    final String? note = hours.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobileModeLabel(mode: mode, fontSize: tablet ? 15 : 14, iconSize: tablet ? 20 : 18, past: _past),
        const SizedBox(height: 8),
        if (hours.isClosed)
          _buildClosed(decided: hours.isOverrideClosure)
        else
          for (final band in hours.bands)
            // Shrinks rather than wraps under large system text.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bandHours(band),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: tablet ? 30 : 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.25,
                      color: hoursInk(mode, past: _past),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (band.isOverride) ...[
                    const SizedBox(width: 6),
                    Icon(kVariationIcon, size: tablet ? 18 : 16, color: hoursInk(mode, past: _past)),
                  ],
                ],
              ),
            ),
        if (note != null) _buildNote(note),
      ],
    );
  }

  Widget _buildModes()
  {
    // Both modes shut for the same reason: one «Chiuso», like the desktop's merged cell.
    if (day.isClosedAllDay)
    {
      final String? note = _allDayNote;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_rounded, size: tablet ? 22 : 20, color: MobilePalette.mutedText),
              const SizedBox(width: 10),
              _buildClosed(decided: day.isOverrideClosedAllDay),
            ],
          ),
          if (note != null) _buildNote(note),
        ],
      );
    }

    if (sideBySide)
    {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, mode) in kHoursModes.indexed) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(child: _buildMode(mode)),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, mode) in kHoursModes.indexed) ...[
          if (i > 0) const MobileHoursRule(gap: 13),
          _buildMode(mode),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 20, 24, 20) : const EdgeInsets.fromLTRB(20, 16, 20, 16),
      borderRadius: BorderRadius.circular(_radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(),
          const MobileHoursRule(gap: 13),
          _buildModes(),
        ],
      ),
    );
  }
}
