import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/week_range.dart';
import '../../../../../services/api_service.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../lessons/utils/opening_window.dart' show kPresenceMode;
import '../../../models/daily_trend_items.dart';
import 'daily_trend.dart';
import 'daily_trend_chart.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';
import 'stats_data.dart';

const Duration _fetchFade = Duration(milliseconds: 150);

const double _teachersChartHeight = 260;
const double _hoursChartHeight = 200;
const double _presenceChartHeight = 280;

// Validated as a pair on white; the tooltip's dark surface takes their lighter siblings.
const Color _availableColor = AppTheme.chartOcean;
const Color _convenedColor = AppTheme.chartViolet;
const Color _availableKey = AppTheme.chartOceanOnDark;
const Color _convenedKey = AppTheme.chartVioletOnDark;

// A third entity in the card: neither of the two series colours above.
const Color _hoursColor = AppTheme.chartNavy;

const String _defaultResolution = kTrendByWeek;

const String _averageSubtitle = 'Media giornaliera';

String _countAxis(int value) => '$value';

String _hoursAxis(int value) => '${value}h';

// Period, mode and resolution of a trend card; a stale answer never lands on the chart.
mixin _TrendFilters<W extends StatefulWidget, T> on State<W>
{
  final ApiService api = ApiService();
  final ValueNotifier<int?> hovered = ValueNotifier<int?>(null);

  String period = defaultStatsPeriod;
  String mode = kPresenceMode;
  String resolution = _defaultResolution;

  List<T>? days;
  bool isLoading = false;
  int _request = 0;

  Future<List<T>> fetch(StatsPeriod period, String mode);

  @override
  void initState()
  {
    super.initState();
    load();
  }

  @override
  void dispose()
  {
    hovered.dispose();
    super.dispose();
  }

  Future<void> load() async
  {
    final request = ++_request;
    setState(() => isLoading = true);

    try
    {
      final data = await fetch(statsPeriodParts(period), mode);

      if (mounted && request == _request)
      {
        setState(() => days = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted && request == _request)
      {
        setState(() => isLoading = false);
      }
    }
  }

  void choosePeriod(String value)
  {
    setState(() => period = value);
    load();
  }

  void chooseMode(String value)
  {
    setState(() => mode = value);
    load();
  }

  void chooseResolution(String value) => setState(() => resolution = value);

  Widget filters()
  {
    return StatFilterRow(
      children: [
        statsModePill(value: mode, onChanged: chooseMode),
        trendResolutionPill(value: resolution, onChanged: chooseResolution),
        statsPeriodPill(value: period, onChanged: choosePeriod),
      ],
    );
  }

  // Fixed heights, so the first answer and every refetch keep the card still.
  Widget chartArea(double height, Widget Function() chart)
  {
    final Widget child;

    if (days == null)
    {
      child = isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise))
          : const EmptyChartMessage();
    }
    else if (days!.isEmpty)
    {
      child = const EmptyChartMessage();
    }
    else
    {
      child = chart();
    }

    return SizedBox(height: height, child: child);
  }

  Widget fading(Widget child)
  {
    return AnimatedOpacity(
      opacity: isLoading && days != null ? 0.4 : 1,
      duration: _fetchFade,
      child: child,
    );
  }
}

class TeacherActivityTrendCard extends StatefulWidget
{
  const TeacherActivityTrendCard({super.key});

  @override
  State<TeacherActivityTrendCard> createState() => _TeacherActivityTrendCardState();
}

class _TeacherActivityTrendCardState extends State<TeacherActivityTrendCard>
    with _TrendFilters<TeacherActivityTrendCard, TeacherActivityDayItem>
{
  static const String _availableLabel = 'Docenti disponibili';
  static const String _convenedLabel = 'Docenti convocati';
  static const String _hoursLabel = 'Ore di lezione erogate';

  static const String _availableOne = 'Docente disponibile';
  static const String _convenedOne = 'Docente convocato';
  static const String _hoursOne = 'Ora di lezione erogata';

  @override
  Future<List<TeacherActivityDayItem>> fetch(StatsPeriod period, String mode)
  {
    return api.getTeacherActivityTrend(
      months: period.months,
      year: period.year,
      month: period.month,
      mode: mode,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final loaded = days ?? const <TeacherActivityDayItem>[];
    final buckets = trendBuckets([for (final day in loaded) day.date], resolution);

    List<double> valuesOf(int Function(TeacherActivityDayItem day) pick)
    {
      final daily = [for (final day in loaded) pick(day)];

      return [for (final bucket in buckets) bucket.valueOf(daily)];
    }

    final available = valuesOf((day) => day.available);
    final convened = valuesOf((day) => day.convened);
    final minutes = valuesOf((day) => day.lessonMinutes);
    final axisLabels = [for (final bucket in buckets) bucket.axisLabel];

    final teachers = [
      TrendSeries(label: _availableLabel, color: _availableColor, values: available),
      TrendSeries(label: _convenedLabel, color: _convenedColor, values: convened),
    ];
    final hours = [
      TrendSeries(
        label: _hoursLabel,
        color: _hoursColor,
        values: [for (final value in minutes) value / 60],
      ),
    ];

    Widget tooltip(int index)
    {
      final bucket = buckets[index];
      final shownAvailable = formatTrendCount(available[index], average: bucket.isAverage);
      final shownConvened = formatTrendCount(convened[index], average: bucket.isAverage);
      final lessonMinutes = minutes[index].round();

      return TrendTooltip(
        title: bucket.title,
        subtitle: bucket.isAverage ? _averageSubtitle : null,
        rows: [
          (
            color: _availableKey,
            value: shownAvailable,
            label: trendCountLabel(shownAvailable, one: _availableOne, many: _availableLabel),
          ),
          (
            color: _convenedKey,
            value: shownConvened,
            label: trendCountLabel(shownConvened, one: _convenedOne, many: _convenedLabel),
          ),
          (
            color: null,
            value: lessonMinutes == 0 ? '0' : formatMinutes(lessonMinutes),
            label: lessonMinutes == 60 ? _hoursOne : _hoursLabel,
          ),
        ],
      );
    }

    return AppCard(
      title: 'Andamento convocazioni',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.timeline_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: filters(),
      child: fading(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrendLegend(series: teachers),
            const SizedBox(height: 20),
            chartArea(
              _teachersChartHeight,
              () => DailyTrendChart(
                axisLabels: axisLabels,
                series: teachers,
                formatAxis: _countAxis,
                hovered: hovered,
                tooltip: tooltip,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _hoursLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
            const SizedBox(height: 20),
            chartArea(
              _hoursChartHeight,
              () => DailyTrendChart(
                axisLabels: axisLabels,
                series: hours,
                formatAxis: _hoursAxis,
                hovered: hovered,
                tooltip: tooltip,
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PresenceTrendCard extends StatefulWidget
{
  const PresenceTrendCard({super.key});

  @override
  State<PresenceTrendCard> createState() => _PresenceTrendCardState();
}

class _PresenceTrendCardState extends State<PresenceTrendCard>
    with _TrendFilters<PresenceTrendCard, PresenceDayItem>
{
  @override
  Future<List<PresenceDayItem>> fetch(StatsPeriod period, String mode)
  {
    return api.getStudentPresenceTrend(
      months: period.months,
      year: period.year,
      month: period.month,
      mode: mode,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final loaded = days ?? const <PresenceDayItem>[];
    final buckets = trendBuckets([for (final day in loaded) day.date], resolution);
    final daily = [for (final day in loaded) day.studentCount];
    final students = [for (final bucket in buckets) bucket.valueOf(daily)];

    final series = [
      TrendSeries(label: 'Studenti presenti', color: AppTheme.chartOcean, values: students, gradient: true),
    ];

    Widget tooltip(int index)
    {
      final bucket = buckets[index];
      final shown = formatTrendCount(students[index], average: bucket.isAverage);

      return TrendTooltip(
        title: bucket.title,
        subtitle: bucket.isAverage ? _averageSubtitle : null,
        rows: [
          (color: null, value: shown, label: trendCountLabel(shown, one: 'studente', many: 'studenti')),
        ],
      );
    }

    return AppCard(
      title: 'Andamento presenze',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.timeline_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: filters(),
      child: fading(
        chartArea(
          _presenceChartHeight,
          () => DailyTrendChart(
            axisLabels: [for (final bucket in buckets) bucket.axisLabel],
            series: series,
            formatAxis: _countAxis,
            hovered: hovered,
            tooltip: tooltip,
            filled: true,
          ),
        ),
      ),
    );
  }
}
