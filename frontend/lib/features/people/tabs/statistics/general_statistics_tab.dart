import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../models/current_totals_item.dart';
import '../../models/member_trend_item.dart';
import '../../models/retention_rate_item.dart';
import 'widgets/stat_filter_menu.dart';
import 'widgets/stat_widgets.dart';
import 'widgets/stats_constants.dart';
import 'widgets/stats_data.dart';
import 'widgets/stats_layout.dart';
import 'widgets/trend_line_chart.dart';

class GeneralStatisticsTab extends StatefulWidget
{
  const GeneralStatisticsTab({super.key});

  @override
  State<GeneralStatisticsTab> createState() => _GeneralStatisticsTabState();
}

class _GeneralStatisticsTabState extends State<GeneralStatisticsTab>
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  CurrentTotalsItem? _currentTotals;
  List<MemberTrendItem> _trendData = [];
  List<MemberTrendItem> _collabTrendData = [];
  RetentionRateItem? _retentionData;
  RetentionRateItem? _collabRetentionData;

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

  @override
  void initState()
  {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async
  {
    setState(() => _isLoading = true);

    try
    {
      final collabRetentionFuture = _collabRetentionType == 'year'
          ? _apiService.getRetentionRate(_selectedCollabYear)
          : _apiService.getCollaboratingRetentionRate(_selectedCollabYear, _selectedCollabMonth);

      final results = await Future.wait([
        _apiService.getCurrentTotals(),
        _apiService.getMembersTrend(
          resolution: _trendResolution,
          startYear: _startTrendYear,
          endYear: _endTrendYear,
        ),
        _apiService.getCollaboratingTrend(
          resolution: _collabTrendResolution,
          startYear: _startCollabTrendYear,
          endYear: _endCollabTrendYear,
        ),
        _apiService.getRetentionRate(_selectedRetentionYear),
        collabRetentionFuture,
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
    }
    catch (_)
    {}
    finally
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
      }
    }
  }

    void _clampCollabMonthToDataStart()
  {
    if (_selectedCollabYear == dataStartYear && _selectedCollabMonth < dataStartMonth)
    {
      _selectedCollabMonth = dataStartMonth;
    }
  }

  void _reload(VoidCallback mutateState)
  {
    setState(mutateState);
    _loadData();
  }

  // Shared shell of the two retention cards: they differ only in the filters
  // above and in the sentence explaining the percentage.
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

  Widget _buildMembersRetentionCard()
  {
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

  Widget _buildCollabRetentionCard()
  {
    final filters = Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        StatFilterMenu<String>(
          hint: 'Tipo',
          value: _collabRetentionType,
          options: resolutionOptions(),
          onChanged: (value) => _reload(()
          {
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
          onChanged: (value) => _reload(()
          {
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
  })
  {
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

  Widget _buildMembersTrendCard()
  {
    return _buildTrendChartCard(
      title: 'Trend Iscritti Totali',
      data: _trendData,
      resolution: _trendResolution,
      startYear: _startTrendYear,
      endYear: _endTrendYear,
      onResolutionChanged: (value) => _reload(() => _trendResolution = value),
      // The two bounds push each other, so the range can never invert.
      onStartYearChanged: (value) => _reload(()
      {
        _startTrendYear = value;

        if (_endTrendYear < value)
        {
          _endTrendYear = value;
        }
      }),
      onEndYearChanged: (value) => _reload(()
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
      title: 'Trend Collaboratori Attivi',
      data: _collabTrendData,
      resolution: _collabTrendResolution,
      startYear: _startCollabTrendYear,
      endYear: _endCollabTrendYear,
      onResolutionChanged: (value) => _reload(() => _collabTrendResolution = value),
      onStartYearChanged: (value) => _reload(()
      {
        _startCollabTrendYear = value;

        if (_endCollabTrendYear < value)
        {
          _endCollabTrendYear = value;
        }
      }),
      onEndYearChanged: (value) => _reload(()
      {
        _endCollabTrendYear = value;

        if (_startCollabTrendYear > value)
        {
          _startCollabTrendYear = value;
        }
      }),
    );
  }

  Widget _buildContent()
  {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveCardPair(
            first: SummaryStatCard(
              title: 'Iscritti Totali',
              icon: Icons.people_alt_outlined,
              count: _currentTotals?.currentTotalMembers ?? 0,
              deltaMonth: _currentTotals?.membersDeltaMonth ?? 0,
              deltaYear: _currentTotals?.membersDeltaYear ?? 0,
            ),
            second: SummaryStatCard(
              title: 'Collaboratori Attivi',
              icon: Icons.handshake_outlined,
              count: _currentTotals?.currentActiveCollaborators ?? 0,
              deltaMonth: _currentTotals?.collabDeltaMonth ?? 0,
              deltaYear: _currentTotals?.collabDeltaYear ?? 0,
            ),
          ),
          const SizedBox(height: 24),
          ResponsiveCardPair(
            first: _buildMembersRetentionCard(),
            second: _buildCollabRetentionCard(),
          ),
          const SizedBox(height: 24),
          _buildMembersTrendCard(),
          const SizedBox(height: 24),
          _buildCollabTrendCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    // The nested Navigator gives this tab its own Overlay, which is why the
    // filter menus below insert into the root overlay instead.
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => _buildContent(),
      ),
    );
  }
}