import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/calendar/utils/calendar_strings.dart';
import '../../../../features/calendar/utils/teacher_band_call.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';

const double _radius = 22;

const double _ruleGap = 13;
const double _figureGap = 12;
const double _chipGap = 8;

// Chips shrink this far before wrapping: a phone card fits a room and "Online".
const double _minChipScale = 0.8;

const EdgeInsets _chipPadding = EdgeInsets.fromLTRB(9, 4, 12, 4);
const double _chipBorder = 1.4;
const double _chipIcon = 17;
const double _chipIconGap = 6;

// Each figure's share of a stretched card.
const double _stretchedFigureWidth = 96;

// Large enough for a photo to be recognised.
const double _phoneFace = 48;
const double _tabletFace = 56;

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
    final hull = call.hull;
    final room = call.room;
    final Set<String> modes = {for (final span in call.byMode) span.mode};

    return MobileBandCard(
      eyebrow: convokedWord(feminine: feminine),
      hours: hull == null ? '' : formatMinutesRange(hull.$1, hull.$2),
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
        if (modes.contains(kOnlineMode)) MobileBandChip.mode(kOnlineMode, tablet: tablet),
      ],
      footer: call.roomSupervisors.isEmpty
          ? null
          : _RoomSupervisors(supervisors: call.roomSupervisors, tablet: tablet, inline: stretched),
    );
  }
}

class _RoomSupervisors extends StatelessWidget
{
  final List<RoomSupervisor> supervisors;
  final bool tablet;

  // Side by side, each name above its hours, as in the stretched card.
  final bool inline;

  const _RoomSupervisors({required this.supervisors, required this.tablet, required this.inline});

  // The mark rides the name's last line, so a wrapped name keeps it close.
  Widget _buildName(RoomSupervisor supervisor)
  {
    return Text.rich(
      TextSpan(
        text: supervisor.person.fullName,
        children: [
          if (supervisor.isSelf)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: MobilePill(kSelfMark, tone: MobilePillTone.teal),
              ),
            ),
        ],
      ),
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 16 : 15,
        fontWeight: FontWeight.w800,
        height: 1.25,
        color: AppTheme.trialInk,
      ),
    );
  }

  Widget _buildSupervisor(RoomSupervisor supervisor)
  {
    final String? hours = supervisorHours(supervisor, count: supervisors.length);
    final Widget? hoursText = hours == null
        ? null
        : Text(
            hours,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 14 : 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: MobilePalette.mutedText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final Widget avatar = MobileAvatar(
      firstName: supervisor.person.firstName,
      lastName: supervisor.person.lastName,
      imageUrl: supervisor.person.profileImageUrl,
      size: tablet ? _tabletFace : _phoneFace,
      gold: false,
    );

    if (inline)
    {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [_buildName(supervisor), ?hoursText],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(child: _buildName(supervisor)),
          if (hoursText != null) ...[
            const SizedBox(width: 10),
            hoursText,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget heading = Text(
      roomSupervisorsHeading(supervisors.length).toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 12 : 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
        color: MobilePalette.mutedText,
      ),
    );

    if (inline)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [for (final supervisor in supervisors) _buildSupervisor(supervisor)],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        const SizedBox(height: 4),
        for (final (i, supervisor) in supervisors.indexed) ...[
          if (i > 0) const SizedBox(height: 1, child: ColoredBox(color: _hairline)),
          _buildSupervisor(supervisor),
        ],
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

  // Under the chips, past a rule of its own.
  final Widget? footer;

  final String? name;

  final bool tablet;
  final bool stretched;

  const MobileBandCard({
    super.key,
    required this.eyebrow,
    required this.hours,
    required this.figures,
    required this.chips,
    this.footer,
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
    final Widget? footer = this.footer;
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
              if (chips.isEmpty && footer == null)
                const Spacer()
              else ...[
                const SizedBox(width: 24),
                const VerticalDivider(width: 1, thickness: 1, color: _hairline),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chips.isNotEmpty) chipList,
                      if (chips.isNotEmpty && footer != null) const SizedBox(height: 14),
                      ?footer,
                    ],
                  ),
                ),
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
          if (footer != null) ...[
            const _Rule(),
            footer,
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
