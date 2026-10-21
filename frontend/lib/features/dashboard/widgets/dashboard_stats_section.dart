import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../people/models/current_totals_item.dart';
import 'dashboard_section_card.dart';

class DashboardStat
{
  final String label;
  final int value;
  final int deltaMonth;

  const DashboardStat({
    required this.label,
    required this.value,
    required this.deltaMonth,
  });
}

// Shared with the mobile home; a total not read counts as zero.
List<DashboardStat> dashboardStats({
  required CurrentTotalsItem? general,
  required CurrentTotalsItem? teachers,
  required CurrentTotalsItem? students,
})
{
  return [
    DashboardStat(
      label: 'Iscritti',
      value: general?.currentTotalMembers ?? 0,
      deltaMonth: general?.membersDeltaMonth ?? 0,
    ),
    DashboardStat(
      label: 'Collaboratori',
      value: general?.currentActiveCollaborators ?? 0,
      deltaMonth: general?.collabDeltaMonth ?? 0,
    ),
    DashboardStat(
      label: 'Docenti',
      value: teachers?.currentTotalMembers ?? 0,
      deltaMonth: teachers?.membersDeltaMonth ?? 0,
    ),
    DashboardStat(
      label: 'Studenti',
      value: students?.currentTotalMembers ?? 0,
      deltaMonth: students?.membersDeltaMonth ?? 0,
    ),
  ];
}

class _StatScale
{
  final double value;
  final double change;
  final double icon;
  final double sideGap;
  final double padX;
  final double padY;
  final double gap;
  final double radius;

  final double labelGap;
  final double valueGap;

  // The label's letter spacing: a strip's tiles are too narrow for the full one.
  final double spacing;

  final bool inline;

  final double label;

  const _StatScale({
    required this.value,
    required this.change,
    required this.icon,
    required this.sideGap,
    required this.padX,
    required this.padY,
    required this.gap,
    required this.radius,
    required this.labelGap,
    required this.valueGap,
    required this.spacing,
    required this.inline,
    this.label = 10.5,
  });

  static const _StatScale spacious = _StatScale(
    value: 34,
    change: 16,
    icon: 16,
    sideGap: 5,
    padX: 16,
    padY: 18,
    gap: 16,
    radius: 20,
    labelGap: 10,
    valueGap: 10,
    spacing: 1.1,
    inline: false,
  );

  static const _StatScale compact = _StatScale(
    value: 22,
    change: 11,
    icon: 14,
    sideGap: 4,
    padX: 14,
    padY: 9,
    gap: 12,
    radius: 16,
    labelGap: 5,
    valueGap: 0,
    spacing: 1.1,
    inline: true,
  );

  static const _StatScale strip = _StatScale(
    value: 26,
    change: 15,
    icon: 16,
    sideGap: 4,
    padX: 10,
    padY: 9,
    gap: 10,
    radius: 18,
    labelGap: 6,
    valueGap: 5,
    spacing: 0.9,
    inline: false,
  );

  static const _StatScale denseStrip = _StatScale(
    value: 20,
    change: 11.5,
    icon: 14,
    sideGap: 3,
    padX: 11,
    padY: 7,
    gap: 8,
    radius: 14,
    labelGap: 5,
    valueGap: 3,
    spacing: 0.9,
    inline: false,
    label: 9.5,
  );
}

class DashboardStatsSection extends StatelessWidget
{
  // Minimum widths for four and two figures per row, measured on the longest label.
  static const double fourInARowFrom = 670;
  static const double twoInARowFrom = 300;

  // "COLLABORATORI" needs about 100 px per tile plus 23 of padding and border.
  static const double stripOfFourFrom = 534;

  static int columnsForWidth(double width)
  {
    if (width >= fourInARowFrom)
    {
      return 4;
    }

    return width >= twoInARowFrom ? 2 : 1;
  }

  static int stripColumnsForWidth(double width) => width >= stripOfFourFrom ? 4 : 2;

  final CurrentTotalsItem? general;
  final CurrentTotalsItem? teachers;
  final CurrentTotalsItem? students;
  final bool isLoading;

  // Compact puts the change on the same line as the figure instead of under it.
  final bool compact;

  // Strip sets four small tiles in a row, figures written large.
  final bool strip;

  // Set by the page: a LayoutBuilder cannot report a height inside equal-height card rows.
  final int columns;

  final double minHeight;
  final bool fill;

  const DashboardStatsSection({
    super.key,
    required this.general,
    required this.teachers,
    required this.students,
    this.isLoading = false,
    this.columns = 4,
    this.compact = false,
    this.strip = false,
    this.minHeight = 0,
    this.fill = false,
  });

  _StatScale _scaleOf(BuildContext context) => strip
      ? (AppBreakpoints.of(context).isDense ? _StatScale.denseStrip : _StatScale.strip)
      : compact
          ? _StatScale.compact
          : _StatScale.spacious;

  List<DashboardStat> get _stats => dashboardStats(general: general, teachers: teachers, students: students);

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      icon: Icons.groups_rounded,
      title: 'Alcune statistiche',
      action: DashboardCardNote(formatMonthYear(romeNow())),
      minHeight: minHeight,
      fill: fill,
      compact: compact,
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(color: Color.fromARGB(255, 36, 43, 42)),
              ),
            )
          : _grid(context),
    );
  }

  // A partial last row keeps normal-width tiles rather than stretching them.
  Widget _grid(BuildContext context)
  {
    final _StatScale scale = _scaleOf(context);
    final List<DashboardStat> stats = _stats;
    final List<Widget> rows = [];

    for (var start = 0; start < stats.length; start += columns)
    {
      final List<DashboardStat> row = stats.sublist(
        start,
        (start + columns).clamp(0, stats.length),
      );

      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) SizedBox(width: scale.gap),
              Expanded(
                child: i < row.length
                    ? _StatTile(stat: row[i], scale: scale)
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      ));
    }

    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: scale.gap),
          if (fill) Expanded(child: rows[i]) else rows[i],
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget
{
  final DashboardStat stat;
  final _StatScale scale;

  const _StatTile({required this.stat, required this.scale});

  @override
  Widget build(BuildContext context)
  {
    final bool still = stat.deltaMonth == 0;
    final bool up = stat.deltaMonth > 0;

    final Color deltaColor = still
        ? AppTheme.trialMutedText
        : (up ? AppTheme.trialSeaGreen : AppTheme.trialDanger);

    final Widget label = Text(
      stat.label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: scale.label,
        fontWeight: FontWeight.w600,
        letterSpacing: scale.spacing,
        color: AppTheme.trialMutedText,
      ),
    );

    final Widget value = Text(
      '${stat.value}',
      style: GoogleFonts.plusJakartaSans(
        fontSize: scale.value,
        fontWeight: FontWeight.w700,
        height: 1,
        color: AppTheme.trialOcean,
      ),
    );

    final Widget change = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          still
              ? Icons.remove_rounded
              : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded),
          size: scale.icon,
          color: deltaColor,
        ),
        SizedBox(width: scale.sideGap),
        Flexible(
          child: Text(
            still ? 'Stabile' : '${up ? '+' : '−'}${stat.deltaMonth.abs()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scale.change,
              fontWeight: FontWeight.w600,
              color: deltaColor,
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: scale.padX, vertical: scale.padY),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(scale.radius),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          SizedBox(height: scale.labelGap),
          if (scale.inline)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                value,
                const SizedBox(width: 8),
                Flexible(child: change),
              ],
            )
          else ...[
            value,
            SizedBox(height: scale.valueGap),
            change,
          ],
        ],
      ),
    );
  }
}
