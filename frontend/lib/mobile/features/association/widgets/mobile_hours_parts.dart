import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/opening_day_item.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/association/tabs/opening_hours/mode_hours_parts.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';

Color hoursInk(String mode, {bool past = false}) => past ? MobilePalette.mutedText : lessonAccent(mode);

String bandHours(OpeningDayItem band) => formatTimeRange(band.startTime!, band.endTime!);

// The mode is always written out, never left to a colour.
class MobileModeLabel extends StatelessWidget
{
  final String mode;
  final double fontSize;
  final double iconSize;
  final bool past;

  const MobileModeLabel({
    super.key,
    required this.mode,
    required this.fontSize,
    required this.iconSize,
    this.past = false,
  });

  static TextStyle _style(double fontSize, Color color)
  {
    return GoogleFonts.plusJakartaSans(fontSize: fontSize, fontWeight: FontWeight.w700, color: color);
  }

  static double _gap(double iconSize) => (iconSize * 0.35).roundToDouble();

  // The wider of the two, so the hours after them start level.
  static double widthOf(BuildContext context, {required double fontSize, required double iconSize})
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle ambient = DefaultTextStyle.of(context).style;

    return kHoursModes.map((mode)
    {
      final painter = TextPainter(
        text: TextSpan(text: modeLabel(mode), style: ambient.merge(_style(fontSize, Colors.black))),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      final double width = painter.width;
      painter.dispose();

      return iconSize + _gap(iconSize) + width;
    }).reduce(math.max).ceilToDouble();
  }

  @override
  Widget build(BuildContext context)
  {
    final Color ink = hoursInk(mode, past: past);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(lessonModeIcon(mode), size: iconSize, color: ink),
        SizedBox(width: _gap(iconSize)),
        Flexible(
          child: Text(
            modeLabel(mode),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: _style(fontSize, ink),
          ),
        ),
      ],
    );
  }
}

class MobileHoursChip extends StatelessWidget
{
  final OpeningDayItem band;
  final bool tablet;

  const MobileHoursChip({super.key, required this.band, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final bool online = band.mode == kOnlineMode;
    final Color ink = hoursInk(band.mode);
    final double fontSize = tablet ? 13 : 12.5;

    return Container(
      height: tablet ? 30 : 26,
      padding: EdgeInsets.symmetric(horizontal: tablet ? 10 : 9),
      decoration: BoxDecoration(
        color: online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: online ? AppTheme.trialGold.withValues(alpha: 0.45) : AppTheme.trialTealDeep.withValues(alpha: 0.2),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          bandHours(band),
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            color: ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// Red for a decided closure (holiday, works), grey where the mode never opens.
class MobileClosedTag extends StatelessWidget
{
  final bool decided;
  final double fontSize;
  final double height;

  const MobileClosedTag({super.key, required this.decided, required this.fontSize, required this.height});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.42),
      decoration: BoxDecoration(
        color: decided ? AppTheme.closedOverrideSurface : AppTheme.closedSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(height * 0.3),
        border: Border.all(
          color: decided ? AppTheme.trialDanger.withValues(alpha: 0.32) : MobilePalette.mutedText.withValues(alpha: 0.14),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          kClosedLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: decided ? FontWeight.w800 : FontWeight.w600,
            color: decided ? AppTheme.trialDanger : MobilePalette.mutedText,
          ),
        ),
      ),
    );
  }
}

// Written out: there is no hover on a phone.
class MobileHoursNote extends StatelessWidget
{
  final String note;
  final double fontSize;

  const MobileHoursNote({super.key, required this.note, required this.fontSize});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.sticky_note_2_outlined, size: fontSize + 2.5, color: MobilePalette.mutedText),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            note,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.35,
              color: MobilePalette.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

class MobileHoursRule extends StatelessWidget
{
  final double gap;

  const MobileHoursRule({super.key, required this.gap});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: gap),
      color: AppTheme.trialInk.withValues(alpha: 0.1),
    );
  }
}
