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

  // When online only, the online hours stand in for the building's.
  (String, String) get _headline
  {
    final ModeSpan? inBuilding = inBuildingSpan(call);
    final ModeSpan? span = inBuilding ?? call.byMode.firstOrNull;

    return (
      inBuilding != null ? convokedWord(feminine: feminine) : kOnlineLessonsTitle,
      span == null ? '' : formatMinutesRange(span.startMinutes, span.endMinutes),
    );
  }

  Widget _buildHeadline()
  {
    final (String eyebrow, String hours) = _headline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
    final List<ConvocationFigure> figures = convocationFigures(call);

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

  List<Widget> _buildChips()
  {
    final room = call.room;

    return [
      for (final span in call.byMode)
        _Chip(
          icon: lessonModeIcon(span.mode),
          label: modeLabel(span.mode),
          accent: lessonAccent(span.mode),
          surface: lessonSurface(span.mode),
          tablet: tablet,
        ),
      if (room != null)
        _Chip(
          icon: Icons.meeting_room_outlined,
          label: room.name,
          accent: AppTheme.trialTealDeep,
          surface: AppTheme.todaySurface,
          tablet: tablet,
        ),
      if (call.supervisions.isNotEmpty)
        _Chip(
          icon: Icons.shield_rounded,
          label: kSupervisorLabel,
          accent: kSupervisorColor,
          filled: true,
          tablet: tablet,
        ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> chipList = _buildChips();

    final Widget chips = Wrap(
      spacing: _chipGap,
      runSpacing: _chipGap,
      children: chipList,
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
              const SizedBox(width: 24),
              const VerticalDivider(width: 1, thickness: 1, color: _hairline),
              const SizedBox(width: 20),
              Expanded(child: Align(alignment: Alignment.centerLeft, child: chips)),
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
          if (chipList.isNotEmpty) ...[
            const _Rule(),
            chips,
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

class _Chip extends StatelessWidget
{
  final IconData icon;
  final String label;
  final Color accent;
  final Color? surface;
  final bool filled;
  final bool tablet;

  const _Chip({
    required this.icon,
    required this.label,
    required this.accent,
    this.surface,
    this.filled = false,
    required this.tablet,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color foreground = filled ? Colors.white : accent;

    return Container(
      constraints: BoxConstraints(minHeight: tablet ? 32 : 30),
      padding: const EdgeInsets.fromLTRB(9, 4, 12, 4),
      decoration: BoxDecoration(
        color: filled ? accent : surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? accent : accent.withValues(alpha: 0.3), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 13 : 12.5,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
