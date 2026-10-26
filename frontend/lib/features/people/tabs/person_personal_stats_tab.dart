import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart' show formatMinutes;
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../lessons/utils/opening_window.dart' show kOnlineMode, kPresenceMode;
import '../models/person_item.dart';
import '../children_tour.dart';
import '../own_tour.dart';
import '../models/personal_statistics_items.dart';
import '../models/student_presence_statistics_item.dart';
import 'statistics/widgets/appreciation_students_dialog.dart';
import 'statistics/widgets/stat_filters.dart';
import 'statistics/widgets/stat_widgets.dart';
import 'statistics/widgets/stats_data.dart';
import 'statistics/widgets/stats_layout.dart';
import 'statistics/widgets/trend_line_chart.dart';

const Color _sectionDivider = AppTheme.trialLine;

const Duration _fetchFade = Duration(milliseconds: 150);

const double _chartHeight = 280;

// Dense Gradimento card: thirds from the first width, each piece its own width down to the second, then wrapped.
const double _appreciationThirdsFrom = 600;
const double _appreciationWrapBelow = 400;

// Ranking size; must match the backend limits.
const int kRankingLimit = 10;

// Shared with the mobile cards.
const String kPupilStatsTitle = 'Presenze e lezioni';
const String kTeacherStatsTitle = 'Disponibilità e lezioni';
const String kTopTeachersTitle = '$kRankingLimit docenti con più ore';
const String kTaughtDisciplinesTitle = '$kRankingLimit discipline più insegnate';
const String kTopStudentsTitle = '$kRankingLimit studenti più seguiti';

String subjectHoursTitle(RequestedSubjectKind kind) => '$kRankingLimit ${kind.hoursTitle}';

class PersonPersonalStatsTab extends StatefulWidget
{
  final PersonItem person;

  // The teacher's own page: no appreciation, and the notices speak to them.
  final bool forOwner;

  // Rendered under the cards, inside the scroll.
  final Widget? footer;

  // A parent's tour lights the presence card and its mode and period.
  final bool childTour;

  const PersonPersonalStatsTab({
    super.key,
    required this.person,
    this.forOwner = false,
    this.footer,
    this.childTour = false,
  });

  @override
  State<PersonPersonalStatsTab> createState() => _PersonPersonalStatsTabState();
}

class _PersonPersonalStatsTabState extends State<PersonPersonalStatsTab>
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  TeacherPersonalStatisticsItem? _teacherStats;
  TeacherAppreciationStatisticsItem? _appreciationStats;
  StudentPersonalStatisticsItem? _studentStats;

  // The mode _studentStats was fetched in; the pill may already show the next one.
  String _studentStatsMode = kPresenceMode;

  bool _isTeacherLoading = false;
  bool _isAppreciationLoading = false;
  bool _isStudentLoading = false;

  String _teacherPeriod = defaultStatsPeriod;
  String _appreciationPeriod = defaultStatsPeriod;
  String _studentPeriod = defaultStatsPeriod;

  String _teacherMode = kPresenceMode;
  String _studentMode = kPresenceMode;

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
      if (_isTeacher && !widget.forOwner) _loadAppreciationStats(),
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
        mode: _teacherMode,
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

  Future<void> _loadAppreciationStats() async
  {
    setState(() => _isAppreciationLoading = true);

    try
    {
      final period = statsPeriodParts(_appreciationPeriod);

      final data = await _apiService.getTeacherAppreciationStatistics(
        widget.person.fiscalCode,
        months: period.months,
        year: period.year,
        month: period.month,
      );

      if (mounted)
      {
        setState(() => _appreciationStats = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isAppreciationLoading = false);
      }
    }
  }

  Future<void> _loadStudentStats() async
  {
    setState(() => _isStudentLoading = true);

    try
    {
      final period = statsPeriodParts(_studentPeriod);

      final mode = _studentMode;
      final data = await _apiService.getStudentPersonalStatistics(
        widget.person.fiscalCode,
        months: period.months,
        year: period.year,
        month: period.month,
        mode: mode,
      );

      if (mounted)
      {
        setState(()
        {
          _studentStats = data;
          _studentStatsMode = mode;
        });
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
    final appreciationStats = _appreciationStats;
    final studentStats = _studentStats;

    final cards = <Widget>[
      if (teacherStats != null)
        PersonalAvailabilityCard(
          tour: widget.forOwner,
          statistics: teacherStats,
          period: _teacherPeriod,
          mode: _teacherMode,
          isLoading: _isTeacherLoading,
          forOwner: widget.forOwner,
          onPeriodChanged: (value)
          {
            setState(() => _teacherPeriod = value);
            _loadTeacherStats();
          },
          onModeChanged: (value)
          {
            setState(() => _teacherMode = value);
            _loadTeacherStats();
          },
        ),
      if (appreciationStats != null)
        PersonalAppreciationCard(
          teacher: widget.person,
          statistics: appreciationStats,
          period: _appreciationPeriod,
          isLoading: _isAppreciationLoading,
          onPeriodChanged: (value)
          {
            setState(() => _appreciationPeriod = value);
            _loadAppreciationStats();
          },
        ),
      if (studentStats != null)
        PersonalPresenceCard(
          tour: widget.childTour
              ? (card: kTourChildrenStats, mode: kTourChildrenMode, period: kTourChildrenPeriod)
              : widget.forOwner && teacherStats == null
                  ? (card: kTourOwnStats, mode: kTourOwnMode, period: kTourOwnPeriod)
                  : null,
          statistics: studentStats,
          period: _studentPeriod,
          mode: _studentMode,
          shownMode: _studentStatsMode,
          isLoading: _isStudentLoading,
          onPeriodChanged: (value)
          {
            setState(() => _studentPeriod = value);
            _loadStudentStats();
          },
          onModeChanged: (value)
          {
            setState(() => _studentMode = value);
            _loadStudentStats();
          },
        ),
    ];

    final Widget? footer = widget.footer;

    if (cards.isEmpty)
    {
      return AppEmptyRoom(
        card: const AppEmptyCard(icon: Icons.insights_rounded, message: 'Nessun dato'),
        below: [?footer],
      );
    }

    // Dense below the wide window wherever the tab sits (the children's page included), its footer as the page has it.
    final bool dense = AppBreakpoints.of(context).isDense;
    final double gap = StatMetrics.forDensity(dense).cardGap;

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: pageTransitionBlocks([
            for (final card in cards) ...[
              AppPageDensity(dense: dense, child: card),
              SizedBox(height: gap),
            ],
            if (footer != null) ...[
              SizedBox(height: gap),
              footer,
            ],
          ]),
        ),
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
    return Expanded(child: StatFigure(label: label, value: value));
  }
}

String presenceDaysPerWeekLabel({required bool online})
{
  return online ? 'Giorni di presenza online a settimana' : 'Giorni di presenza a settimana';
}

String presenceTrendTitle({required bool online})
{
  return online ? 'Presenze online per mese, ultimi 12 mesi' : 'Presenze per mese, ultimi 12 mesi';
}

List<String> availabilityShortfalls(TeacherPersonalStatisticsItem statistics, {required bool forOwner})
{
  return [
    if (statistics.shortWeekCount > 0)
      'Settimane con meno di 2 disponibilità: ${statistics.shortWeekCount}.',
    if (statistics.isBelowMonthlyThreshold)
      'Nel mese selezionato ${forOwner ? 'hai' : 'ha'} dato meno di 9 disponibilità '
          '(${statistics.totalAvailabilities}).',
  ];
}

ShareRankingSection _subjectHoursRanking(String title, List<SubjectHoursItem> subjects)
{
  return ShareRankingSection(
    title: title,
    rows: [
      for (var index = 0; index < subjects.length; index++)
        ShareRankRow(
          position: index + 1,
          name: subjects[index].name,
          percentage: subjects[index].percentage,
          badgeText: formatMinutes(subjects[index].minutes),
        ),
    ],
  );
}

ShareRankingSection _peopleHoursRanking(String title, List<PersonHoursItem> people)
{
  return ShareRankingSection(
    title: title,
    rows: [
      for (var index = 0; index < people.length; index++)
        ShareRankRow(
          position: index + 1,
          name: people[index].person.fullName,
          percentage: people[index].percentage,
          badgeText: formatMinutes(people[index].minutes),
        ),
    ],
  );
}

class PersonalAvailabilityCard extends StatelessWidget
{
  final TeacherPersonalStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  // Online is never flagged: the backend answers it with no shortfall.
  final String mode;
  final ValueChanged<String> onModeChanged;

  final bool isLoading;
  final bool forOwner;

  // Lit by the owner's tour: the card, and its filters.
  final bool tour;

  const PersonalAvailabilityCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    required this.mode,
    required this.onModeChanged,
    this.isLoading = false,
    this.forOwner = false,
    this.tour = false,
  });

  Widget _banner(String message, bool dense)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 16, vertical: dense ? 10 : 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(dense ? 14 : 16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: dense ? 19 : 20,
            color: AppTheme.modifiedAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: dense ? 13 : 14,
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
    final StatMetrics metrics = StatMetrics.of(context);
    final banners = [
      for (final shortfall in availabilityShortfalls(statistics, forOwner: forOwner)) _banner(shortfall, metrics.dense),
    ];

    return DesktopTourTarget(
      id: tour ? kTourOwnStats : null,
      child: AppCard(
        title: kTeacherStatsTitle,
        selectable: false,
        leading: const AppCardBadge(icon: Icons.event_available_rounded),
        trailingFit: AppCardTrailing.wrapping,
        trailing: DesktopTourTarget(
          id: tour ? kTourOwnFilters : null,
          child: StatFilterRow(
            children: [
              statsModePill(value: mode, onChanged: onModeChanged),
              statsPeriodPill(value: period, onChanged: onPeriodChanged),
            ],
          ),
        ),
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
              const StatPartDivider(color: _sectionDivider),
              const StatSectionTitle('Disponibilità per mese, ultimi 12 mesi'),
              SizedBox(height: metrics.titleGap),
              SizedBox(
                height: statChartHeight(context, _chartHeight),
                child: statistics.monthlyTrend.isEmpty
                    ? const EmptyChartMessage()
                    : TrendLineChart(
                        data: statistics.monthlyTrend,
                        isMonthly: true,
                      ),
              ),
              const StatPartDivider(color: _sectionDivider),
              RankingPair(
                first: _subjectHoursRanking(kTaughtDisciplinesTitle, statistics.taughtDisciplines),
                second: _peopleHoursRanking(kTopStudentsTitle, statistics.topStudents),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonalAppreciationCard extends StatelessWidget
{
  final PersonItem teacher;
  final TeacherAppreciationStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;

  const PersonalAppreciationCard({
    super.key,
    required this.teacher,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  void _showStudents(BuildContext context, {required bool up})
  {
    showAppreciationStudentsDialog(
      context,
      taxCode: teacher.fiscalCode,
      period: period,
      up: up,
    );
  }

  Widget _place(bool dense)
  {
    final rank = statistics.rank;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 14, vertical: dense ? 6 : 8),
      decoration: BoxDecoration(
        color: AppTheme.trialDeepWater.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rank == null ? 'Non in classifica' : '$rank° in classifica',
        maxLines: 1,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 13 : 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialDeepWater,
        ),
      ),
    );
  }

  Widget _thumbs(BuildContext context)
  {
    return ThumbCounts(
      up: statistics.preferringStudentCount,
      down: statistics.avoidingStudentCount,
      large: true,
      onUpTap: () => _showStudents(context, up: true),
      onDownTap: () => _showStudents(context, up: false),
    );
  }

  // Dense, the score and two centred thirds while they fit; then place and thumbs at their own width, then under the score.
  Widget _denseFigures(BuildContext context)
  {
    final Widget score = StatFigure(label: 'Punteggio', value: formatAppreciationScore(statistics.score));

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth >= _appreciationThirdsFrom)
        {
          return Row(
            children: [
              Expanded(child: score),
              const StatDivider(),
              Expanded(child: Center(child: _place(true))),
              const StatDivider(),
              Expanded(child: Center(child: _thumbs(context))),
            ],
          );
        }

        if (constraints.maxWidth < _appreciationWrapBelow)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              score,
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [_place(true), _thumbs(context)],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: score),
            const StatDivider(),
            _place(true),
            const StatDivider(),
            _thumbs(context),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'Gradimento',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.emoji_events_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: statsPeriodPill(value: period, onChanged: onPeriodChanged),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: StatMetrics.of(context).dense
            ? _denseFigures(context)
            : Row(
                children: [
                  _Figure(
                    label: 'Punteggio',
                    value: formatAppreciationScore(statistics.score),
                  ),
                  const StatDivider(),
                  Expanded(child: Center(child: _place(false))),
                  const StatDivider(),
                  Expanded(child: Center(child: _thumbs(context))),
                ],
              ),
      ),
    );
  }
}

class PersonalPresenceCard extends StatefulWidget
{
  final StudentPersonalStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final String mode;
  final ValueChanged<String> onModeChanged;

  // The mode of [statistics], which words the labels.
  final String shownMode;

  final bool isLoading;

  // Lit by a parent's tour or the student's own: the card, its mode and its period.
  final ({String card, String mode, String period})? tour;

  const PersonalPresenceCard({
    super.key,
    this.tour,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    required this.mode,
    required this.onModeChanged,
    required this.shownMode,
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
    final online = widget.shownMode == kOnlineMode;

    final Widget card = AppCard(
      title: kPupilStatsTitle,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.event_seat_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: StatFilterRow(
        children: [
          requestedKindPill(
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
          ),
          DesktopTourTarget(
            id: widget.tour?.mode,
            child: statsModePill(value: widget.mode, onChanged: widget.onModeChanged),
          ),
          DesktopTourTarget(
            id: widget.tour?.period,
            child: statsPeriodPill(value: widget.period, onChanged: widget.onPeriodChanged),
          ),
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
                  label: presenceDaysPerWeekLabel(online: online),
                  value: widget.statistics.weeklyPresenceDays.toStringAsFixed(1),
                ),
                const StatDivider(),
                _Figure(
                  label: 'Giorni totali nel periodo',
                  value: '${widget.statistics.totalPresenceDays}',
                ),
              ],
            ),
            const StatPartDivider(color: _sectionDivider),
            StatSectionTitle(presenceTrendTitle(online: online)),
            SizedBox(height: StatMetrics.of(context).titleGap),
            SizedBox(
              height: statChartHeight(context, _chartHeight),
              child: widget.statistics.monthlyTrend.isEmpty
                  ? const EmptyChartMessage()
                  : TrendLineChart(data: widget.statistics.monthlyTrend, isMonthly: true),
            ),
            const StatPartDivider(color: _sectionDivider),
            RankingPair(
              first: _subjectHoursRanking(subjectHoursTitle(_kind), widget.statistics.lessonHours.of(_kind)),
              second: _peopleHoursRanking(kTopTeachersTitle, widget.statistics.topTeachers),
            ),
          ],
        ),
      ),
    );

    return DesktopTourTarget(id: widget.tour?.card, child: card);
  }
}
