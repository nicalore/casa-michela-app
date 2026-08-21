import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_filter_pill.dart';
import '../../../../shared/widgets/filter_menu.dart';
import '../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../shared/widgets/page_transition.dart';
import '../../../association/models/subject_taxonomy.dart';
import '../../models/age_distribution_item.dart';
import '../../models/city_distribution_item.dart';
import '../../models/course_distribution_item.dart';
import '../../models/current_totals_item.dart';
import '../../models/education_distribution_item.dart';
import '../../models/member_trend_item.dart';
import '../../models/retention_rate_item.dart';
import '../../models/teacher_appreciation_item.dart';
import '../../models/teacher_subjects_statistics_item.dart';
import 'widgets/appreciation_ranking_card.dart';
import 'widgets/bar_chart.dart';
import 'widgets/chart_common.dart';
import 'widgets/pie_chart.dart';
import 'widgets/stat_filters.dart';
import 'widgets/stat_widgets.dart';
import 'widgets/stats_data.dart';
import 'widgets/stats_layout.dart';
import 'widgets/trend_line_chart.dart';
import 'widgets/stats_constants.dart';

const Color _sectionDivider = AppTheme.trialLine;

// The ground every chip of the app that names something stands on: the brand
// turquoise laid on white until it is barely a colour.
const Color _subjectBadgeBackground = Color(0xFFE8F7F5);

// Roles whose members have a residence and an age worth charting. The other
// roles skip those two requests entirely.
const Set<String> _rolesWithDemographics = {
  'teacher',
  'student',
  'course_participant',
};

const String _studentRole = 'student';
const String _teacherRole = 'teacher';
const String _courseParticipantRole = 'course_participant';

// Age brackets in the order the backend does not guarantee: the labels are
// strings, so they have to be sorted against this explicit sequence.
const Map<String, int> _ageGroupOrder = {
  '< 11': 1,
  '11-14': 2,
  '15-18': 3,
  '19-25': 4,
  '26-35': 5,
  '36-50': 6,
  '> 50': 7,
};

List<AgeDistributionItem> _sortedByAgeGroup(List<AgeDistributionItem> items)
{
  final sorted = [...items];
  sorted.sort((a, b) => (_ageGroupOrder[a.ageGroup] ?? 99).compareTo(_ageGroupOrder[b.ageGroup] ?? 99));

  return sorted;
}

class RoleSpecificStatisticsView extends StatefulWidget
{
  final String roleKey;

  const RoleSpecificStatisticsView({super.key, required this.roleKey});

  @override
  State<RoleSpecificStatisticsView> createState() => _RoleSpecificStatisticsViewState();
}

class _RoleSpecificStatisticsViewState extends State<RoleSpecificStatisticsView>
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isTrendLoading = false;
  bool _isCollabTrendLoading = false;
  bool _isRetentionLoading = false;
  bool _isCollabRetentionLoading = false;
  CurrentTotalsItem? _currentTotals;
  List<MemberTrendItem> _trendData = [];
  List<MemberTrendItem> _collabTrendData = [];
  RetentionRateItem? _retentionData;
  RetentionRateItem? _collabRetentionData;

  List<CityDistributionItem> _cityData = [];
  List<AgeDistributionItem> _ageData = [];
  List<EducationDistributionItem> _educationData = [];
  List<CourseDistributionItem> _courseData = [];
  TeacherSubjectsStatisticsItem? _teacherStats;
  TeacherAppreciationRankingItem? _teacherAppreciation;
  bool _isAppreciationLoading = false;

  String _trendResolution = 'year';
  int _startTrendYear = dataStartYear;
  int _endTrendYear = DateTime.now().year;

  String _collabTrendResolution = 'year';
  int _startCollabTrendYear = dataStartYear;
  int _endCollabTrendYear = DateTime.now().year;

  int _selectedRetentionYear = DateTime.now().year;
  String _collabRetentionType = 'month';
  int _selectedCollabYear = DateTime.now().year;
  int _selectedCollabMonth = DateTime.now().month;

  String _educationDistributionType = 'school';
  String _teacherRankingMode = 'absolute';
  String _appreciationPeriod = wholeWindowPeriod;

  bool get _hasDemographics => _rolesWithDemographics.contains(widget.roleKey);

  @override
  void initState()
  {
    super.initState();
    _loadData();
  }

  Future<void> _loadEducationData() async
  {
    if (widget.roleKey != _studentRole)
    {
      return;
    }

    try
    {
      final data = await _apiService.getStudentEducationDistribution(
        _educationDistributionType,
      );

      if (mounted)
      {
        setState(() => _educationData = data);
      }
    }
    catch (_) {}
  }

  Future<void> _loadTeacherData() async
  {
    if (widget.roleKey != _teacherRole)
    {
      return;
    }

    try
    {
      final data = await _apiService.getTeacherSubjectsStatistics(
        _teacherRankingMode,
      );

      if (mounted)
      {
        setState(() => _teacherStats = data);
      }
    }
    catch (_) {}
  }

  // Its own request and its own spinner: the period pill stands on the ranking
  // card, and answering it by reloading the competences beside it would blank a
  // card nobody asked about.
  Future<void> _loadTeacherAppreciationData() async
  {
    if (widget.roleKey != _teacherRole)
    {
      return;
    }

    setState(() => _isAppreciationLoading = true);

    try
    {
      final period = periodParts(_appreciationPeriod);

      final data = await _apiService.getTeacherAppreciationRanking(
        year: period?.year,
        month: period?.month,
      );

      if (mounted)
      {
        setState(() => _teacherAppreciation = data);
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

  Future<void> _loadCourseData() async
  {
    if (widget.roleKey != _courseParticipantRole)
    {
      return;
    }

    try
    {
      final data = await _apiService.getCourseParticipantDistribution();

      if (mounted)
      {
        setState(() => _courseData = data);
      }
    }
    catch (_) {}
  }

  Future<void> _loadRoleSpecificData() async
  {
    switch (widget.roleKey)
    {
      case _studentRole:
        await _loadEducationData();
      case _teacherRole:
        await Future.wait([_loadTeacherData(), _loadTeacherAppreciationData()]);
      case _courseParticipantRole:
        await _loadCourseData();
    }
  }

  Future<void> _loadData() async
  {
    setState(() => _isLoading = true);

    try
    {
      final collabRetentionFuture = _collabRetentionType == 'year'
          ? _apiService.getRoleRetentionRate(
              widget.roleKey,
              _selectedCollabYear,
            )
          : _apiService.getRoleCollaboratingRetentionRate(
              widget.roleKey,
              _selectedCollabYear,
              _selectedCollabMonth,
            );

      final results = await Future.wait([
        _apiService.getRoleCurrentTotals(widget.roleKey),
        _apiService.getRoleMembersTrend(
          role: widget.roleKey,
          resolution: _trendResolution,
          startYear: _startTrendYear,
          endYear: _endTrendYear,
        ),
        _apiService.getRoleCollaboratingTrend(
          role: widget.roleKey,
          resolution: _collabTrendResolution,
          startYear: _startCollabTrendYear,
          endYear: _endCollabTrendYear,
        ),
        _apiService.getRoleRetentionRate(
          widget.roleKey,
          _selectedRetentionYear,
        ),
        collabRetentionFuture,
        _hasDemographics
            ? _apiService.getRoleCityDistribution(widget.roleKey)
            : Future.value(<CityDistributionItem>[]),
        _hasDemographics
            ? _apiService.getRoleAgeDistribution(widget.roleKey)
            : Future.value(<AgeDistributionItem>[]),
      ]);

      _currentTotals = results[0] as CurrentTotalsItem;
      _trendData = padTrendData(
        results[1] as List<MemberTrendItem>,
        _trendResolution,
        _startTrendYear,
        _endTrendYear,
      );
      _collabTrendData = padTrendData(
        results[2] as List<MemberTrendItem>,
        _collabTrendResolution,
        _startCollabTrendYear,
        _endCollabTrendYear,
      );
      _retentionData = results[3] as RetentionRateItem;
      _collabRetentionData = results[4] as RetentionRateItem;
      _cityData = results[5] as List<CityDistributionItem>;
      _ageData = _sortedByAgeGroup(results[6] as List<AgeDistributionItem>);

      await _loadRoleSpecificData();
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
      }
    }
  }

  // Every card fetches and reloads on its own. A pill belongs to the card it
  // stands on, and answering it by blanking the whole view behind a spinner —
  // which is what a single shared load did — throws away the cards that were
  // not asked about and makes a change of year read as a page change.

  Future<void> _loadRetentionData() async
  {
    setState(() => _isRetentionLoading = true);

    try
    {
      final data = await _apiService.getRoleRetentionRate(
        widget.roleKey,
        _selectedRetentionYear,
      );

      if (mounted)
      {
        setState(() => _retentionData = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isRetentionLoading = false);
      }
    }
  }

  Future<void> _loadCollabRetentionData() async
  {
    setState(() => _isCollabRetentionLoading = true);

    try
    {
      final data = _collabRetentionType == 'year'
          ? await _apiService.getRoleRetentionRate(
              widget.roleKey,
              _selectedCollabYear,
            )
          : await _apiService.getRoleCollaboratingRetentionRate(
              widget.roleKey,
              _selectedCollabYear,
              _selectedCollabMonth,
            );

      if (mounted)
      {
        setState(() => _collabRetentionData = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isCollabRetentionLoading = false);
      }
    }
  }

  void _reloadRetention(VoidCallback mutateState)
  {
    setState(mutateState);
    _loadRetentionData();
  }

  void _reloadCollabRetention(VoidCallback mutateState)
  {
    setState(mutateState);
    _loadCollabRetentionData();
  }

  Future<void> _loadTrendData() async
  {
    setState(() => _isTrendLoading = true);

    try
    {
      final data = await _apiService.getRoleMembersTrend(
        role: widget.roleKey,
        resolution: _trendResolution,
        startYear: _startTrendYear,
        endYear: _endTrendYear,
      );

      if (mounted)
      {
        setState(() => _trendData = padTrendData(data, _trendResolution, _startTrendYear, _endTrendYear));
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isTrendLoading = false);
      }
    }
  }

  Future<void> _loadCollabTrendData() async
  {
    setState(() => _isCollabTrendLoading = true);

    try
    {
      final data = await _apiService.getRoleCollaboratingTrend(
        role: widget.roleKey,
        resolution: _collabTrendResolution,
        startYear: _startCollabTrendYear,
        endYear: _endCollabTrendYear,
      );

      if (mounted)
      {
        setState(()
        {
          _collabTrendData =
              padTrendData(data, _collabTrendResolution, _startCollabTrendYear, _endCollabTrendYear);
        });
      }
    }
    catch (_) {}
    finally
    {
      if (mounted)
      {
        setState(() => _isCollabTrendLoading = false);
      }
    }
  }

  void _reloadTrend(VoidCallback mutateState)
  {
    setState(mutateState);
    _loadTrendData();
  }

  void _reloadCollabTrend(VoidCallback mutateState)
  {
    setState(mutateState);
    _loadCollabTrendData();
  }

  void _clampCollabMonthToDataStart()
  {
    if (_selectedCollabYear == dataStartYear && _selectedCollabMonth < dataStartMonth)
    {
      _selectedCollabMonth = dataStartMonth;
    }
  }

  String _membersRetentionSentence(RetentionRateItem data)
  {
    final subject = data.retainedMembers == 1
        ? '1 iscritto mantenuto'
        : '${data.retainedMembers} iscritti mantenuti';

    return "$subject su ${data.previousYearMembers} dell'anno precedente.";
  }

  String _collaboratorsRetentionSentence(RetentionRateItem data)
  {
    final subject = data.retainedMembers == 1
        ? '1 collaboratore mantenuto'
        : '${data.retainedMembers} collaboratori mantenuti';

    final period = _collabRetentionType == 'year' ? "nell'anno precedente" : 'nel mese precedente';

    return '$subject rispetto ai ${data.previousYearMembers} attivi $period.';
  }

  Widget _buildMembersRetentionCard(double width, bool matched)
  {
    return RetentionCard(
      title: 'Fidelizzazione iscritti',
      icon: Icons.favorite_rounded,
      width: width,
      matched: matched,
      data: _retentionData,
      isLoading: _isRetentionLoading,
      describe: _membersRetentionSentence,
      filters: yearPill(
        value: _selectedRetentionYear,
        onChanged: (value) => _reloadRetention(() => _selectedRetentionYear = value),
      ),
    );
  }

  Widget _buildCollabRetentionCard(double width, bool matched)
  {
    final filters = StatFilterRow(
      children: [
        resolutionPill(
          prefix: 'Tipo',
          value: _collabRetentionType,
          onChanged: (value) => _reloadCollabRetention(()
          {
            _collabRetentionType = value;
            _clampCollabMonthToDataStart();
          }),
        ),
        if (_collabRetentionType == 'month')
          monthPill(
            year: _selectedCollabYear,
            value: _selectedCollabMonth,
            onChanged: (value) => _reloadCollabRetention(() => _selectedCollabMonth = value),
          ),
        yearPill(
          value: _selectedCollabYear,
          onChanged: (value) => _reloadCollabRetention(()
          {
            _selectedCollabYear = value;
            _clampCollabMonthToDataStart();
          }),
        ),
      ],
    );

    return RetentionCard(
      title: 'Fidelizzazione collaboratori attivi',
      icon: Icons.volunteer_activism_rounded,
      width: width,
      matched: matched,
      data: _collabRetentionData,
      isLoading: _isCollabRetentionLoading,
      describe: _collaboratorsRetentionSentence,
      filters: filters,
    );
  }

  Widget _buildTrendChartCard({
    required String title,
    required IconData icon,
    required List<MemberTrendItem> data,
    required bool isLoading,
    required String resolution,
    required int startYear,
    required int endYear,
    required ValueChanged<String> onResolutionChanged,
    required ValueChanged<int> onStartYearChanged,
    required ValueChanged<int> onEndYearChanged,
  })
  {
    final filters = StatFilterRow(
      children: [
        resolutionPill(
          prefix: 'Vista',
          value: resolution,
          onChanged: onResolutionChanged,
        ),
        startYearPill(value: startYear, onChanged: onStartYearChanged),
        endYearPill(value: endYear, onChanged: onEndYearChanged),
      ],
    );

    return ChartCard(
      title: title,
      icon: icon,
      filters: filters,
      isEmpty: data.isEmpty,
      isLoading: isLoading,
      chart: TrendLineChart(data: data, isMonthly: resolution == 'month'),
    );
  }

  Widget _buildMembersTrendCard()
  {
    return _buildTrendChartCard(
      title: 'Trend iscritti',
      icon: Icons.show_chart_rounded,
      data: _trendData,
      isLoading: _isTrendLoading,
      resolution: _trendResolution,
      startYear: _startTrendYear,
      endYear: _endTrendYear,
      onResolutionChanged: (value) => _reloadTrend(() => _trendResolution = value),
      // The two bounds push each other, so the range can never invert.
      onStartYearChanged: (value) => _reloadTrend(()
      {
        _startTrendYear = value;

        if (_endTrendYear < value)
        {
          _endTrendYear = value;
        }
      }),
      onEndYearChanged: (value) => _reloadTrend(()
      {
        _endTrendYear = value;

        if (_startTrendYear > value)
        {
          _startTrendYear = value;
        }
      }),
    );
  }

  Widget _buildCollabTrendCard()
  {
    return _buildTrendChartCard(
      title: 'Trend collaboratori attivi',
      icon: Icons.stacked_line_chart_rounded,
      data: _collabTrendData,
      isLoading: _isCollabTrendLoading,
      resolution: _collabTrendResolution,
      startYear: _startCollabTrendYear,
      endYear: _endCollabTrendYear,
      onResolutionChanged: (value) => _reloadCollabTrend(() => _collabTrendResolution = value),
      onStartYearChanged: (value) => _reloadCollabTrend(()
      {
        _startCollabTrendYear = value;

        if (_endCollabTrendYear < value)
        {
          _endCollabTrendYear = value;
        }
      }),
      onEndYearChanged: (value) => _reloadCollabTrend(()
      {
        _endCollabTrendYear = value;

        if (_startCollabTrendYear > value)
        {
          _startCollabTrendYear = value;
        }
      }),
    );
  }

  Widget _buildCityChartCard()
  {
    return ChartCard(
      title: 'Distribuzione per città',
      icon: Icons.location_city_rounded,
      isEmpty: _cityData.isEmpty,
      chart: BarChart(
        data: _cityData
            .map((item) => ChartDatum(label: item.city, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildAgeChartCard()
  {
    return ChartCard(
      title: 'Distribuzione per età',
      icon: Icons.cake_rounded,
      isEmpty: _ageData.isEmpty,
      chart: PieChart(
        data: _ageData
            .map((item) => ChartDatum(label: item.ageGroup, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildEducationChartCard()
  {
    return ChartCard(
      title: 'Distribuzione scolastica',
      icon: Icons.school_rounded,
      isEmpty: _educationData.isEmpty,
      filters: AppFilterPill<String>.setting(
        prefix: 'Raggruppa per',
        hint: 'Raggruppa per',
        icon: Icons.category_rounded,
        value: _educationDistributionType,
        options: const [
          FilterOption(value: 'school', label: 'Scuola'),
          FilterOption(value: 'program', label: 'Percorso di studio'),
          FilterOption(value: 'level', label: 'Livello di istruzione'),
        ],
        onChanged: (value)
        {
          setState(() => _educationDistributionType = value);
          _loadEducationData();
        },
        menuWidth: 230,
      ),
      chart: BarChart(
        data: _educationData
            .map((item) => ChartDatum(label: item.label, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildCourseChartCard()
  {
    return ChartCard(
      title: 'Distribuzione per corso',
      icon: Icons.menu_book_rounded,
      isEmpty: _courseData.isEmpty,
      chart: BarChart(
        data: _courseData
            .map((item) => ChartDatum(label: item.label, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildSubjectRow(SubjectDistributionItem subject)
  {
    final unit = subject.count == 1 ? 'docente' : 'docenti';
    final programName = subject.programName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                OverflowTooltipText(
                  text: subject.name,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialInk,
                  ),
                ),
                if (programName != null) ...[
                  const SizedBox(height: 2),
                  OverflowTooltipText(
                    text: programName,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.trialMutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: _subjectBadgeBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${subject.count} $unit',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialTealDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRanking(String title, List<SubjectDistributionItem> subjects)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatSectionTitle(title),
        const SizedBox(height: 24),
        if (subjects.isEmpty)
          const EmptyChartMessage(fontSize: 14)
        else
          ...subjects.map(_buildSubjectRow),
      ],
    );
  }

  Widget _buildAreaDistributionSection(List<AreaDistributionItem> areas)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const StatSectionTitle('Distribuzione per area'),
        const SizedBox(height: 24),
        // The explicit height is what keeps the IntrinsicHeight below working:
        // it stops the intrinsic measurement before it reaches the LayoutBuilder
        // inside the pie chart, which cannot answer it.
        SizedBox(
          height: 320,
          child: areas.isEmpty
              ? const EmptyChartMessage(fontSize: 14)
              : PieChart(
                  data: areas
                      .map(
                        (item) => ChartDatum(
                          label: subjectAreaLabel(item.area),
                          count: item.count,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTeacherSubjectsSections(TeacherSubjectsStatisticsItem stats)
  {
    final topRanking = _buildSubjectRanking(
      '10 discipline più coperte',
      stats.top10Subjects,
    );
    final bottomRanking = _buildSubjectRanking(
      '10 discipline meno coperte',
      stats.bottom10Subjects,
    );
    final areaSection = _buildAreaDistributionSection(stats.areaDistribution);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < 900)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topRanking,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 1),
              const SizedBox(height: 24),
              bottomRanking,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 1),
              const SizedBox(height: 24),
              areaSection,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 4, child: topRanking),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: VerticalDivider(color: _sectionDivider, thickness: 1),
              ),
              Expanded(flex: 4, child: bottomRanking),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: VerticalDivider(color: _sectionDivider, thickness: 1),
              ),
              Expanded(flex: 5, child: areaSection),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAverageBlock(String label, double value)
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
            value.toStringAsFixed(1),
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

  Widget _buildTeacherSubjectsCard(TeacherSubjectsStatisticsItem stats)
  {
    return AppCard(
      title: 'Analisi competenze',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.workspace_premium_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: AppFilterPill<String>.setting(
        prefix: 'Classifica',
        hint: 'Classifica',
        icon: Icons.leaderboard_rounded,
        value: _teacherRankingMode,
        options: const [
          FilterOption(value: 'absolute', label: 'Per disciplina'),
          FilterOption(value: 'program', label: 'Per disciplina e percorso'),
        ],
        onChanged: (value)
        {
          setState(() => _teacherRankingMode = value);
          _loadTeacherData();
        },
        menuWidth: 260,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAverageBlock(
                'Media discipline per docente',
                stats.avgSubjectsPerTeacher,
              ),
              const StatDivider(),
              _buildAverageBlock(
                'Media docenti per disciplina',
                stats.avgTeachersPerSubject,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: _sectionDivider, thickness: 1),
          const SizedBox(height: 32),
          _buildTeacherSubjectsSections(stats),
        ],
      ),
    );
  }

  // Two cards about the teachers, and neither waits for the other: what they can
  // teach, and how often the pupils ask for them.
  List<Widget> _buildTeacherCards()
  {
    final stats = _teacherStats;
    final appreciation = _teacherAppreciation;

    return [
      if (stats != null) _buildTeacherSubjectsCard(stats),
      if (appreciation != null)
        TeacherAppreciationCard(
          ranking: appreciation,
          period: _appreciationPeriod,
          isLoading: _isAppreciationLoading,
          onPeriodChanged: (value)
          {
            setState(() => _appreciationPeriod = value);
            _loadTeacherAppreciationData();
          },
        ),
    ];
  }

  // City and age are shown side by side when both are available, and alone when
  // only one of the two came back.
  Widget? _buildDemographicsSection()
  {
    if (_cityData.isEmpty && _ageData.isEmpty)
    {
      return null;
    }

    if (_cityData.isNotEmpty && _ageData.isNotEmpty)
    {
      return ResponsiveCardPair(
        first: _buildCityChartCard(),
        second: _buildAgeChartCard(),
      );
    }

    return _cityData.isNotEmpty ? _buildCityChartCard() : _buildAgeChartCard();
  }

  // A list and not one card: the teachers have two, and each of them has to
  // come in on a beat of its own like every other card of the page.
  List<Widget> _buildRoleSpecificCards()
  {
    switch (widget.roleKey)
    {
      case _studentRole:
        return [_buildEducationChartCard()];
      case _courseParticipantRole:
        return [_buildCourseChartCard()];
      case _teacherRole:
        return _buildTeacherCards();
      default:
        return const [];
    }
  }

  Widget _buildContent()
  {
    final demographics = _buildDemographicsSection();
    final roleSpecific = _buildRoleSpecificCards();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pageTransitionBlocks([
          ResponsiveCardPair(
            first: SummaryStatCard(
              title: 'Iscritti',
              icon: Icons.groups_rounded,
              count: _currentTotals?.currentTotalMembers ?? 0,
              deltaMonth: _currentTotals?.membersDeltaMonth ?? 0,
              deltaYear: _currentTotals?.membersDeltaYear ?? 0,
              percentage: _currentTotals?.percentageOfTotalMembers,
            ),
            second: SummaryStatCard(
              title: 'Collaboratori attivi',
              icon: Icons.handshake_rounded,
              count: _currentTotals?.currentActiveCollaborators ?? 0,
              deltaMonth: _currentTotals?.collabDeltaMonth ?? 0,
              deltaYear: _currentTotals?.collabDeltaYear ?? 0,
              percentage: _currentTotals?.percentageOfTotalCollaborators,
            ),
          ),
          const SizedBox(height: 24),
          // The one pair of the page that has to be the same height on both
          // sides: they are the same question asked of two populations.
          MatchedCardPair(
            first: _buildMembersRetentionCard,
            second: _buildCollabRetentionCard,
          ),
          const SizedBox(height: 24),
          if (demographics != null) ...[
            demographics,
            const SizedBox(height: 24),
          ],
          for (final card in roleSpecific) ...[
            card,
            const SizedBox(height: 24),
          ],
          _buildMembersTrendCard(),
          const SizedBox(height: 24),
          _buildCollabTrendCard(),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // The nested Navigator gives this view its own Overlay, which is why the
  // filter menus insert into the root overlay instead.
  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
      );
    }

    // The charts are timed one by one inside, rather than the whole page being
    // wrapped as one element out here: a page that left in a single slab was
    // the odd one out beside every list in the app.
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (context) => _buildContent()),
    );
  }
}
