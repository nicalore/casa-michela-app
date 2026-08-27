import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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

class DashboardStatsSection extends StatelessWidget
{
  // Minimum widths for four and two figures per row, measured on the longest
  // label.
  static const double fourInARowFrom = 670;
  static const double twoInARowFrom = 300;

  static int columnsForWidth(double width)
  {
    if (width >= fourInARowFrom)
    {
      return 4;
    }

    return width >= twoInARowFrom ? 2 : 1;
  }

  final CurrentTotalsItem? general;
  final CurrentTotalsItem? teachers;
  final CurrentTotalsItem? students;
  final bool isLoading;

  // Compact puts the change on the same line as the figure instead of under
  // it.
  final bool compact;

  // Decided by the page: measuring here would need a LayoutBuilder, which
  // cannot report a height inside a row of equal-height cards.
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
    this.minHeight = 0,
    this.fill = false,
  });

  List<DashboardStat> get _stats => [
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

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      eyebrow: 'Persone',
      title: 'Alcune statistiche',
      minHeight: minHeight,
      fill: fill,
      compact: compact,
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
              ),
            )
          : _grid(),
    );
  }

  // A partial last row keeps normal-width tiles rather than stretching them.
  Widget _grid()
  {
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
              if (i > 0) SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: i < row.length
                    ? _StatTile(stat: row[i], compact: compact)
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
          if (i > 0) SizedBox(height: compact ? 12 : 16),
          if (fill) Expanded(child: rows[i]) else rows[i],
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget
{
  final DashboardStat stat;
  final bool compact;

  const _StatTile({required this.stat, this.compact = false});

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
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: AppTheme.trialMutedText,
      ),
    );

    final Widget value = Text(
      '${stat.value}',
      style: GoogleFonts.plusJakartaSans(
        fontSize: compact ? 22 : 34,
        fontWeight: FontWeight.w700,
        height: 1,
        color: AppTheme.trialOcean,
      ),
    );

    final Widget change = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          Icon(
            still
                ? Icons.remove_rounded
                : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded),
            size: 16,
            color: deltaColor,
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            still ? 'Stabile' : '${up ? '+' : ''}${stat.deltaMonth} questo mese',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: compact ? 10.5 : 12.5,
              fontWeight: FontWeight.w600,
              color: deltaColor,
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          SizedBox(height: compact ? 5 : 10),
          if (compact)
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
            const SizedBox(height: 10),
            change,
          ],
        ],
      ),
    );
  }
}
