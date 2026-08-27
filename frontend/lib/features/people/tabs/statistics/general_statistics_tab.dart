import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/page_transition.dart';
import '../../models/current_totals_item.dart';
import '../../models/member_trend_item.dart';
import '../../models/retention_rate_item.dart';
import 'widgets/stat_filters.dart';
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
  bool _isTrendLoading = false;
  bool _isCollabTrendLoading = false;
  bool _isRetentionLoading = false;
  bool _isCollabRetentionLoading = false;
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

  // Every card fetches and reloads on its own; a shared load blanked the tab.

  Future<void> _loadRetentionData() async
  {
    setState(() => _isRetentionLoading = true);

    try
    {
      final data = await _apiService.getRetentionRate(_selectedRetentionYear);

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
          ? await _apiService.getRetentionRate(_selectedCollabYear)
          : await _apiService.getCollaboratingRetentionRate(
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
      final data = await _apiService.getMembersTrend(
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
      final data = await _apiService.getCollaboratingTrend(
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
      title: 'Trend iscritti totali',
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

  Widget _buildContent()
  {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pageTransitionBlocks([
          ResponsiveCardPair(
            first: SummaryStatCard(
              title: 'Iscritti totali',
              icon: Icons.groups_rounded,
              count: _currentTotals?.currentTotalMembers ?? 0,
              deltaMonth: _currentTotals?.membersDeltaMonth ?? 0,
              deltaYear: _currentTotals?.membersDeltaYear ?? 0,
            ),
            second: SummaryStatCard(
              title: 'Collaboratori attivi',
              icon: Icons.handshake_rounded,
              count: _currentTotals?.currentActiveCollaborators ?? 0,
              deltaMonth: _currentTotals?.collabDeltaMonth ?? 0,
              deltaYear: _currentTotals?.collabDeltaYear ?? 0,
            ),
          ),
          const SizedBox(height: 24),
          MatchedCardPair(
            first: _buildMembersRetentionCard,
            second: _buildCollabRetentionCard,
          ),
          const SizedBox(height: 24),
          _buildMembersTrendCard(),
          const SizedBox(height: 24),
          _buildCollabTrendCard(),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    // The nested Navigator gives this tab its own Overlay; the filter menus
    // insert into the root overlay instead.
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => _buildContent(),
      ),
    );
  }
}