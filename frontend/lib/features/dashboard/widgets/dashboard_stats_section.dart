import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../people/models/current_totals_item.dart';
import 'dashboard_section_card.dart';

// The four figures saying how the association stands. Only the figures, with
// their change: the charts already have a page of their own, and a home page
// repeating them becomes a statistics page with a greeting on top.

// A total with how much it changed over the last month.
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
  // How wide the card has to be for the four figures to sit in a row without
  // clipping their labels, and how wide for two of them. The first is measured
  // on the longest of the four labels.
  static const double fourInARowFrom = 670;
  static const double twoInARowFrom = 300;

  // How many columns of figures fit in the given width.
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

  // How many figures per row. Decided by the page, the only one that knows how
  // much room it gave this card: measuring it here would want a LayoutBuilder,
  // and a LayoutBuilder inside a row of equal-height cards cannot answer how
  // tall it would be.
  final int columns;

  /// Passati alla card: quanto è alta almeno e se il contenuto riempie.
  final double minHeight;
  final bool fill;

  const DashboardStatsSection({
    super.key,
    required this.general,
    required this.teachers,
    required this.students,
    this.isLoading = false,
    this.columns = 4,
    this.minHeight = 0,
    this.fill = false,
  });

  List<DashboardStat> get _stats => [
        DashboardStat(
          label: 'Iscritti',
          value: general?.currentTotalMembers ?? 0,
          deltaMonth: general?.membersDeltaMonth ?? 0,
        ),
        // The full label does not fit in a quarter of the card, and truncated
        // it says nothing: these are all current figures, and the section
        // already says so.
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

  // The figures in rows of [columns], with the last row keeping its height even
  // when not full: two tiles twice as wide as the other two would say that those
  // two count for more.
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
              if (i > 0) const SizedBox(width: 16),
              Expanded(
                child: i < row.length ? _StatTile(stat: row[i]) : const SizedBox(),
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
          if (i > 0) const SizedBox(height: 16),
          if (fill) Expanded(child: rows[i]) else rows[i],
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget
{
  final DashboardStat stat;

  const _StatTile({required this.stat});

  @override
  Widget build(BuildContext context)
  {
    // Green for a rise, red for a fall, grey for standing still: a plus in
    // front of a zero is news that is not there.
    final bool still = stat.deltaMonth == 0;
    final bool up = stat.deltaMonth > 0;

    final Color deltaColor = still
        ? AppTheme.trialMutedText
        : (up ? AppTheme.trialSeaGreen : AppTheme.trialDanger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // If the tile is stretched taller — because the row holds a card
        // taller than this one — the figure stays centred instead of hanging at
        // the top.
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${stat.value}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1,
              color: AppTheme.trialOcean,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                still
                    ? Icons.remove_rounded
                    : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                size: 16,
                color: deltaColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  still
                      ? 'Stabile'
                      : '${up ? '+' : ''}${stat.deltaMonth} nel mese',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: deltaColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
