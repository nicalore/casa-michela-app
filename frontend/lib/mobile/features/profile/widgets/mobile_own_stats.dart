import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/people/models/personal_statistics_items.dart';
import '../../../../features/people/tabs/person_personal_stats_tab.dart' show availabilityShortfalls;
import '../../../../features/people/tabs/statistics/widgets/stats_data.dart';
import '../../../../services/api_service.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_choice_chips.dart';
import '../../../shared/widgets/mobile_load_switcher.dart';
import 'mobile_detail_card.dart';
import 'mobile_trend_chart.dart';

// Held by the own page: its pages are not kept alive, and returning must not refetch.
class MobileOwnStatsController extends ChangeNotifier
{
  final String taxCode;

  final ApiService _apiService = ApiService();

  String period = defaultStatsPeriod;
  TeacherPersonalStatisticsItem? statistics;
  bool loading = false;

  int _request = 0;
  bool _disposed = false;

  MobileOwnStatsController(this.taxCode);

  Future<void> load() async
  {
    final int request = ++_request;
    final StatsPeriod parts = statsPeriodParts(period);

    loading = true;
    notifyListeners();

    try
    {
      final TeacherPersonalStatisticsItem fetched = await _apiService.getTeacherPersonalStatistics(
        taxCode,
        months: parts.months,
        year: parts.year,
        month: parts.month,
      );

      if (!_disposed && request == _request)
      {
        statistics = fetched;
      }
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle statistiche personali');
    }
    finally
    {
      if (!_disposed && request == _request)
      {
        loading = false;
        notifyListeners();
      }
    }
  }

  void choose(String? chosen)
  {
    if (chosen == null || chosen == period)
    {
      return;
    }

    period = chosen;
    load();
  }

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }
}

class MobileOwnStats extends StatelessWidget
{
  final MobileOwnStatsController controller;

  // The page margin, which the chips run past.
  final double margin;

  const MobileOwnStats({super.key, required this.controller, required this.margin});

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileChoiceChips(
            choices: [
              for (final option in statsPeriodOptions())
                MobileChoice(value: option.value, label: option.label),
            ],
            value: controller.period,
            margin: margin,
            onChanged: controller.choose,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: _buildCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildCard()
  {
    final TeacherPersonalStatisticsItem? statistics = controller.statistics;
    final bool loading = controller.loading;

    // Old figures stay while the next period loads: glass cannot be faded.
    final Widget? spinner = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialTealDeep),
          )
        : null;

    return MobileDetailCard(
      icon: Icons.event_available_rounded,
      title: 'Disponibilità',
      trailing: spinner,
      body: MobileLoadSwitcher(
        contained: true,
        waiting: statistics == null && loading,
        child: statistics == null
            ? (loading ? const SizedBox(height: 60) : const _NoData())
            : _Figures(statistics: statistics),
      ),
    );
  }
}

class _Figures extends StatelessWidget
{
  final TeacherPersonalStatisticsItem statistics;

  const _Figures({required this.statistics});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final shortfall in availabilityShortfalls(statistics, forOwner: true))
          _Shortfall(text: shortfall),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Figure(
                  value: statistics.weeklyAverage.toStringAsFixed(1),
                  label: 'Disponibilità a settimana',
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppTheme.trialInk.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _Figure(
                  value: '${statistics.totalAvailabilities}',
                  label: 'Totale nel periodo',
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 16, bottom: 14),
          color: AppTheme.trialInk.withValues(alpha: 0.1),
        ),
        Text(
          'Disponibilità per mese, ultimi 12 mesi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 8),
        if (statistics.monthlyTrend.isEmpty)
          const _NoData()
        else
          MobileTrendChart(data: statistics.monthlyTrend),
      ],
    );
  }
}

class _Figure extends StatelessWidget
{
  final String value;
  final String label;

  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
            color: AppTheme.trialTealDeep,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: MobilePalette.mutedText,
          ),
        ),
      ],
    );
  }
}

// Worded and coloured as on the desktop.
class _Shortfall extends StatelessWidget
{
  final String text;

  const _Shortfall({required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 19, color: AppTheme.modifiedAccent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppTheme.modifiedAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget
{
  const _NoData();

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          'Nessun dato',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: MobilePalette.mutedText,
          ),
        ),
      ),
    );
  }
}
