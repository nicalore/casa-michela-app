import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/calendar/utils/calendar_strings.dart';
import '../../../../features/calendar/utils/teacher_band_call.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

const double _radius = 22;

const double _ruleGap = 13;
const double _figureGap = 12;
const double _chipGap = 8;

// Chips shrink this far before wrapping: a phone card fits a room and the supervisor's.
const double _minChipScale = 0.8;

const EdgeInsets _chipPadding = EdgeInsets.fromLTRB(9, 4, 12, 4);
const double _chipBorder = 1.4;
const double _chipIcon = 17;
const double _chipIconGap = 6;

// Each figure's share of a stretched card.
const double _stretchedFigureWidth = 96;

class MobileConvocationCard extends StatelessWidget
{
  final TeacherBandCall call;
  final bool feminine;
  final bool tablet;
  final bool stretched;

  const MobileConvocationCard({
    super.key,
    required this.call,
    required this.feminine,
    required this.tablet,
    this.stretched = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final ModeSpan? inBuilding = inBuildingSpan(call);
    // When online only, the online hours stand in for the building's.
    final ModeSpan? span = inBuilding ?? call.byMode.firstOrNull;
    final room = call.room;
    final Set<String> modes = {for (final span in call.byMode) span.mode};

    return MobileBandCard(
      eyebrow: inBuilding != null ? convokedWord(feminine: feminine) : kOnlineLessonsTitle,
      hours: span == null ? '' : formatMinutesRange(span.startMinutes, span.endMinutes),
      figures: convocationFigures(call),
      tablet: tablet,
      stretched: stretched,
      // In the building the room speaks for the mode; "In presenza" only while no room is set.
      chips: [
        if (room != null)
          MobileBandChip(
            icon: Icons.meeting_room_outlined,
            label: room.name,
            accent: AppTheme.trialTealDeep,
            surface: AppTheme.todaySurface,
            tablet: tablet,
          )
        else if (modes.contains(kPresenceMode))
          MobileBandChip.mode(kPresenceMode, tablet: tablet),
        if (call.supervisions.isNotEmpty)
          MobileBandChip(
            icon: Icons.shield_rounded,
            label: kSupervisorLabel,
            accent: kSupervisorColor,
            filled: true,
            tablet: tablet,
          ),
        if (modes.contains(kOnlineMode)) MobileBandChip.mode(kOnlineMode, tablet: tablet),
      ],
    );
  }
}

class MobileBandCard extends StatelessWidget
{
  final String eyebrow;
  final String hours;
  final List<ConvocationFigure> figures;
  final List<MobileBandChip> chips;

  final String? name;

  final bool tablet;
  final bool stretched;

  const MobileBandCard({
    super.key,
    required this.eyebrow,
    required this.hours,
    required this.figures,
    required this.chips,
    this.name,
    required this.tablet,
    this.stretched = false,
  });

  Widget _buildHeadline()
  {
    final String? name = this.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name != null) ...[
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 20 : 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 12.5 : 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppTheme.trialTealDeep,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hours,
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 36 : 31,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.2,
            color: AppTheme.trialInk,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildFigure(ConvocationFigure figure)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            figure.value,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 24 : 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.15,
              color: AppTheme.trialDeepWater,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            figure.label,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 12.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: MobilePalette.mutedText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigures()
  {
    Widget cell(int i)
    {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: i == 0 ? null : const Border(left: BorderSide(color: _hairline)),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : _figureGap, right: 4),
          child: _buildFigure(figures[i]),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: stretched ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < figures.length; i++)
            if (stretched)
              SizedBox(width: _stretchedFigureWidth, child: cell(i))
            else
              Expanded(child: cell(i)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget chipList = Wrap(
      spacing: _chipGap,
      runSpacing: _chipGap,
      children: chips,
    );

    if (stretched)
    {
      return MobileGlassPanel(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        borderRadius: const BorderRadius.all(Radius.circular(_radius)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildHeadline()),
              const SizedBox(width: 24),
              const VerticalDivider(width: 1, thickness: 1, color: _hairline),
              const SizedBox(width: 20),
              Center(child: _buildFigures()),
              if (chips.isEmpty)
                const Spacer()
              else ...[
                const SizedBox(width: 24),
                const VerticalDivider(width: 1, thickness: 1, color: _hairline),
                const SizedBox(width: 20),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: chipList)),
              ],
            ],
          ),
        ),
      );
    }

    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 18, 24, 20) : const EdgeInsets.fromLTRB(18, 16, 18, 18),
      borderRadius: const BorderRadius.all(Radius.circular(_radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeadline(),
          const _Rule(),
          _buildFigures(),
          if (chips.isNotEmpty) ...[
            const _Rule(),
            if (tablet) chipList else _ChipLine(chips: chips),
          ],
        ],
      ),
    );
  }
}

const Color _hairline = Color(0x1A122438);

class _Rule extends StatelessWidget
{
  const _Rule();

  @override
  Widget build(BuildContext context)
  {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: _ruleGap),
      child: SizedBox(height: 1, child: ColoredBox(color: _hairline)),
    );
  }
}

class MobileBandChip extends StatelessWidget
{
  final IconData icon;
  final String label;
  final Color accent;
  final Color? surface;
  final bool filled;
  final bool tablet;

  const MobileBandChip({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.surface,
    this.filled = false,
    required this.tablet,
  });

  MobileBandChip.mode(String mode, {super.key, required this.tablet})
      : icon = lessonModeIcon(mode),
        label = modeLabel(mode),
        accent = lessonAccent(mode),
        surface = lessonSurface(mode),
        filled = false;

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 13 : 12.5,
        fontWeight: FontWeight.w800,
        color: filled ? Colors.white : accent,
      );

  // Must match build, in the ambient style the label inherits.
  double naturalWidth(BuildContext context)
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: DefaultTextStyle.of(context).style.merge(_labelStyle)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double text = painter.width.ceilToDouble();

    painter.dispose();

    return 2 * _chipBorder + _chipPadding.horizontal + _chipIcon + _chipIconGap + text;
  }

  @override
  Widget build(BuildContext context)
  {
    final Color foreground = filled ? Colors.white : accent;

    return Container(
      constraints: BoxConstraints(minHeight: tablet ? 32 : 30),
      padding: _chipPadding,
      decoration: BoxDecoration(
        color: filled ? accent : surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? accent : accent.withValues(alpha: 0.3), width: _chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _chipIcon, color: foreground),
          const SizedBox(width: _chipIconGap),
          Flexible(child: Text(label, style: _labelStyle)),
        ],
      ),
    );
  }
}

class _ChipLine extends StatelessWidget
{
  final List<MobileBandChip> chips;

  const _ChipLine({required this.chips});

  Widget _buildRow()
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, chip) in chips.indexed) ...[
          if (i > 0) const SizedBox(width: _chipGap),
          chip,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double natural = chips.fold(0.0, (sum, chip) => sum + chip.naturalWidth(context)) +
        (chips.length - 1) * _chipGap;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Shrinks only when it must, so a hair of misjudged width never overflows.
        if (natural * _minChipScale <= constraints.maxWidth)
        {
          return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _buildRow());
        }

        return Wrap(spacing: _chipGap, runSpacing: _chipGap, children: chips);
      },
    );
  }
}
