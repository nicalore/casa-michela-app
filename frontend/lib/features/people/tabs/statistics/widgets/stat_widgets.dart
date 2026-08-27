import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../models/retention_rate_item.dart';

const double _figureSize = 36;
const double _percentageSize = 24;
const double _labelSize = 15;

// Below this a card stops laying its figures out side by side.
const double _figuresStackBelow = 430;

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
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.trialMutedText,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class StatSectionTitle extends StatelessWidget
{
  final String text;

  const StatSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
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
      color: AppTheme.trialLine,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class StatRowDivider extends StatelessWidget
{
  const StatRowDivider({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
    );
  }
}

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
    final color = isDelta && value < 0 ? AppTheme.trialDanger : AppTheme.trialTealDeep;
    final sign = value > 0 ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: _labelSize,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 8),
        // mainAxisSize.min is required: FittedBox hands out unbounded
        // constraints and max would throw on infinite width.
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
                  fontSize: _figureSize,
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
                      fontSize: _percentageSize,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.trialMutedText,
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
    final blocks = [
      StatBlock(label: 'Totale', value: count, percentage: percentage),
      StatBlock(label: 'Da inizio mese', value: deltaMonth, isDelta: true),
      StatBlock(label: 'Da inizio anno', value: deltaYear, isDelta: true),
    ];

    return AppCard(
      title: title,
      compact: true,
      selectable: false,
      leading: AppCardBadge(icon: icon, compact: true),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < _figuresStackBelow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const StatRowDivider(),
                    blocks[i],
                  ],
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const StatDivider(),
                    Expanded(child: blocks[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget
{
  static const double _chartHeight = 280;

  final String title;

  final IconData icon;

  final Widget? filters;
  final bool isEmpty;

  // Replaces only the chart with a spinner, so changing this card's filters
  // does not blank out the rest of it.
  final bool isLoading;

  final Widget chart;

  const ChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isEmpty,
    required this.chart,
    this.filters,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context)
  {
    Widget chartArea;

    if (isLoading)
    {
      chartArea = const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }
    else if (isEmpty)
    {
      chartArea = const EmptyChartMessage();
    }
    else
    {
      chartArea = chart;
    }

    return AppCard(
      title: title,
      selectable: false,
      leading: AppCardBadge(icon: icon),
      trailing: filters,
      trailingFit: AppCardTrailing.wrapping,
      child: SizedBox(height: _chartHeight, child: chartArea),
    );
  }
}

class RetentionCard extends StatelessWidget
{
  static const double _percentageFigureSize = 48;

  static const double _bodyMinHeight = 62;

  static const Duration _fetchFade = Duration(milliseconds: 150);

  final String title;
  final IconData icon;
  final Widget filters;
  final RetentionRateItem? data;
  final String Function(RetentionRateItem data) describe;

  final bool isLoading;

  // Handed down by MatchedCardPair: a matched card may not measure itself.
  final double width;
  final bool matched;

  const RetentionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.filters,
    required this.data,
    required this.describe,
    required this.width,
    required this.matched,
    this.isLoading = false,
  });

  Widget _buildBody()
  {
    final retention = data;

    // An existing figure stays, dimmed, while the next is fetched: swapping it
    // for a spinner resized the card and its matched pair.
    if (retention == null)
    {
      if (isLoading)
      {
        return const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.trialTurquoise),
          ),
        );
      }

      return const EmptyChartMessage(fontSize: 14);
    }

    final Widget figure = Text(
      '${retention.retentionRatePercentage.toStringAsFixed(1)}%',
      style: GoogleFonts.plusJakartaSans(
        fontSize: _percentageFigureSize,
        fontWeight: FontWeight.w800,
        color: AppTheme.trialTealDeep,
      ),
    );

    final Widget sentence = Text(
      describe(retention),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
        height: 1.5,
      ),
    );

    if (width < _figuresStackBelow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          figure,
          const SizedBox(height: 8),
          sentence,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        figure,
        const SizedBox(width: 16),
        Expanded(child: sentence),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: title,
      compact: true,
      selectable: false,
      fillHeight: matched,
      leading: AppCardBadge(icon: icon, compact: true),
      trailing: filters,
      trailingFit: AppCardTrailing.wrapping,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _bodyMinHeight),
          child: _buildBody(),
        ),
      ),
    );
  }
}
