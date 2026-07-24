import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/stat_card.dart';
import '../../../models/retention_rate_item.dart';
import 'stats_layout.dart';

// Presentation pieces shared by the statistics tabs. They wrap StatCard rather
// than replacing it: the white panel stays one widget, these add the recurring
// arrangements of content inside it.

class StatCardTitle extends StatelessWidget
{
  final String text;

  const StatCardTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.slate800,
      ),
    );
  }
}

class EmptyChartMessage extends StatelessWidget
{
  final double fontSize;

  const EmptyChartMessage({super.key, this.fontSize = 16});

  @override
  Widget build(BuildContext context)
  {
    return Center(
      child: Text(
        'Nessun dato',
        style: GoogleFonts.plusJakartaSans(color: AppTheme.slate400, fontSize: fontSize),
      ),
    );
  }
}

class StatDivider extends StatelessWidget
{
  const StatDivider({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: 1,
      height: 45,
      color: AppTheme.slate200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

// A labelled figure. Deltas are signed and get a trend arrow; the optional
// percentage sits next to the figure, aligned on the same baseline.
class StatBlock extends StatelessWidget
{
  final String label;
  final int value;
  final bool isDelta;
  final double? percentage;

  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.isDelta = false,
    this.percentage,
  });

  @override
  Widget build(BuildContext context)
  {
    final color = isDelta && value < 0 ? AppTheme.danger : AppTheme.primary;
    final sign = value > 0 ? '+' : '';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 8),
          // Numbers cannot wrap, so scaling down is the right fallback here,
          // unlike the text elsewhere. mainAxisSize.min is required: FittedBox
          // hands out unbounded constraints and max would throw on infinite
          // width.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  isDelta ? '$sign$value' : '$value',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (percentage != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      '${percentage!.toStringAsFixed(1)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate400,
                      ),
                    ),
                  ),
                if (isDelta && value != 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      value > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: color,
                      size: 26,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryStatCard extends StatelessWidget
{
  final String title;
  final IconData icon;
  final int count;
  final int deltaMonth;
  final int deltaYear;
  final double? percentage;

  const SummaryStatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
    required this.deltaMonth,
    required this.deltaYear,
    this.percentage,
  });

  @override
  Widget build(BuildContext context)
  {
    return StatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceHover,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              StatBlock(label: 'Totale', value: count, percentage: percentage),
              const StatDivider(),
              StatBlock(label: 'Da inizio mese', value: deltaMonth, isDelta: true),
              const StatDivider(),
              StatBlock(label: 'Da inizio anno', value: deltaYear, isDelta: true),
            ],
          ),
        ],
      ),
    );
  }
}

// Card hosting a chart of fixed height, with the empty state handled here so no
// caller has to repeat it.
class ChartCard extends StatelessWidget
{
  static const double _titleGap = 48;
  static const double _chartHeight = 280;

  final String title;
  final Widget? filters;
  final double filtersBreakpoint;
  final bool isEmpty;

  /// Shows a spinner in place of the chart, without touching the title or the
  /// filters above it, so changing this card's own filters does not blank out
  /// the rest of the page while the new data loads.
  final bool isLoading;

  final Widget chart;

  const ChartCard({
    super.key,
    required this.title,
    required this.isEmpty,
    required this.chart,
    this.filters,
    this.filtersBreakpoint = 760,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final titleWidget = StatCardTitle(title);

    Widget chartArea;

    if (isLoading)
    {
      chartArea = const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    else if (isEmpty)
    {
      chartArea = const EmptyChartMessage();
    }
    else
    {
      chartArea = chart;
    }

    return StatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filters == null
              ? titleWidget
              : ResponsiveCardHeader(
                  title: titleWidget,
                  filters: filters!,
                  breakpoint: filtersBreakpoint,
                ),
          const SizedBox(height: _titleGap),
          SizedBox(height: _chartHeight, child: chartArea),
        ],
      ),
    );
  }
}

// Big percentage plus a sentence explaining it. The sentence is built by the
// caller, because its wording depends on what is being retained.
class RetentionCard extends StatelessWidget
{
  final String title;
  final Widget filters;
  final double filtersBreakpoint;
  final RetentionRateItem? data;
  final String Function(RetentionRateItem data) describe;

  const RetentionCard({
    super.key,
    required this.title,
    required this.filters,
    required this.filtersBreakpoint,
    required this.data,
    required this.describe,
  });

  @override
  Widget build(BuildContext context)
  {
    final retention = data;

    return StatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveCardHeader(
            title: StatCardTitle(title),
            filters: filters,
            breakpoint: filtersBreakpoint,
          ),
          const SizedBox(height: 24),
          if (retention != null)
            Row(
              children: [
                Text(
                  '${retention.retentionRatePercentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    describe(retention),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: AppTheme.slate500,
                      height: 1.5,
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