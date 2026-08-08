import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../models/retention_rate_item.dart';

// The recurring cards of the statistics tabs. The panel around them is AppCard's
// — the same white, radius, badge, heading and rule every other card of the app
// wears — so what is written here is only what goes inside.
//
// The two families are deliberately different sizes. A card carrying a figure or
// two takes the compact chrome, a card carrying a chart takes the full one, and
// the pages read as figures first, charts after.

const double _figureSize = 36;
const double _percentageSize = 24;
const double _labelSize = 15;

// Under this a card stops laying its figures out side by side. Three columns of
// figures need about a hundred and forty pixels each before the labels start
// coming apart, and a phone has half of that to give.
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

// A heading inside a card, under the one the card itself carries: the three
// sections of the competences card are one card, not three.
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

// Between two figures standing side by side.
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

// And between two standing one over the other, which is what they do on a card
// too narrow to hold three columns of figures.
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
    // Red is what the app says about something going the wrong way, and a month
    // that lost members is the one figure here that qualifies. Everything else
    // is the brand.
    final color = isDelta && value < 0 ? AppTheme.trialDanger : AppTheme.trialTealDeep;
    final sign = value > 0 ? '+' : '';

    // Not flexible on its own: the card lays three of these across a row on a
    // wide window and down a column on a narrow one, and only one of the two
    // wants a flex factor.
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

// Three figures about one population: how many there are, and how that has moved
// since the start of the month and of the year.
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
      // Three columns of figures on a card narrower than this are three columns
      // of one word each, with "Da inizio mese" broken over three lines above a
      // number scaled down to nothing. Under it they go one to a row.
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

// Card hosting a chart of fixed height, with the empty state handled here so no
// caller has to repeat it.
class ChartCard extends StatelessWidget
{
  static const double _chartHeight = 280;

  final String title;

  // Every card of the app is introduced by a badge, and no two badges on the
  // same page may be the same icon: that is the whole of what a badge says.
  final IconData icon;

  final Widget? filters;
  final bool isEmpty;

  /// Shows a spinner in place of the chart, without touching the title or the
  /// filters above it, so changing this card's own filters does not blank out
  /// the rest of the page while the new data loads.
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

// Big percentage plus a sentence explaining it. The sentence is built by the
// caller, because its wording depends on what is being retained.
class RetentionCard extends StatelessWidget
{
  static const double _percentageFigureSize = 48;

  // Only for the card that has nothing to show yet: with a figure already on it
  // the body keeps the height of that figure.
  static const double _bodyMinHeight = 62;

  static const Duration _fetchFade = Duration(milliseconds: 150);

  final String title;
  final IconData icon;
  final Widget filters;
  final RetentionRateItem? data;
  final String Function(RetentionRateItem data) describe;

  // Only this card's own figure is being fetched again: the rest of the page
  // stays where it is.
  final bool isLoading;

  // Both handed down by the pair this card stands in. See MatchedCardPair for
  // why a card matched to another one may not measure itself.
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

    // A figure already on the card stays there while the next one is fetched,
    // dimmed rather than taken away. Swapping it for a spinner shortened the
    // card for as long as the request took and then let it back out — and with
    // the two cards matched, the one beside it followed both ways.
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

    // A figure of this size and a sentence of this length do not share a narrow
    // card: what is left over for the sentence is a column two words wide. Under
    // the breakpoint the figure stands over it and the sentence gets the whole
    // width.
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
