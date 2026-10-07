import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/models/opening_day_item.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/association/tabs/opening_hours/mode_hours_parts.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import 'mobile_hours_parts.dart';

const double _columnGap = 14;

class MobileHoursTable
{
  final bool tablet;

  const MobileHoursTable({required this.tablet});

  EdgeInsets get padding => tablet ? const EdgeInsets.fromLTRB(20, 16, 20, 8) : const EdgeInsets.fromLTRB(18, 14, 18, 6);

  TextStyle labelStyle({bool past = false}) => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 15.5 : 14.5,
        fontWeight: FontWeight.w700,
        height: 1.45,
        color: past ? MobilePalette.mutedText : AppTheme.trialInk,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle closedStyle({bool decided = false}) => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 15 : 14,
        fontWeight: decided ? FontWeight.w800 : FontWeight.w600,
        height: 1.45,
        color: decided ? AppTheme.trialDanger : MobilePalette.mutedText,
      );

  // Largest a phone column takes at default text size; the fit shrinks it beyond.
  TextStyle hoursStyle(String mode, {bool past = false}) => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 18 : 17,
        fontWeight: FontWeight.w800,
        height: 1.45,
        color: hoursInk(mode, past: past),
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  double labelWidth(BuildContext context, Iterable<String> labels)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle style = DefaultTextStyle.of(context).style.merge(labelStyle());

    double widest = 0;

    for (final label in labels)
    {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    return widest.ceilToDouble();
  }

  Widget head(double labelWidth)
  {
    Widget heading(String mode)
    {
      return Expanded(
        child: Row(
          children: [
            Icon(lessonModeIcon(mode), size: tablet ? 16 : 15, color: hoursInk(mode)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                modeLabel(mode).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: tablet ? 10.5 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: hoursInk(mode),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        children: [
          SizedBox(width: labelWidth),
          const SizedBox(width: _columnGap),
          heading(kHoursModes.first),
          const SizedBox(width: _columnGap),
          heading(kHoursModes.last),
        ],
      ),
    );
  }

  Widget rule({bool strong = false, bool hidden = false})
  {
    return Container(
      height: 1,
      color: hidden ? null : AppTheme.trialInk.withValues(alpha: strong ? 0.1 : 0.08),
    );
  }

  // One cell spans both modes; first-baseline aligned, as the hours outsize the label.
  Widget row({required double labelWidth, required Widget label, required List<Widget> cells, Widget? below})
  {
    final Widget line = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: labelWidth, child: label),
        const SizedBox(width: _columnGap),
        if (cells.length == 1)
          Expanded(child: cells.single)
        else ...[
          Expanded(child: cells.first),
          const SizedBox(width: _columnGap),
          Expanded(child: cells.last),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tablet ? 11 : 10),
      child: below == null
          ? line
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line,
                Padding(padding: EdgeInsets.only(left: labelWidth + _columnGap, top: 6), child: below),
              ],
            ),
    );
  }

  Widget label(String text, {bool past = false}) => Text(text, maxLines: 1, style: labelStyle(past: past));

  Widget closed({bool decided = false}) => Text(kClosedLabel, style: closedStyle(decided: decided));

  // [marked] off when the variation's mark stands by its reason instead.
  Widget bands(String mode, List<OpeningDayItem> bands, {bool past = false, bool marked = true})
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final band in bands)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bandHours(band), maxLines: 1, style: hoursStyle(mode, past: past)),
                if (marked && band.isOverride) ...[
                  const SizedBox(width: 5),
                  Icon(kVariationIcon, size: tablet ? 15 : 14, color: hoursInk(mode, past: past)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
