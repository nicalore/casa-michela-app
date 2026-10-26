import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/layout/app_breakpoints.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../../shared/widgets/page_density.dart';
import '../../../../../shared/widgets/show_more_button.dart';
import '../../../models/person_face.dart';
import '../../../models/student_presence_statistics_item.dart';
import '../../../models/retention_rate_item.dart';

const double _figureSize = 36;
const double _percentageSize = 24;
const double _labelSize = 15;

// Below this a card stops laying its figures out side by side.
const double _figuresStackBelow = 430;
const double _denseFiguresStackBelow = 330;

// The narrowest wide window leaves a whole card 864 wide inside and a paired summary card 400: below those
// nothing may stack there, or narrowing past 1280 (rail and margins gone, content wider) would unstack it again.
const double _wideListsFrom = 860;
const double _wideFiguresStackBelow = 380;

// In the minimal window a ranking shows this many rows, then lengthens in place.
const int kFoldedRankingRows = 5;

// Below the wide window the page asks for denser statistics, as the pages under the user menu do.
class StatMetrics
{
  final bool dense;

  const StatMetrics.forDensity(this.dense);

  factory StatMetrics.of(BuildContext context) => StatMetrics.forDensity(AppPageDensity.of(context));

  double get labelSize => dense ? 13 : _labelSize;
  double get figureSize => dense ? 26 : _figureSize;
  double get percentageSize => dense ? 17 : _percentageSize;
  double get labelGap => dense ? 4 : 8;
  double get sectionTitleSize => dense ? 15 : 17;

  // Under a section title, before its rows.
  double get titleGap => dense ? 12 : 24;

  // Around the rules between the parts of a card.
  double get partSpace => dense ? 20 : 32;

  // Around the rules between lists stacked in a card.
  double get listSpace => dense ? 20 : 24;

  double get rowSize => dense ? 13.5 : 14;
  double get badgeSize => dense ? 11.5 : 12;
  EdgeInsets get badgePadding => EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 3 : 5);
  double get rowGap => dense ? 10 : 14;

  // Between the cards of a page.
  double get cardGap => dense ? 14 : 24;

  // Pairs of cards sit side by side from this width.
  double get pairFrom => dense ? 640 : 900;

  // Lists inside a card sit side by side from this width, three of them from the next.
  double get listsFrom => dense ? 640 : _wideListsFrom;
  double get threeListsFrom => dense ? 900 : _wideListsFrom;

  double get figuresStackBelow => dense ? _denseFiguresStackBelow : _wideFiguresStackBelow;
}

// Below the wide window charts are lower, more so in the narrow sizes.
double statChartHeight(BuildContext context, double wide)
{
  if (!AppPageDensity.of(context))
  {
    return wide;
  }

  return AppBreakpoints.of(context).isNarrow ? 200 : 220;
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
        fontSize: StatMetrics.of(context).sectionTitleSize,
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
    final bool dense = StatMetrics.of(context).dense;

    return Container(
      width: 1,
      height: dense ? 36 : 45,
      color: AppTheme.trialLine,
      margin: EdgeInsets.symmetric(horizontal: dense ? 14 : 16),
    );
  }
}

class StatRowDivider extends StatelessWidget
{
  const StatRowDivider({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: StatMetrics.of(context).dense ? 12 : 16),
      child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
    );
  }
}

// A rule between the parts of a card, with its space above and below.
class StatPartDivider extends StatelessWidget
{
  final Color color;

  // Between lists stacked in a card rather than between its parts.
  final bool lists;

  const StatPartDivider({super.key, this.color = AppTheme.trialLine, this.lists = false});

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);
    final double space = lists ? metrics.listSpace : metrics.partSpace;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: space),
      child: Divider(height: 16, color: color, thickness: 1),
    );
  }
}

// A rule between lists side by side in a card.
class StatColumnDivider extends StatelessWidget
{
  const StatColumnDivider({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: StatMetrics.of(context).dense ? 20 : 24),
      child: const VerticalDivider(color: AppTheme.trialLine, thickness: 1),
    );
  }
}

// A ranking in two columns, 1°–5° beside 6°–10°.
class SplitRanking extends StatelessWidget
{
  final String title;
  final List<Widget> rows;

  const SplitRanking({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context)
  {
    final int half = (rows.length + 1) ~/ 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatSectionTitle(title),
        SizedBox(height: StatMetrics.of(context).titleGap),
        if (rows.isEmpty)
          const EmptyChartMessage(fontSize: 14)
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Column(children: rows.sublist(0, half))),
                const StatColumnDivider(),
                Expanded(child: Column(children: rows.sublist(half))),
              ],
            ),
          ),
      ],
    );
  }
}

// A label over a big figure, as wide as its slot.
class StatFigure extends StatelessWidget
{
  final String label;
  final String value;

  const StatFigure({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: metrics.labelSize,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        SizedBox(height: metrics.labelGap),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: metrics.figureSize,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialTealDeep,
          ),
        ),
      ],
    );
  }
}

// The rows of a ranking; in the minimal window the first few, lengthening in place.
class RankingRows extends StatefulWidget
{
  final List<Widget> rows;

  const RankingRows({super.key, required this.rows});

  @override
  State<RankingRows> createState() => _RankingRowsState();
}

class _RankingRowsState extends State<RankingRows>
{
  bool _all = false;

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> rows = widget.rows;
    final bool folds = AppBreakpoints.of(context).isMinimal && rows.length > kFoldedRankingRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...(folds && !_all ? rows.take(kFoldedRankingRows) : rows),
        if (folds)
          ShowMoreButton(
            label: _all ? kShowFewerLabel : kShowAllLabel,
            open: _all,
            onTap: () => setState(() => _all = !_all),
          ),
      ],
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
    final StatMetrics metrics = StatMetrics.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: metrics.labelSize,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        SizedBox(height: metrics.labelGap),
        // mainAxisSize.min required: FittedBox gives unbounded constraints.
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
                  fontSize: metrics.figureSize,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (percentage != null)
                Padding(
                  padding: EdgeInsets.only(left: metrics.dense ? 6 : 10),
                  child: Text(
                    '${percentage!.toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: metrics.percentageSize,
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
                    size: metrics.dense ? 21 : 26,
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

  // The narrowest card keeping its figures side by side, padding included.
  static double rowWidth(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);

    return metrics.figuresStackBelow + (metrics.dense ? 40 : 2 * 26);
  }

  @override
  Widget build(BuildContext context)
  {
    final blocks = [
      StatBlock(label: 'Totale', value: count, percentage: percentage),
      StatBlock(label: 'Da inizio mese', value: deltaMonth, isDelta: true),
      StatBlock(label: 'Da inizio anno', value: deltaYear, isDelta: true),
    ];
    final StatMetrics metrics = StatMetrics.of(context);

    // Dense, the page's own card sizes take over from the compact ones.
    return AppCard(
      title: title,
      compact: !metrics.dense,
      selectable: false,
      leading: AppCardBadge(icon: icon, compact: !metrics.dense),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < metrics.figuresStackBelow
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
                // Numbers on one line even when only some labels wrap.
                crossAxisAlignment: metrics.dense ? CrossAxisAlignment.end : CrossAxisAlignment.center,
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

  // Replaces only the chart with a spinner, not the whole card.
  final bool isLoading;

  final Widget chart;

  // A chart that may take the height it needs, as bars laid across do.
  final bool sizesItself;

  const ChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isEmpty,
    required this.chart,
    this.filters,
    this.isLoading = false,
    this.sizesItself = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final double height = statChartHeight(context, _chartHeight);
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
      child: sizesItself && !isLoading && !isEmpty
          ? ConstrainedBox(constraints: BoxConstraints(minHeight: height), child: chartArea)
          : SizedBox(height: height, child: chartArea),
    );
  }
}

class RetentionCard extends StatelessWidget
{
  static const double _percentageFigureSize = 48;
  static const double _densePercentageFigureSize = 34;

  static const double _bodyMinHeight = 62;
  static const double _denseBodyMinHeight = 44;

  // Dense, the figure and its sentence share a row down to narrower cards.
  static const double _denseStackBelow = 340;

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

  // The narrowest card keeping figure and sentence side by side.
  static double rowWidth(BuildContext context) => StatMetrics.of(context).dense ? _denseStackBelow : _figuresStackBelow;

  Widget _buildBody(bool dense)
  {
    final retention = data;

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
        fontSize: dense ? _densePercentageFigureSize : _percentageFigureSize,
        fontWeight: FontWeight.w800,
        color: AppTheme.trialTealDeep,
      ),
    );

    final Widget sentence = Text(
      describe(retention),
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13.5 : 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
        height: dense ? 1.45 : 1.5,
      ),
    );

    if (width < (dense ? _denseStackBelow : _figuresStackBelow))
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
        SizedBox(width: dense ? 14 : 16),
        Expanded(child: sentence),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = StatMetrics.of(context).dense;

    return AppCard(
      title: title,
      compact: !dense,
      selectable: false,
      fillHeight: matched,
      leading: AppCardBadge(icon: icon, compact: !dense),
      trailing: filters,
      trailingFit: AppCardTrailing.wrapping,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: dense ? _denseBodyMinHeight : _bodyMinHeight),
          child: _buildBody(dense),
        ),
      ),
    );
  }
}


// Signed: +250, -34 (typographic minus), 0.
String formatAppreciationScore(int score)
{
  if (score == 0)
  {
    return '0';
  }

  return '${score > 0 ? '+' : '−'}${score.abs()}';
}

const Color kThumbUpColor = AppTheme.trialTealDeep;
const Color kThumbDownColor = AppTheme.trialDeepWater;

const Duration _hoverFade = Duration(milliseconds: 180);

// A zero count is never tappable.
class ThumbCount extends StatefulWidget
{
  final bool up;
  final int count;

  final bool large;

  final VoidCallback? onTap;

  const ThumbCount({
    super.key,
    required this.up,
    required this.count,
    this.large = false,
    this.onTap,
  });

  @override
  State<ThumbCount> createState() => _ThumbCountState();
}

class _ThumbCountState extends State<ThumbCount>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final color = widget.up ? kThumbUpColor : kThumbDownColor;
    final bool dense = StatMetrics.of(context).dense;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.up ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
          size: widget.large ? (dense ? 21 : 26) : 14,
          color: color,
        ),
        SizedBox(width: widget.large ? (dense ? 6 : 10) : 4),
        Text(
          '${widget.count}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: widget.large ? (dense ? 26 : 36) : (dense ? 11.5 : 12),
            fontWeight: widget.large ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );

    if (widget.onTap == null || widget.count == 0)
    {
      return content;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Only the hover colour animates: the padding follows the window's size.
        child: AnimatedContainer(
          duration: _hoverFade,
          decoration: BoxDecoration(
            color: _hover
                ? AppTheme.trialGoldSurface
                : AppTheme.trialGoldSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.large ? (dense ? 6 : 10) : 6,
              vertical: widget.large ? (dense ? 4 : 6) : 3,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class ThumbCounts extends StatelessWidget
{
  final int up;
  final int down;

  final bool large;

  final VoidCallback? onUpTap;
  final VoidCallback? onDownTap;

  const ThumbCounts({
    super.key,
    required this.up,
    required this.down,
    this.large = false,
    this.onUpTap,
    this.onDownTap,
  });

  @override
  Widget build(BuildContext context)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThumbCount(up: true, count: up, large: large, onTap: onUpTap),
        SizedBox(width: large ? (StatMetrics.of(context).dense ? 18 : 28) : 12),
        ThumbCount(up: false, count: down, large: large, onTap: onDownTap),
      ],
    );
  }
}

class RankPosition extends StatelessWidget
{
  final int position;
  final Color color;

  const RankPosition({super.key, required this.position, required this.color});

  @override
  Widget build(BuildContext context)
  {
    // Room for "10" plus the ordinal sign on one line.
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 32,
        child: Text(
          '$position°',
          style: GoogleFonts.plusJakartaSans(
            fontSize: StatMetrics.of(context).dense ? 13.5 : 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class PersonRankRow extends StatelessWidget
{
  // Null for lists that are not rankings, such as warnings.
  final int? position;
  final PersonFace person;
  final String badgeText;
  final Color accent;

  final Widget? subtitle;

  const PersonRankRow({
    super.key,
    required this.person,
    required this.badgeText,
    required this.accent,
    this.position,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: metrics.rowGap),
      child: Row(
        children: [
          if (position case final position?) RankPosition(position: position, color: accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                OverflowTooltipText(
                  text: '${person.firstName} ${person.lastName}',
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: metrics.rowSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialInk,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  subtitle!,
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: metrics.badgePadding,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: metrics.badgeSize,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonRankingSection extends StatelessWidget
{
  final String title;
  final List<PersonRankRow> rows;

  const PersonRankingSection({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatSectionTitle(title),
        SizedBox(height: StatMetrics.of(context).titleGap),
        if (rows.isEmpty) const EmptyChartMessage(fontSize: 14) else RankingRows(rows: rows),
      ],
    );
  }
}


// Share and badge sit in fixed slots so they line up down the list.
class ShareRankRow extends StatelessWidget
{
  static const Color _badgeBackground = Color(0xFFE8F7F5);

  // Room for "100.0%".
  static const double _percentageSlot = 48;

  // Room for the usual badges; a longer one widens its own slot.
  static const double _badgeSlot = 78;
  static const double _denseBadgeSlot = 70;

  final int position;
  final String name;
  final double percentage;
  final String badgeText;

  const ShareRankRow({
    super.key,
    required this.position,
    required this.name,
    required this.percentage,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: metrics.rowGap),
      child: Row(
        children: [
          RankPosition(position: position, color: AppTheme.trialTealDeep),
          Expanded(
            child: OverflowTooltipText(
              text: name,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: metrics.rowSize,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _percentageSlot),
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: metrics.badgeSize,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: metrics.dense ? _denseBadgeSlot : _badgeSlot),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: metrics.badgePadding,
                decoration: BoxDecoration(
                  color: _badgeBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: metrics.badgeSize,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShareRankingSection extends StatelessWidget
{
  final String title;
  final List<ShareRankRow> rows;

  const ShareRankingSection({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatSectionTitle(title),
        SizedBox(height: StatMetrics.of(context).titleGap),
        if (rows.isEmpty) const EmptyChartMessage(fontSize: 14) else RankingRows(rows: rows),
      ],
    );
  }
}

class RequestedSubjectsSection extends StatelessWidget
{
  final RequestedSubjectRankings rankings;
  final RequestedSubjectKind kind;

  final int limit;

  const RequestedSubjectsSection({
    super.key,
    required this.rankings,
    required this.kind,
    required this.limit,
  });

  @override
  Widget build(BuildContext context)
  {
    final subjects = rankings.of(kind);

    return ShareRankingSection(
      title: '$limit ${kind.rankingTitle}',
      rows: [
        for (var index = 0; index < subjects.length; index++)
          ShareRankRow(
            position: index + 1,
            name: subjects[index].name,
            percentage: subjects[index].percentage,
            badgeText:
                '${subjects[index].requestCount} '
                '${subjects[index].requestCount == 1 ? 'richiesta' : 'richieste'}',
          ),
      ],
    );
  }
}
