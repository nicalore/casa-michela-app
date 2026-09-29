import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../lessons/utils/opening_window.dart';
import '../../../lessons/widgets/calendar_lesson_block.dart';
import '../../models/opening_day_item.dart';

const String kClosedLabel = 'Chiuso';

// Not a flag icon: elsewhere a flag means reporting.
const IconData kVariationIcon = Icons.update_rounded;

Widget withReason(String? note, Widget child)
{
  if (note == null)
  {
    return child;
  }

  return Tooltip(message: note, child: child);
}

// Merged with the inherited style as Text does: Material's body letter spacing would wrap the column.
double measureText(BuildContext context, String text, TextStyle style)
{
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();

  final width = painter.width.ceilToDouble();
  painter.dispose();

  return width;
}

class ModeHeading extends StatelessWidget
{
  final String mode;
  final double fontSize;
  final double iconSize;

  const ModeHeading({super.key, required this.mode, this.fontSize = 15, this.iconSize = 20});

  static TextStyle _labelStyle(String mode, double fontSize) => GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: lessonAccent(mode),
      );

  static double widthOf(BuildContext context, String mode, {double fontSize = 15, double iconSize = 20})
  {
    return iconSize * 1.4 + measureText(context, modeLabel(mode), _labelStyle(mode, fontSize));
  }

  @override
  Widget build(BuildContext context)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(lessonModeIcon(mode), size: iconSize, color: lessonAccent(mode)),
        SizedBox(width: iconSize * 0.4),
        Flexible(
          child: Text(
            modeLabel(mode),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(mode, fontSize),
          ),
        ),
      ],
    );
  }
}

class ClosedPill extends StatelessWidget
{
  static const double _padding = 16;

  final bool isOverride;

  final bool expand;

  final String? note;

  const ClosedPill({super.key, required this.isOverride, this.expand = false, this.note});

  static TextStyle _style(bool isOverride) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: isOverride ? FontWeight.w700 : FontWeight.w500,
        color: isOverride ? AppTheme.trialDanger : AppTheme.trialMutedText,
      );

  static double widthOf(BuildContext context, {required bool isOverride})
  {
    return 2 * _padding + measureText(context, kClosedLabel, _style(isOverride));
  }

  @override
  Widget build(BuildContext context)
  {
    return withReason(note, _buildPill());
  }

  Widget _buildPill()
  {
    return Container(
      height: 26,
      padding: expand ? null : const EdgeInsets.symmetric(horizontal: _padding),
      decoration: BoxDecoration(
        color: isOverride ? AppTheme.closedOverrideSurface : AppTheme.closedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      // widthFactor keeps a hugging pill from taking the whole column.
      child: Center(
        widthFactor: expand ? null : 1,
        child: Text(kClosedLabel, style: _style(isOverride)),
      ),
    );
  }
}

class BandTimes extends StatelessWidget
{
  static const double _spacing = 22;
  static const double _markGap = 4;

  // Kept small: a mark must not cost the week its seven columns.
  static double _markSize(double fontSize) => (fontSize * 0.85).roundToDouble();

  final List<OpeningDayItem> bands;
  final double fontSize;
  final FontWeight fontWeight;

  final bool stacked;

  final bool markVariations;

  final String? variationNote;

  const BandTimes({
    super.key,
    required this.bands,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.stacked = false,
    this.markVariations = true,
    this.variationNote,
  });

  static String _label(OpeningDayItem band) => formatTimeRange(band.startTime!, band.endTime!);

  static TextStyle _style(OpeningDayItem band, double fontSize, FontWeight fontWeight)
  {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: lessonAccent(band.mode),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static double widthOf(
    BuildContext context,
    List<OpeningDayItem> bands, {
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    bool stacked = false,
    bool markVariations = true,
  })
  {
    final widths = [
      for (final band in bands)
        measureText(context, _label(band), _style(band, fontSize, fontWeight)) +
            (markVariations && band.isOverride ? _markGap + _markSize(fontSize) : 0),
    ];

    if (widths.isEmpty)
    {
      return 0;
    }

    return stacked ? widths.reduce(math.max) : widths.reduce((a, b) => a + b) + _spacing * (widths.length - 1);
  }

  @override
  Widget build(BuildContext context)
  {
    final times = <Widget>[
      for (final band in bands)
        if (markVariations && band.isOverride)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_label(band), maxLines: 1, softWrap: false, style: _style(band, fontSize, fontWeight)),
              const SizedBox(width: _markGap),
              withReason(
                variationNote,
                Icon(kVariationIcon, size: _markSize(fontSize), color: lessonAccent(band.mode)),
              ),
            ],
          )
        else
          Text(_label(band), maxLines: 1, softWrap: false, style: _style(band, fontSize, fontWeight)),
    ];

    if (stacked)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < times.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            times[i],
          ],
        ],
      );
    }

    return Wrap(spacing: _spacing, runSpacing: 4, children: times);
  }
}

class VariationNote extends StatelessWidget
{
  final String note;
  final int maxLines;

  const VariationNote(this.note, {super.key, this.maxLines = 1});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.sticky_note_2_outlined, size: 15, color: AppTheme.trialMutedText),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: OverflowTooltipText(
            text: note,
            maxLines: maxLines,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
      ],
    );
  }
}
