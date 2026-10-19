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
import '../../../shared/widgets/mobile_tour.dart';
import 'mobile_hours_parts.dart';

const double _columnGap = 14;

const EdgeInsets _tourMarkInflate = EdgeInsets.all(5);
const double _tourMarkRadius = 14;
const double _headingGap = 5;

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

  TextStyle _headingStyle(String mode) => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 10.5 : 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: hoursInk(mode),
      );

  double get _headingIconSize => tablet ? 16 : 15;

  // Whether each mode's label fits beside its icon in a table [width] wide.
  bool headingsFit(BuildContext context, {required double width, required double labelWidth})
  {
    final double column = (width - labelWidth - 2 * _columnGap) / 2;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle ambient = DefaultTextStyle.of(context).style;

    return kHoursModes.every((mode)
    {
      final painter = TextPainter(
        text: TextSpan(text: modeLabel(mode).toUpperCase(), style: ambient.merge(_headingStyle(mode))),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      final double needed = _headingIconSize + _headingGap + painter.width;
      painter.dispose();

      return needed <= column;
    });
  }

  // [inline] off on a narrow phone: the icon stands over its label, in both columns alike.
  Widget head(double labelWidth, {bool inline = true})
  {
    Widget heading(String mode)
    {
      final Widget icon = Icon(lessonModeIcon(mode), size: _headingIconSize, color: hoursInk(mode));
      final Widget text = Text(modeLabel(mode).toUpperCase(), maxLines: 2, style: _headingStyle(mode));

      return Expanded(
        child: inline
            ? Row(children: [icon, const SizedBox(width: _headingGap), Flexible(child: text)])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [icon, const SizedBox(height: 3), text],
              ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  // [marked] off when the mark stands by its reason instead; [tourMark] lights the first mark.
  Widget bands(String mode, List<OpeningDayItem> bands, {bool past = false, bool marked = true, String? tourMark})
  {
    final int first = bands.indexWhere((band) => band.isOverride);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, band) in bands.indexed)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bandHours(band), maxLines: 1, style: hoursStyle(mode, past: past)),
                if (marked && band.isOverride) ...[
                  const SizedBox(width: 5),
                  MobileTourTarget(
                    id: i == first ? tourMark : null,
                    inflate: _tourMarkInflate,
                    radius: _tourMarkRadius,
                    child: Icon(kVariationIcon, size: tablet ? 15 : 14, color: hoursInk(mode, past: past)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
