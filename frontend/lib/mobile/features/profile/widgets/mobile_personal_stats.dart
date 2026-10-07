import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/people/models/personal_statistics_items.dart';
import '../../../../features/people/models/student_presence_statistics_item.dart';
import '../../../../features/people/tabs/person_personal_stats_tab.dart'
    show availabilityShortfalls, kRequestedSubjectsLimit, presenceDaysPerWeekLabel, presenceTrendTitle;
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/people/tabs/statistics/widgets/stats_data.dart';
import '../../../../services/api_service.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_choice_chips.dart';
import 'mobile_detail_card.dart';
import 'mobile_trend_chart.dart';

// Held by the page: its pages are not kept alive, and returning must not refetch.
abstract class MobileStatsController<T> extends ChangeNotifier
{
  final ApiService _api = ApiService();

  String taxCode;

  String period = defaultStatsPeriod;
  String mode = kPresenceMode;
  T? statistics;

  // Mode of the shown [statistics]: words the labels while the next loads.
  String shownMode = kPresenceMode;
  bool loading = false;

  int _request = 0;
  bool _disposed = false;

  MobileStatsController(this.taxCode);

  Future<T> fetch(StatsPeriod period);

  Future<void> load() async
  {
    final int request = ++_request;
    final StatsPeriod parts = statsPeriodParts(period);
    final String asked = mode;

    loading = true;
    notifyListeners();

    try
    {
      final T fetched = await fetch(parts);

      if (!_disposed && request == _request)
      {
        statistics = fetched;
        shownMode = asked;
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

  void chooseMode(String? chosen)
  {
    if (chosen == null || chosen == mode)
    {
      return;
    }

    mode = chosen;
    load();
  }

  // Same period, another person: old figures must not show under the new name.
  void follow(String other)
  {
    if (other == taxCode)
    {
      return;
    }

    taxCode = other;
    statistics = null;
    load();
  }

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }
}

class MobileTeacherStatsController extends MobileStatsController<TeacherPersonalStatisticsItem>
{
  MobileTeacherStatsController(super.taxCode);

  @override
  Future<TeacherPersonalStatisticsItem> fetch(StatsPeriod period)
  {
    return _api.getTeacherPersonalStatistics(
      taxCode,
      months: period.months,
      year: period.year,
      month: period.month,
      mode: mode,
    );
  }
}

class MobilePupilStatsController extends MobileStatsController<StudentPersonalStatisticsItem>
{
  RequestedSubjectKind kind = RequestedSubjectKind.ministrySubject;

  MobilePupilStatsController(super.taxCode);

  @override
  Future<StudentPersonalStatisticsItem> fetch(StatsPeriod period)
  {
    return _api.getStudentPersonalStatistics(
      taxCode,
      months: period.months,
      year: period.year,
      month: period.month,
      mode: mode,
    );
  }

  void chooseKind(String? chosen)
  {
    final RequestedSubjectKind? picked = RequestedSubjectKind.values.asNameMap()[chosen];

    if (picked != null && picked != kind)
    {
      kind = picked;
      notifyListeners();
    }
  }
}

class MobileTeacherStats extends StatelessWidget
{
  final MobileTeacherStatsController controller;

  final double margin;

  const MobileTeacherStats({super.key, required this.controller, required this.margin});

  @override
  Widget build(BuildContext context)
  {
    return _StatsBlock(
      controller: controller,
      margin: margin,
      icon: Icons.event_available_rounded,
      title: 'Disponibilità',
      figures: (statistics) => _TeacherFigures(statistics: statistics),
    );
  }
}

class MobilePupilStats extends StatelessWidget
{
  final MobilePupilStatsController controller;

  final double margin;

  const MobilePupilStats({super.key, required this.controller, required this.margin});

  @override
  Widget build(BuildContext context)
  {
    return _StatsBlock(
      controller: controller,
      margin: margin,
      icon: Icons.event_seat_rounded,
      title: 'Presenze e richieste',
      figures: (statistics) => _PupilFigures(statistics: statistics, controller: controller),
    );
  }
}

class _StatsBlock<T> extends StatelessWidget
{
  final MobileStatsController<T> controller;
  final double margin;

  final IconData icon;
  final String title;
  final Widget Function(T statistics) figures;

  const _StatsBlock({
    required this.controller,
    required this.margin,
    required this.icon,
    required this.title,
    required this.figures,
  });

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
              for (final mode in const [kPresenceMode, kOnlineMode])
                MobileChoice(value: mode, label: modeLabel(mode)),
            ],
            value: controller.mode,
            margin: margin,
            onChanged: controller.chooseMode,
          ),
          const SizedBox(height: 10),
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
    final T? statistics = controller.statistics;
    final bool loading = controller.loading;

    // Old figures stay while the next period loads: glass cannot be faded.
    final Widget? spinner = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialTealDeep),
          )
        : null;

    return MobileDetailCard(
      icon: icon,
      title: title,
      trailing: spinner,
      body: statistics == null
          ? (loading ? const SizedBox(height: 60) : const _NoData())
          : figures(statistics),
    );
  }
}

class _TeacherFigures extends StatelessWidget
{
  final TeacherPersonalStatisticsItem statistics;

  const _TeacherFigures({required this.statistics});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final shortfall in availabilityShortfalls(statistics, forOwner: true))
          _Shortfall(text: shortfall),
        _FigurePair(
          first: _Figure(
            value: statistics.weeklyAverage.toStringAsFixed(1),
            label: 'Disponibilità a settimana',
          ),
          second: _Figure(
            value: '${statistics.totalAvailabilities}',
            label: 'Totale nel periodo',
          ),
        ),
        const _Hairline(),
        const _SectionTitle('Disponibilità per mese, ultimi 12 mesi'),
        const SizedBox(height: 8),
        if (statistics.monthlyTrend.isEmpty)
          const _NoData()
        else
          MobileTrendChart(data: statistics.monthlyTrend),
      ],
    );
  }
}

class _PupilFigures extends StatelessWidget
{
  final StudentPersonalStatisticsItem statistics;
  final MobilePupilStatsController controller;

  const _PupilFigures({required this.statistics, required this.controller});

  @override
  Widget build(BuildContext context)
  {
    final RequestedSubjectKind kind = controller.kind;
    final List<RequestedSubjectItem> requested = statistics.requested.of(kind);
    final bool online = controller.shownMode == kOnlineMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FigurePair(
          first: _Figure(
            value: statistics.weeklyPresenceDays.toStringAsFixed(1),
            label: presenceDaysPerWeekLabel(online: online),
          ),
          second: _Figure(
            value: '${statistics.totalPresenceDays}',
            label: 'Giorni totali nel periodo',
          ),
        ),
        const _Hairline(),
        _SectionTitle(presenceTrendTitle(online: online)),
        const SizedBox(height: 8),
        if (statistics.monthlyTrend.isEmpty)
          const _NoData()
        else
          MobileTrendChart(data: statistics.monthlyTrend),
        const _Hairline(),
        _SectionTitle('$kRequestedSubjectsLimit ${kind.rankingTitle}'),
        const SizedBox(height: 10),
        MobileChoiceChips(
          choices: [
            for (final option in RequestedSubjectKind.values)
              MobileChoice(value: option.name, label: option.label),
          ],
          value: kind.name,
          margin: 0,
          onLight: true,
          onChanged: controller.chooseKind,
        ),
        const SizedBox(height: 8),
        if (requested.isEmpty)
          const _NoData()
        else
          for (var i = 0; i < requested.length; i++) _Requested(subject: requested[i], first: i == 0),
      ],
    );
  }
}

class _Requested extends StatelessWidget
{
  final RequestedSubjectItem subject;
  final bool first;

  const _Requested({required this.subject, required this.first});

  @override
  Widget build(BuildContext context)
  {
    final String unit = subject.requestCount == 1 ? 'richiesta' : 'richieste';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.09))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                subject.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppTheme.trialInk,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${subject.percentage.toStringAsFixed(1)}%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: MobilePalette.mutedText,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.trialTealDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${subject.requestCount} $unit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialTealDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigurePair extends StatelessWidget
{
  final Widget first;
  final Widget second;

  const _FigurePair({required this.first, required this.second});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppTheme.trialInk.withValues(alpha: 0.12),
          ),
          Expanded(child: second),
        ],
      ),
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

class _Hairline extends StatelessWidget
{
  const _Hairline();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(top: 16, bottom: 14),
      color: AppTheme.trialInk.withValues(alpha: 0.1),
    );
  }
}

class _SectionTitle extends StatelessWidget
{
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppTheme.trialInk,
      ),
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
