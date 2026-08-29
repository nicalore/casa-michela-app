import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_transition.dart';
import '../models/person_item.dart';
import '../models/personal_statistics_items.dart';
import '../models/student_presence_statistics_item.dart';
import 'statistics/widgets/stat_filters.dart';
import 'statistics/widgets/stat_widgets.dart';
import 'statistics/widgets/stats_data.dart';
import 'statistics/widgets/trend_line_chart.dart';

const Color _sectionDivider = AppTheme.trialLine;

const Duration _fetchFade = Duration(milliseconds: 150);

const double _chartHeight = 280;

// Ranking size; must match the backend limit.
const int _requestsLimit = 10;

class PersonPersonalStatsTab extends StatefulWidget
{
  final PersonItem person;

  const PersonPersonalStatsTab({super.key, required this.person});

  @override
  State<PersonPersonalStatsTab> createState() => _PersonPersonalStatsTabState();
}

class _PersonPersonalStatsTabState extends State<PersonPersonalStatsTab>
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  TeacherPersonalStatisticsItem? _teacherStats;
  StudentPersonalStatisticsItem? _studentStats;

  bool _isTeacherLoading = false;
  bool _isStudentLoading = false;

  String _teacherPeriod = defaultStatsPeriod;
  String _studentPeriod = defaultStatsPeriod;

  bool get _isTeacher => widget.person.roles
      .map((role) => role.toUpperCase())
      .contains('DOCENTE');

  bool get _isStudent => widget.person.roles
      .map((role) => role.toUpperCase())
      .contains('STUDENTE');

  @override
  void initState()
  {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async
  {
    setState(() => _isLoading = true);

    await Future.wait([
      if (_isTeacher) _loadTeacherStats(),
      if (_isStudent) _loadStudentStats(),
    ]);

    if (mounted)
    {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeacherStats() async
  {
    setState(() => _isTeacherLoading = true);

    try
    {
      final period = statsPeriodParts(_teacherPeriod);

      final data = await _apiService.getTeacherPersonalStatistics(
        widget.person.fiscalCode,
        months: period.months,
        year: period.year,
        month: period.month,
      );

      if (mounted)
      {
        setState(() => _teacherStats = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isTeacherLoading = false);
      }
    }
  }

  Future<void> _loadStudentStats() async
  {
    setState(() => _isStudentLoading = true);

    try
    {
      final period = statsPeriodParts(_studentPeriod);

      final data = await _apiService.getStudentPersonalStatistics(
        widget.person.fiscalCode,
        months: period.months,
        year: period.year,
        month: period.month,
      );

      if (mounted)
      {
        setState(() => _studentStats = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isStudentLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
      );
    }

    final teacherStats = _teacherStats;
    final studentStats = _studentStats;

    final cards = <Widget>[
      if (teacherStats != null)
        PersonalAvailabilityCard(
          statistics: teacherStats,
          period: _teacherPeriod,
          isLoading: _isTeacherLoading,
          onPeriodChanged: (value)
          {
            setState(() => _teacherPeriod = value);
            _loadTeacherStats();
          },
        ),
      if (teacherStats != null)
        PersonalAppreciationCard(statistics: teacherStats),
      if (studentStats != null)
        PersonalPresenceCard(
          statistics: studentStats,
          period: _studentPeriod,
          isLoading: _isStudentLoading,
          onPeriodChanged: (value)
          {
            setState(() => _studentPeriod = value);
            _loadStudentStats();
          },
        ),
    ];

    if (cards.isEmpty)
    {
      return const Center(child: EmptyChartMessage());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pageTransitionBlocks([
          for (final card in cards) ...[
            card,
            const SizedBox(height: 24),
          ],
        ]),
      ),
    );
  }
}

class _Figure extends StatelessWidget
{
  final String label;
  final String value;

  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context)
  {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalAvailabilityCard extends StatelessWidget
{
  final TeacherPersonalStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;

  const PersonalAvailabilityCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  Widget _banner(String message)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppTheme.modifiedAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.modifiedAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final banners = <Widget>[
      if (statistics.isBelowWeeklyThreshold)
        _banner(
          'Nel periodo selezionato la media è sotto le 2 disponibilità a '
          'settimana (${statistics.weeklyAverage.toStringAsFixed(1)}).',
        ),
      if (statistics.isBelowMonthlyThreshold)
        _banner(
          'Nel mese selezionato ha dato meno di 9 disponibilità '
          '(${statistics.totalAvailabilities}).',
        ),
    ];

    return AppCard(
      title: 'Disponibilità',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.event_available_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: statsPeriodPill(value: period, onChanged: onPeriodChanged),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banners.isNotEmpty) ...[
              ...banners,
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                _Figure(
                  label: 'Disponibilità a settimana',
                  value: statistics.weeklyAverage.toStringAsFixed(1),
                ),
                const StatDivider(),
                _Figure(
                  label: 'Totale nel periodo',
                  value: '${statistics.totalAvailabilities}',
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: _sectionDivider, thickness: 1),
            const SizedBox(height: 32),
            const StatSectionTitle('Disponibilità per mese, ultimi 12 mesi'),
            const SizedBox(height: 24),
            SizedBox(
              height: _chartHeight,
              child: statistics.monthlyTrend.isEmpty
                  ? const EmptyChartMessage()
                  : TrendLineChart(
                      data: statistics.monthlyTrend,
                      isMonthly: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalAppreciationCard extends StatelessWidget
{
  final TeacherPersonalStatisticsItem statistics;

  const PersonalAppreciationCard({super.key, required this.statistics});

  Widget _side({
    required String label,
    required int count,
    required int? rank,
    required Color accent,
  })
  {
    final unit = count == 1 ? 'richiesta' : 'richieste';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rank == null ? 'Mai indicato' : '$rank° in classifica',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'Gradimento',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.emoji_events_rounded),
      child: Row(
        children: [
          _side(
            label: 'Indicato come preferito',
            count: statistics.preferredCount,
            rank: statistics.preferredRank,
            accent: AppTheme.trialViolet,
          ),
          const StatDivider(),
          _side(
            label: 'Indicato come non gradito',
            count: statistics.notPreferredCount,
            rank: statistics.notPreferredRank,
            accent: AppTheme.trialDeepWater,
          ),
        ],
      ),
    );
  }
}

class PersonalPresenceCard extends StatefulWidget
{
  final StudentPersonalStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;

  const PersonalPresenceCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  @override
  State<PersonalPresenceCard> createState() => _PersonalPresenceCardState();
}

class _PersonalPresenceCardState extends State<PersonalPresenceCard>
{
  RequestedSubjectKind _kind = RequestedSubjectKind.ministrySubject;

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'Presenze e richieste',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.event_seat_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: StatFilterRow(
        children: [
          requestedKindPill(
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
          ),
          statsPeriodPill(value: widget.period, onChanged: widget.onPeriodChanged),
        ],
      ),
      child: AnimatedOpacity(
        opacity: widget.isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Figure(
                  label: 'Giorni di presenza a settimana',
                  value: widget.statistics.weeklyPresenceDays.toStringAsFixed(1),
                ),
                const StatDivider(),
                _Figure(
                  label: 'Giorni totali nel periodo',
                  value: '${widget.statistics.totalPresenceDays}',
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: _sectionDivider, thickness: 1),
            const SizedBox(height: 32),
            const StatSectionTitle('Presenze per mese, ultimi 12 mesi'),
            const SizedBox(height: 24),
            SizedBox(
              height: _chartHeight,
              child: widget.statistics.monthlyTrend.isEmpty
                  ? const EmptyChartMessage()
                  : TrendLineChart(data: widget.statistics.monthlyTrend, isMonthly: true),
            ),
            const SizedBox(height: 32),
            const Divider(color: _sectionDivider, thickness: 1),
            const SizedBox(height: 32),
            RequestedSubjectsSection(
              rankings: widget.statistics.requested,
              kind: _kind,
              limit: _requestsLimit,
            ),
          ],
        ),
      ),
    );
  }
}
