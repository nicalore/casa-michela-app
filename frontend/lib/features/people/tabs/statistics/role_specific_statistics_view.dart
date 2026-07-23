import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../association/models/subject_taxonomy.dart';
import '../../models/age_distribution_item.dart';
import '../../models/city_distribution_item.dart';
import '../../models/course_distribution_item.dart';
import '../../models/current_totals_item.dart';
import '../../models/education_distribution_item.dart';
import '../../models/member_trend_item.dart';
import '../../models/retention_rate_item.dart';
import '../../models/teacher_subjects_statistics_item.dart';
import 'widgets/bar_chart.dart';
import 'widgets/chart_common.dart';
import 'widgets/pie_chart.dart';
import 'widgets/stat_filter_menu.dart';
import 'widgets/stat_widgets.dart';
import 'widgets/stats_data.dart';
import 'widgets/stats_layout.dart';
import 'widgets/trend_line_chart.dart';
import 'widgets/stats_constants.dart';

const Color _sectionDivider = Color(0xFFF1F5F9);
const Color _subjectBadgeBackground = Color(0xFFE0F2FE);
const Color _subjectBadgeText = Color(0xFF0284C7);

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

List<AgeDistributionItem> _sortedByAgeGroup(List<AgeDistributionItem> items) {
  final sorted = [...items];
  sorted.sort(
    (a, b) => (_ageGroupOrder[a.ageGroup] ?? 99).compareTo(
      _ageGroupOrder[b.ageGroup] ?? 99,
    ),
  );

  return sorted;
}

class RoleSpecificStatisticsView extends StatefulWidget {
  final String roleKey;

  const RoleSpecificStatisticsView({super.key, required this.roleKey});

  @override
  State<RoleSpecificStatisticsView> createState() =>
      _RoleSpecificStatisticsViewState();
}

class _RoleSpecificStatisticsViewState
    extends State<RoleSpecificStatisticsView> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
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

  bool get _hasDemographics => _rolesWithDemographics.contains(widget.roleKey);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadEducationData() async {
    if (widget.roleKey != _studentRole) {
      return;
    }

    try {
      final data = await _apiService.getStudentEducationDistribution(
        _educationDistributionType,
      );

      if (mounted) {
        setState(() => _educationData = data);
      }
    } catch (_) {}
  }

  Future<void> _loadTeacherData() async {
    if (widget.roleKey != _teacherRole) {
      return;
    }

    try {
      final data = await _apiService.getTeacherSubjectsStatistics(
        _teacherRankingMode,
      );

      if (mounted) {
        setState(() => _teacherStats = data);
      }
    } catch (_) {}
  }

  Future<void> _loadCourseData() async {
    if (widget.roleKey != _courseParticipantRole) {
      return;
    }

    try {
      final data = await _apiService.getCourseParticipantDistribution();

      if (mounted) {
        setState(() => _courseData = data);
      }
    } catch (_) {}
  }

  Future<void> _loadRoleSpecificData() async {
    switch (widget.roleKey) {
      case _studentRole:
        await _loadEducationData();
      case _teacherRole:
        await _loadTeacherData();
      case _courseParticipantRole:
        await _loadCourseData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
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
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _reload(VoidCallback mutateState) {
    setState(mutateState);
    _loadData();
  }

  void _clampCollabMonthToDataStart() {
    if (_selectedCollabYear == dataStartYear &&
        _selectedCollabMonth < dataStartMonth) {
      _selectedCollabMonth = dataStartMonth;
    }
  }

  String _membersRetentionSentence(RetentionRateItem data) {
    final subject = data.retainedMembers == 1
        ? '1 iscritto mantenuto'
        : '${data.retainedMembers} iscritti mantenuti';

    return "$subject su ${data.previousYearMembers} dell'anno precedente.";
  }

  String _collaboratorsRetentionSentence(RetentionRateItem data) {
    final subject = data.retainedMembers == 1
        ? '1 collaboratore mantenuto'
        : '${data.retainedMembers} collaboratori mantenuti';

    final period = _collabRetentionType == 'year'
        ? "nell'anno precedente"
        : 'nel mese precedente';

    return '$subject rispetto ai ${data.previousYearMembers} attivi $period.';
  }

  Widget _buildMembersRetentionCard() {
    return RetentionCard(
      title: 'Fidelizzazione Iscritti',
      filtersBreakpoint: 480,
      data: _retentionData,
      describe: _membersRetentionSentence,
      filters: StatFilterMenu<int>(
        hint: 'Anno',
        value: _selectedRetentionYear,
        options: yearOptions(),
        onChanged: (value) => _reload(() => _selectedRetentionYear = value),
      ),
    );
  }

  Widget _buildCollabRetentionCard() {
    final filters = Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        StatFilterMenu<String>(
          hint: 'Tipo',
          value: _collabRetentionType,
          options: resolutionOptions(),
          onChanged: (value) => _reload(() {
            _collabRetentionType = value;
            _clampCollabMonthToDataStart();
          }),
        ),
        if (_collabRetentionType == 'month')
          StatFilterMenu<int>(
            hint: 'Mese',
            value: _selectedCollabMonth,
            options: monthOptions(_selectedCollabYear),
            onChanged: (value) => _reload(() => _selectedCollabMonth = value),
          ),
        StatFilterMenu<int>(
          hint: 'Anno',
          value: _selectedCollabYear,
          options: yearOptions(),
          onChanged: (value) => _reload(() {
            _selectedCollabYear = value;
            _clampCollabMonthToDataStart();
          }),
        ),
      ],
    );

    return RetentionCard(
      title: 'Fidelizzazione Collaboratori Attivi',
      filtersBreakpoint: 620,
      data: _collabRetentionData,
      describe: _collaboratorsRetentionSentence,
      filters: filters,
    );
  }

  Widget _buildTrendChartCard({
    required String title,
    required List<MemberTrendItem> data,
    required String resolution,
    required int startYear,
    required int endYear,
    required ValueChanged<String> onResolutionChanged,
    required ValueChanged<int> onStartYearChanged,
    required ValueChanged<int> onEndYearChanged,
  }) {
    final filters = Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        StatFilterMenu<String>(
          hint: 'Risoluzione',
          value: resolution,
          options: resolutionOptions(),
          onChanged: onResolutionChanged,
        ),
        StatFilterMenu<int>(
          hint: 'Da anno',
          value: startYear,
          options: yearOptions(),
          onChanged: onStartYearChanged,
        ),
        StatFilterMenu<int>(
          hint: 'A anno',
          value: endYear,
          options: yearOptions(),
          onChanged: onEndYearChanged,
        ),
      ],
    );

    return ChartCard(
      title: title,
      filters: filters,
      isEmpty: data.isEmpty,
      chart: TrendLineChart(data: data, isMonthly: resolution == 'month'),
    );
  }

  Widget _buildMembersTrendCard() {
    return _buildTrendChartCard(
      title: 'Trend Iscritti',
      data: _trendData,
      resolution: _trendResolution,
      startYear: _startTrendYear,
      endYear: _endTrendYear,
      onResolutionChanged: (value) => _reload(() => _trendResolution = value),
      // The two bounds push each other, so the range can never invert.
      onStartYearChanged: (value) => _reload(() {
        _startTrendYear = value;

        if (_endTrendYear < value) {
          _endTrendYear = value;
        }
      }),
      onEndYearChanged: (value) => _reload(() {
        _endTrendYear = value;

        if (_startTrendYear > value) {
          _startTrendYear = value;
        }
      }),
    );
  }

  Widget _buildCollabTrendCard() {
    return _buildTrendChartCard(
      title: 'Trend Collaboratori Attivi',
      data: _collabTrendData,
      resolution: _collabTrendResolution,
      startYear: _startCollabTrendYear,
      endYear: _endCollabTrendYear,
      onResolutionChanged: (value) =>
          _reload(() => _collabTrendResolution = value),
      onStartYearChanged: (value) => _reload(() {
        _startCollabTrendYear = value;

        if (_endCollabTrendYear < value) {
          _endCollabTrendYear = value;
        }
      }),
      onEndYearChanged: (value) => _reload(() {
        _endCollabTrendYear = value;

        if (_startCollabTrendYear > value) {
          _startCollabTrendYear = value;
        }
      }),
    );
  }

  Widget _buildCityChartCard() {
    return ChartCard(
      title: 'Distribuzione per città',
      isEmpty: _cityData.isEmpty,
      chart: BarChart(
        data: _cityData
            .map((item) => ChartDatum(label: item.city, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildAgeChartCard() {
    return ChartCard(
      title: 'Distribuzione per età',
      isEmpty: _ageData.isEmpty,
      chart: PieChart(
        data: _ageData
            .map((item) => ChartDatum(label: item.ageGroup, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildEducationChartCard() {
    return ChartCard(
      title: 'Distribuzione scolastica',
      filtersBreakpoint: 560,
      isEmpty: _educationData.isEmpty,
      filters: StatFilterMenu<String>(
        hint: 'Raggruppa per',
        value: _educationDistributionType,
        options: const [
          StatFilterOption(value: 'school', label: 'Scuola'),
          StatFilterOption(value: 'program', label: 'Percorso di studio'),
          StatFilterOption(value: 'level', label: 'Livello di istruzione'),
        ],
        onChanged: (value) {
          setState(() => _educationDistributionType = value);
          _loadEducationData();
        },
      ),
      chart: BarChart(
        data: _educationData
            .map((item) => ChartDatum(label: item.label, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildCourseChartCard() {
    return ChartCard(
      title: 'Distribuzione per corso',
      isEmpty: _courseData.isEmpty,
      chart: BarChart(
        data: _courseData
            .map((item) => ChartDatum(label: item.label, count: item.count))
            .toList(),
      ),
    );
  }

  Widget _buildSubjectRow(SubjectDistributionItem subject) {
    final unit = subject.count == 1 ? 'docente' : 'docenti';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              subject.name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.slate500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _subjectBadgeBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${subject.count} $unit',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _subjectBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.slate800,
      ),
    );
  }

  Widget _buildSubjectRanking(
    String title,
    List<SubjectDistributionItem> subjects,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSubjectSectionTitle(title),
        const SizedBox(height: 24),
        if (subjects.isEmpty)
          const EmptyChartMessage(fontSize: 14)
        else
          ...subjects.map(_buildSubjectRow),
      ],
    );
  }

  Widget _buildAreaDistributionSection(List<AreaDistributionItem> areas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSubjectSectionTitle('Distribuzione per area'),
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

  Widget _buildTeacherSubjectsSections(TeacherSubjectsStatisticsItem stats) {
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
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topRanking,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 2),
              const SizedBox(height: 24),
              bottomRanking,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 2),
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
                child: VerticalDivider(color: _sectionDivider, thickness: 2),
              ),
              Expanded(flex: 4, child: bottomRanking),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: VerticalDivider(color: _sectionDivider, thickness: 2),
              ),
              Expanded(flex: 5, child: areaSection),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAverageBlock(String label, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toStringAsFixed(1),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSubjectsCard() {
    final stats = _teacherStats;

    if (stats == null) {
      return const SizedBox();
    }

    return StatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveCardHeader(
            title: Text(
              'Analisi Competenze',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate800,
              ),
            ),
            breakpoint: 560,
            filters: StatFilterMenu<String>(
              hint: 'Classifica',
              value: _teacherRankingMode,
              options: const [
                StatFilterOption(value: 'absolute', label: 'Per disciplina'),
                StatFilterOption(
                  value: 'program',
                  label: 'Per disciplina e percorso',
                ),
              ],
              onChanged: (value) {
                setState(() => _teacherRankingMode = value);
                _loadTeacherData();
              },
            ),
          ),
          const SizedBox(height: 32),
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
          const Divider(color: _sectionDivider, thickness: 2),
          const SizedBox(height: 32),
          _buildTeacherSubjectsSections(stats),
        ],
      ),
    );
  }

  // City and age are shown side by side when both are available, and alone when
  // only one of the two came back.
  Widget? _buildDemographicsSection() {
    if (_cityData.isEmpty && _ageData.isEmpty) {
      return null;
    }

    if (_cityData.isNotEmpty && _ageData.isNotEmpty) {
      return ResponsiveCardPair(
        first: _buildCityChartCard(),
        second: _buildAgeChartCard(),
      );
    }

    return _cityData.isNotEmpty ? _buildCityChartCard() : _buildAgeChartCard();
  }

  Widget? _buildRoleSpecificCard() {
    switch (widget.roleKey) {
      case _studentRole:
        return _buildEducationChartCard();
      case _courseParticipantRole:
        return _buildCourseChartCard();
      case _teacherRole:
        return _buildTeacherSubjectsCard();
      default:
        return null;
    }
  }

  Widget _buildContent() {
    final demographics = _buildDemographicsSection();
    final roleSpecific = _buildRoleSpecificCard();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveCardPair(
            first: SummaryStatCard(
              title: 'Iscritti',
              icon: Icons.person_outline,
              count: _currentTotals?.currentTotalMembers ?? 0,
              deltaMonth: _currentTotals?.membersDeltaMonth ?? 0,
              deltaYear: _currentTotals?.membersDeltaYear ?? 0,
              percentage: _currentTotals?.percentageOfTotalMembers,
            ),
            second: SummaryStatCard(
              title: 'Collaboratori Attivi',
              icon: Icons.handshake_outlined,
              count: _currentTotals?.currentActiveCollaborators ?? 0,
              deltaMonth: _currentTotals?.collabDeltaMonth ?? 0,
              deltaYear: _currentTotals?.collabDeltaYear ?? 0,
              percentage: _currentTotals?.percentageOfTotalCollaborators,
            ),
          ),
          const SizedBox(height: 24),
          ResponsiveCardPair(
            first: _buildMembersRetentionCard(),
            second: _buildCollabRetentionCard(),
          ),
          const SizedBox(height: 24),
          if (demographics != null) ...[
            demographics,
            const SizedBox(height: 24),
          ],
          if (roleSpecific != null) ...[
            roleSpecific,
            const SizedBox(height: 24),
          ],
          _buildMembersTrendCard(),
          const SizedBox(height: 24),
          _buildCollabTrendCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // The nested Navigator gives this view its own Overlay, which is why the
  // filter menus insert into the root overlay instead.
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return Navigator(
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (context) => _buildContent()),
    );
  }
}
