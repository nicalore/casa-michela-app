import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../people/models/member_trend_item.dart';
import '../../people/tabs/statistics/widgets/chart_common.dart';
import '../../people/tabs/statistics/widgets/daily_trend_chart.dart' show TrendLegend, TrendSeries, TrendTooltip;
import '../../people/tabs/statistics/widgets/stat_widgets.dart';
import '../../people/tabs/statistics/widgets/stats_layout.dart';
import '../../people/tabs/statistics/widgets/trend_band.dart';
import '../../people/tabs/statistics/widgets/trend_line_chart.dart';
import '../models/accounting_stats_items.dart';
import '../utils/accounting_strings.dart';
import '../widgets/money_charts.dart';

const String _defaultPeriod = 'last-12';
const List<int> _lastMonths = [1, 3, 6, 12];

const double _chartHeight = 260;
const double _balanceHeight = 200;
const double _switchHeight = 32;
const double _switchFont = 12.5;
const double _switchPadding = 10;

// Stacked bars, in the order of kIncomeKinds.
const List<Color> _kindColors = [
  AppTheme.chartNavy,
  AppTheme.chartOcean,
  AppTheme.chartViolet,
  AppTheme.chartLilac,
  Color(0xFF77B5FB),
  Color(0xFFD9C8F2),
];

// 'last-3' or 'year-2025'.
({int? months, int? year}) _partsOf(String period)
{
  final List<String> parts = period.split('-');
  final int value = int.parse(parts[1]);

  return parts[0] == 'year' ? (months: null, year: value) : (months: value, year: null);
}

String _hoursFigure(int minutes) => minutes == 0 ? '0h' : formatMinutes(minutes);

class AccountingStatsTab extends StatefulWidget
{
  // On screen among the page's sections: shown again, it reads the figures anew.
  final bool shown;

  const AccountingStatsTab({super.key, this.shown = true});

  @override
  State<AccountingStatsTab> createState() => _AccountingStatsTabState();
}

class _AccountingStatsTabState extends State<AccountingStatsTab>
{
  // Kept while the app runs: back on the page, the same period shows.
  static String _shownPeriod = _defaultPeriod;

  final ApiService _api = ApiService();

  String _period = _shownPeriod;
  AccountingStats? _data;
  Object? _error;

  // Lordo, netto, ritenute.
  int _payView = 0;

  // A later answer for another period drops an earlier one.
  int _request = 0;

  @override
  void initState()
  {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(AccountingStatsTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.shown && !oldWidget.shown)
    {
      unawaited(_load());
    }
  }

  Future<void> _load() async
  {
    final int request = ++_request;
    final ({int? months, int? year}) parts = _partsOf(_period);

    try
    {
      final AccountingStats data = await _api.getAccountingStats(months: parts.months, year: parts.year);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _data = data;
        _error = null;
      });
    }
    catch (error)
    {
      if (!mounted || request != _request)
      {
        return;
      }

      setState(() => _error = error);
    }
  }

  void _choose(String period)
  {
    if (period == _period)
    {
      return;
    }

    setState(()
    {
      _period = period;
      _shownPeriod = period;
    });

    unawaited(_load());
  }

  List<FilterOption<String>> _options()
  {
    final int thisYear = romeNow().year;
    final int firstYear = _data?.firstYear ?? thisYear;

    return [
      for (final months in _lastMonths)
        FilterOption(value: 'last-$months', label: months == 1 ? kThisMonthPeriod : lastMonthsPeriod(months)),
      for (var year = thisYear; year >= firstYear; year--) FilterOption(value: 'year-$year', label: yearPeriod(year)),
    ];
  }

  Widget _buildNav()
  {
    return Align(
      alignment: Alignment.centerRight,
      child: AppFilterPill<String>.setting(
        prefix: kPeriodPrefix,
        hint: kPeriodPrefix,
        icon: Icons.event_note_rounded,
        value: _period,
        options: _options(),
        onChanged: _choose,
        menuWidth: 200,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final AccountingStats? data = _data;
    final Object? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final Object failure) when data == null => AppLoadFailedRoom(
          error: failure,
          message: readableApiError(failure),
          onRetry: _load,
        ),
      (final AccountingStats stats, _) => _StatsBody(
          stats: stats,
          lastMonths: _period.startsWith('last-'),
          payView: _payView,
          onPayView: (index) => setState(() => _payView = index),
        ),
      _ => const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
    };

    final bool dense = AppBreakpoints.of(context).isDense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.frame, child: _buildNav()),
        SizedBox(height: dense ? 14 : 18),
        Expanded(child: body),
      ],
    );
  }
}

class _StatsBody extends StatelessWidget
{
  final AccountingStats stats;
  final bool lastMonths;
  final int payView;
  final ValueChanged<int> onPayView;

  const _StatsBody({required this.stats, required this.lastMonths, required this.payView, required this.onPayView});

  List<DateTime> get _months => [for (final month in stats.months) month.month];

  TrendSpan? get _span => stats.spanOf(lastMonths: lastMonths);

  List<MemberTrendItem> _trend(int Function(AccountingMonth month) of) => [
        for (final month in stats.months)
          MemberTrendItem(year: month.month.year, month: month.month.month, totalMembers: of(month)),
      ];

  Widget _lineChart(BuildContext context, List<MemberTrendItem> data, TrendScale scale)
  {
    return SizedBox(
      height: statChartHeight(context, _chartHeight),
      child: TrendLineChart(
        data: data,
        isMonthly: true,
        span: _span,
        scale: scale,
        leftPadding: trendChartPadding([(data: data, scale: scale)]),
      ),
    );
  }

  // Figures side by side, one under the other in a narrow card: the width is handed down,
  // since a card matched to its neighbour may not measure itself.
  Widget _figures(BuildContext context, List<(String, String)> items, double width, {bool small = false})
  {
    final StatMetrics metrics = StatMetrics.of(context);
    final List<Widget> figures = [
      for (final (label, value) in items)
        small ? _SmallFigure(label: label, value: value) : StatFigure(label: label, value: value),
    ];

    if (width < metrics.figuresStackBelow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, figure) in figures.indexed) ...[
            if (index > 0) const StatRowDivider(),
            figure,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, figure) in figures.indexed) ...[
          if (index > 0) const StatDivider(),
          Expanded(child: figure),
        ],
      ],
    );
  }

  Widget _part(BuildContext context, Widget title, Widget chart)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
        const SizedBox(height: 16),
        title,
        const SizedBox(height: 12),
        chart,
      ],
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child})
  {
    return AppCard(title: title, leading: AppCardBadge(icon: icon), selectable: false, child: child);
  }

  Widget _tooltip(int index)
  {
    final AccountingMonth month = stats.months[index];

    return TrendTooltip(
      title: formatMonthYear(month.month),
      rows: [
        (value: formatAmount(month.totalIncomeCents), label: kIncomeSeries),
        (value: formatAmount(month.grossCents), label: kGrossSeries),
        (value: formatSignedAmount(month.balanceCents), label: kBalanceSeries),
      ],
    );
  }

  Widget _flowsCard(BuildContext context, double width)
  {
    final int income = stats.sum((month) => month.totalIncomeCents);
    final int gross = stats.sum((month) => month.grossCents);

    final List<MoneySeries> lines = [
      MoneySeries(
        label: kIncomeSeries,
        color: AppTheme.chartOcean,
        cents: [for (final month in stats.months) month.totalIncomeCents],
      ),
      MoneySeries(
        label: kGrossSeries,
        color: AppTheme.chartViolet,
        cents: [for (final month in stats.months) month.grossCents],
      ),
    ];

    return _card(
      title: kFlowsTitle,
      icon: Icons.account_balance_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _figures(context, [
            (kIncomeInPeriod, formatAmount(income)),
            (kGrossInPeriod, formatAmount(gross)),
            (kBalanceInPeriod, formatSignedAmount(income - gross)),
          ], width),
          _part(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatSectionTitle(kFlowsChart),
                const SizedBox(height: 10),
                TrendLegend(
                  series: [
                    for (final line in lines) TrendSeries(label: line.label, color: line.color, values: const []),
                  ],
                ),
              ],
            ),
            SizedBox(
              height: statChartHeight(context, _chartHeight),
              child: MoneyChart.lines(months: _months, lines: lines, span: _span, tooltip: _tooltip),
            ),
          ),
          _part(
            context,
            const StatSectionTitle(kBalanceChart),
            SizedBox(
              height: statChartHeight(context, _balanceHeight),
              child: MoneyChart.bars(
                months: _months,
                stacks: [for (final month in stats.months) [month.balanceCents]],
                stackColors: const [AppTheme.chartViolet],
                span: _span,
                tooltip: _tooltip,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _perHourCard(BuildContext context, double width)
  {
    final int pupilMinutes = stats.sum((month) => month.pupilMinutes);
    final int paidMinutes = stats.sum((month) => month.paidMinutes);

    String perHour(int cents, int minutes) => minutes == 0 ? '—' : formatAmount((cents * 60 / minutes).round());

    return _card(
      title: kPerHourTitle,
      icon: Icons.price_change_rounded,
      child: _figures(context, [
        (kIncomePerHour, perHour(stats.sum((month) => month.lessonIncomeCents), pupilMinutes)),
        (kPayPerHour, perHour(stats.sum((month) => month.grossCents), paidMinutes)),
      ], width),
    );
  }

  Widget _paySwitch(BuildContext context)
  {
    final double width = AppSegmentedTabs.widthOf(
      kPayViews,
      fontSize: _switchFont,
      scaler: MediaQuery.textScalerOf(context),
      segmentPadding: _switchPadding,
    );

    // Its size given: a matched card may not let it measure itself.
    return SizedBox(
      width: width,
      height: _switchHeight,
      child: AppSegmentedTabs(
        labels: kPayViews,
        selectedIndex: payView,
        onSelected: onPayView,
        height: _switchHeight,
        fontSize: _switchFont,
        padding: EdgeInsets.zero,
        hugContent: true,
        segmentPadding: _switchPadding,
      ),
    );
  }

  Widget _payCard(BuildContext context, double width)
  {
    final int Function(AccountingMonth month) shown = switch (payView)
    {
      1 => (month) => month.netCents,
      2 => (month) => month.withheldCents,
      _ => (month) => month.grossCents,
    };

    return _card(
      title: kPayTitle,
      icon: Icons.payments_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _figures(context, [
            (kGrossFigure, formatAmount(stats.sum((month) => month.grossCents))),
            (kNetFigure, formatAmount(stats.sum((month) => month.netCents))),
            (kWithheldFigure, formatAmount(stats.sum((month) => month.withheldCents))),
          ], width, small: true),
          _part(
            context,
            // A Row, not a Wrap: a Wrap measures its children by laying them out dry.
            Row(
              children: [
                Expanded(child: StatSectionTitle(kPayCharts[payView])),
                const SizedBox(width: 12),
                _paySwitch(context),
              ],
            ),
            _lineChart(context, _trend(shown), TrendScale.cents),
          ),
        ],
      ),
    );
  }

  Widget _incomeCard(BuildContext context, double width)
  {
    final int income = stats.sum((month) => month.incomeCents);
    final int count = stats.inPeriod.length;

    return _card(
      title: kIncomeTitle,
      icon: Icons.savings_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _figures(context, [
            (kCollectedFigure, formatAmount(income)),
            (kMonthlyMeanFigure, formatAmount(count == 0 ? 0 : (income / count).round())),
            (kPayersFigure, '${stats.payers}'),
          ], width, small: true),
          _part(
            context,
            const StatSectionTitle(kIncomeChart),
            _lineChart(context, _trend((month) => month.incomeCents), TrendScale.cents),
          ),
        ],
      ),
    );
  }

  Widget _kindsTooltip(int index)
  {
    final AccountingMonth month = stats.months[index];

    return TrendTooltip(
      title: formatMonthYear(month.month),
      rows: [
        for (final kind in kIncomeKinds)
          if (month.kind(kind) > 0) (value: formatAmount(month.kind(kind)), label: kIncomeKindLabels[kind]!),
      ],
    );
  }

  Widget _kindsCard(BuildContext context, double width)
  {
    final int total = stats.sum((month) => month.totalIncomeCents);

    return _card(
      title: kKindsTitle,
      icon: Icons.stacked_bar_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatSectionTitle(kKindsChart),
          const SizedBox(height: 12),
          SizedBox(
            height: statChartHeight(context, _chartHeight),
            child: MoneyChart.bars(
              months: _months,
              stacks: [
                for (final month in stats.months) [for (final kind in kIncomeKinds) month.kind(kind)],
              ],
              stackColors: _kindColors,
              span: _span,
              tooltip: _kindsTooltip,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
          const SizedBox(height: 8),
          for (final (index, kind) in kIncomeKinds.indexed)
            _KindRow(
              color: _kindColors[index],
              label: kIncomeKindLabels[kind]!,
              cents: stats.sum((month) => month.kind(kind)),
              total: total,
            ),
        ],
      ),
    );
  }

  Widget _volunteerCard(BuildContext context, double width)
  {
    return _card(
      title: kVolunteerTitle,
      icon: Icons.volunteer_activism_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _figures(context, [
            (kVolunteerHoursFigure, _hoursFigure(stats.sum((month) => month.volunteerMinutes))),
            (kVolunteerValueFigure, formatAmount(stats.sum((month) => month.volunteerValueCents))),
            (kVolunteersFigure, '${stats.volunteers}'),
          ], width, small: true),
          _part(
            context,
            const StatSectionTitle(kVolunteerChart),
            _lineChart(context, _trend((month) => month.volunteerMinutes), TrendScale.minutes),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);
    final double gap = metrics.cardGap;

    Widget whole(Widget Function(BuildContext context, double width) card) => LayoutBuilder(
          builder: (context, constraints) => card(context, constraints.maxWidth),
        );

    return PageTransitionScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageTransitionItem(slot: PageTransitionItem.header, child: whole(_flowsCard)),
            SizedBox(height: gap),
            PageTransitionItem(slot: PageTransitionItem.list, child: whole(_perHourCard)),
            SizedBox(height: gap),
            PageTransitionItem(
              slot: PageTransitionItem.list + 1,
              child: MatchedCardPair(
                first: (width, _) => _payCard(context, width),
                second: (width, _) => _incomeCard(context, width),
              ),
            ),
            SizedBox(height: gap),
            PageTransitionItem(
              slot: PageTransitionItem.list + 2,
              child: MatchedCardPair(
                first: (width, _) => _kindsCard(context, width),
                second: (width, _) => _volunteerCard(context, width),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A kind of money: its colour, its name, its amount and its share of the period.
class _KindRow extends StatelessWidget
{
  final Color color;
  final String label;
  final int cents;
  final int total;

  const _KindRow({required this.color, required this.label, required this.cents, required this.total});

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: metrics.rowSize,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );
    final int share = total == 0 ? 0 : (cents * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: style)),
          Text(formatAmount(cents), style: style.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialOcean)),
          SizedBox(width: 52, child: Text('$share%', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

// A pair's figures: three to a half card, so a size down from the page's, and each on one line.
class _SmallFigure extends StatelessWidget
{
  final String label;
  final String value;

  const _SmallFigure({required this.label, required this.value});

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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.plusJakartaSans(
              fontSize: metrics.dense ? 20 : 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ),
      ],
    );
  }
}
