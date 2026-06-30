import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/api_service.dart';
import '../../models/current_totals_item.dart';
import '../../models/member_trend_item.dart';
import '../../models/retention_rate_item.dart';

class GeneralStatisticsTab extends StatefulWidget 
{
  const GeneralStatisticsTab({super.key});

  @override
  State<GeneralStatisticsTab> createState() => _GeneralStatisticsTabState();
}

class _GeneralStatisticsTabState extends State<GeneralStatisticsTab> 
{
  bool                  _isLoading           = true;
  CurrentTotalsItem?    _currentTotals;
  List<MemberTrendItem> _trendData           = [];
  List<MemberTrendItem> _collabTrendData     = [];
  RetentionRateItem?    _retentionData;
  RetentionRateItem?    _collabRetentionData;

  String _trendResolution       = 'year';
  int    _startTrendYear        = 2022;
  int    _endTrendYear          = DateTime.now().year;
  String _collabTrendResolution = 'year';
  int    _startCollabTrendYear  = 2022;
  int    _endCollabTrendYear    = DateTime.now().year;

  int    _selectedRetentionYear = DateTime.now().year;
  String _collabRetentionType   = 'month';
  int    _selectedCollabYear    = DateTime.now().year;
  int    _selectedCollabMonth   = DateTime.now().month;

  static const List<String> _months = 
  [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
  ];

  @override
  void initState() 
  {
    super.initState();
    _loadData();
  }

  //GenerateFilledSequentialListIncludingZerosForMissingPeriods
  List<MemberTrendItem> _padTrendData(List<MemberTrendItem> rawData, String resolution, int startYear, int endYear) 
  {
    final List<MemberTrendItem> padded = [];
    
    if (resolution == 'year') 
    {
      for (int y = startYear; y <= endYear; y++) 
      {
        final existing = rawData.firstWhere
        (
          (e) => e.year == y,
          orElse: () => MemberTrendItem(year: y, totalMembers: -1),
        );
        padded.add(existing.totalMembers == -1 ? MemberTrendItem(year: y, totalMembers: 0) : existing);
      }
    } 
    else 
    {
      for (int y = startYear; y <= endYear; y++) 
      {
        final sMonth = (y == 2022) ? 11 : 1;
        final eMonth = (y == DateTime.now().year) ? DateTime.now().month : 12;
        
        for (int m = sMonth; m <= eMonth; m++) 
        {
          final existing = rawData.firstWhere
          (
            (e) => e.year == y && e.month == m,
            orElse: () => MemberTrendItem(year: y, month: m, totalMembers: -1),
          );
          padded.add(existing.totalMembers == -1 ? MemberTrendItem(year: y, month: m, totalMembers: 0) : existing);
        }
      }
    }
    return padded;
  }

  Future<void> _loadData() async 
  {
    setState(() => _isLoading = true);

    try 
    {
      final totalsFuture      = ApiService().getCurrentTotals();
      final trendFuture       = ApiService().getMembersTrend(resolution: _trendResolution, startYear: _startTrendYear, endYear: _endTrendYear);
      final collabTrendFuture = ApiService().getCollaboratingTrend(resolution: _collabTrendResolution, startYear: _startCollabTrendYear, endYear: _endCollabTrendYear);
      final retFuture         = ApiService().getRetentionRate(_selectedRetentionYear);

      Future<RetentionRateItem> collabRetFuture;
      if (_collabRetentionType == 'year') 
      {
        collabRetFuture = ApiService().getRetentionRate(_selectedCollabYear);
      } 
      else 
      {
        collabRetFuture = ApiService().getCollaboratingRetentionRate(_selectedCollabYear, _selectedCollabMonth);
      }

      final results = await Future.wait([totalsFuture, trendFuture, collabTrendFuture, retFuture, collabRetFuture]);

      final rawTrend       = results[1] as List<MemberTrendItem>;
      final rawCollabTrend = results[2] as List<MemberTrendItem>;

      _currentTotals       = results[0] as CurrentTotalsItem;
      _trendData           = _padTrendData(rawTrend, _trendResolution, _startTrendYear, _endTrendYear);
      _collabTrendData     = _padTrendData(rawCollabTrend, _collabTrendResolution, _startCollabTrendYear, _endCollabTrendYear);
      _retentionData       = results[3] as RetentionRateItem;
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

  List<_StatFilterOption<String>> _getResolutionOptions() 
  {
    return 
    [
      _StatFilterOption(value: 'year',  label: 'Annuale'), 
      _StatFilterOption(value: 'month', label: 'Mensile'),
    ];
  }

  List<_StatFilterOption<String>> _getRetentionTypeOptions() 
  {
    return 
    [
      _StatFilterOption(value: 'year',  label: 'Annuale'), 
      _StatFilterOption(value: 'month', label: 'Mensile'),
    ];
  }

  List<_StatFilterOption<int>> _getYearOptions() 
  {
    final currentYear = DateTime.now().year;
    return List.generate(currentYear - 2022 + 1, (index) => currentYear - index)
        .map((y) => _StatFilterOption(value: y, label: y.toString()))
        .toList();
  }

  List<_StatFilterOption<int>> _getCollabMonthOptions() 
  {
    if (_selectedCollabYear == 2022) 
    {
      return 
      [
        _StatFilterOption(value: 11, label: 'Nov'), 
        _StatFilterOption(value: 12, label: 'Dic'),
      ];
    }
    return List.generate(12, (index) => _StatFilterOption(value: index + 1, label: _months[index]));
  }

  Widget _buildStatBlock(String label, int value, bool isDelta) 
  {
    final sign  = value > 0 ? '+' : '';
    final color = isDelta && value < 0 ? const Color(0xFFE53935) : const Color(0xFF003C82);
    final text  = isDelta ? '$sign$value' : '$value';

    return Expanded
    (
      child: Column
      (
        crossAxisAlignment: CrossAxisAlignment.start,
        children: 
        [
          Text
          (
            label,
            style: GoogleFonts.plusJakartaSans
            (
              fontSize:   15,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row
          (
            crossAxisAlignment: CrossAxisAlignment.center,
            children: 
            [
              Text
              (
                text,
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   36,
                  fontWeight: FontWeight.w800,
                  color:      color,
                ),
              ),
              if (isDelta && value != 0) 
                Padding
                (
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon
                  (
                    value > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: color,
                    size:  26,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required int count, required int deltaMonth, required int deltaYear, required IconData icon}) 
  {
    //MakeCardSelectable
    return SelectionArea
    (
      child: Container
      (
        padding:    const EdgeInsets.all(24),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x0A000000), 
              offset:     Offset(0, 4), 
              blurRadius: 16,
            ),
          ],
        ),
        child: Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            Row
            (
              children: 
              [
                Container
                (
                  padding:    const EdgeInsets.all(10),
                  decoration: const BoxDecoration
                  (
                    color: Color(0xFFF5F8FC), 
                    shape: BoxShape.circle,
                  ),
                  child: Icon
                  (
                    icon, 
                    color: const Color(0xFF003C82), 
                    size:  24,
                  ),
                ),
                const SizedBox(width: 12),
                Text
                (
                  title, 
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   18, 
                    fontWeight: FontWeight.w700, 
                    color:      const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row
            (
              children: 
              [
                _buildStatBlock('Totale', count, false),
                Container
                (
                  width:  1, 
                  height: 45, 
                  color:  const Color(0xFFE2E8F0), 
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildStatBlock('Da inizio mese', deltaMonth, true),
                Container
                (
                  width:  1, 
                  height: 45, 
                  color:  const Color(0xFFE2E8F0), 
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildStatBlock('Da inizio anno', deltaYear, true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionCard() 
  {
    //MakeCardSelectable
    return SelectionArea
    (
      child: Container
      (
        padding:    const EdgeInsets.all(24),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x0A000000), 
              offset:     Offset(0, 4), 
              blurRadius: 16,
            ),
          ],
        ),
        child: Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            Row
            (
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: 
              [
                Text
                (
                  'Fidelizzazione Iscritti', 
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   18, 
                    fontWeight: FontWeight.w600, 
                    color:      const Color(0xFF1E293B),
                  ),
                ),
                _StatFilterMenu<int>
                (
                  hint:      'Anno', 
                  value:     _selectedRetentionYear, 
                  options:   _getYearOptions(),
                  onChanged: (v) 
                  { 
                    setState(() => _selectedRetentionYear = v); 
                    _loadData(); 
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_retentionData != null)
              Row
              (
                children: 
                [
                  Text
                  (
                    '${_retentionData!.retentionRatePercentage.toStringAsFixed(1)}%', 
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize:   54, 
                      fontWeight: FontWeight.w700, 
                      color:      const Color(0xFF003C82),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded
                  (
                    child: Text
                    (
                      _retentionData!.retainedMembers == 1 
                        ? '1 iscritto mantenuto su ${_retentionData!.previousYearMembers} dell\'anno precedente.'
                        : '${_retentionData!.retainedMembers} iscritti mantenuti su ${_retentionData!.previousYearMembers} dell\'anno precedente.', 
                      style: GoogleFonts.plusJakartaSans
                      (
                        fontSize: 16, 
                        color:    const Color(0xFF64748B), 
                        height:   1.5,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollabRetentionCard({required bool stackHeader}) 
  {
    final filtersWidget = Wrap
    (
      spacing:    12,
      runSpacing: 8,
      alignment:  WrapAlignment.start,
      children: 
      [
        _StatFilterMenu<String>
        (
          hint:      'Tipo', 
          value:     _collabRetentionType, 
          options:   _getRetentionTypeOptions(),
          onChanged: (v) 
          { 
            setState(() 
            { 
              _collabRetentionType = v; 
              if (v == 'month' && _selectedCollabYear == 2022 && _selectedCollabMonth < 11) 
              {
                _selectedCollabMonth = 11;
              }
            }); 
            _loadData(); 
          },
        ),
        if (_collabRetentionType == 'month')
          _StatFilterMenu<int>
          (
            hint:      'Mese', 
            value:     _selectedCollabMonth, 
            options:   _getCollabMonthOptions(),
            onChanged: (v) 
            { 
              setState(() => _selectedCollabMonth = v); 
              _loadData(); 
            },
          ),
        _StatFilterMenu<int>
        (
          hint:      'Anno', 
          value:     _selectedCollabYear, 
          options:   _getYearOptions(),
          onChanged: (v) 
          { 
            setState(() 
            { 
              _selectedCollabYear = v; 
              if (v == 2022 && _selectedCollabMonth < 11) 
              {
                _selectedCollabMonth = 11;
              }
            }); 
            _loadData(); 
          },
        ),
      ],
    );

    final titleWidget = Text
    (
      'Fidelizzazione Collaboratori Attivi', 
      style: GoogleFonts.plusJakartaSans
      (
        fontSize:   18, 
        fontWeight: FontWeight.w600, 
        color:      const Color(0xFF1E293B),
      ),
    );

    //MakeCardSelectable
    return SelectionArea
    (
      child: Container
      (
        padding:    const EdgeInsets.all(24),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x0A000000), 
              offset:     Offset(0, 4), 
              blurRadius: 16,
            ),
          ],
        ),
        child: Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            //SwitchBetweenInlineAndStackedHeaderBasedOnAvailableCardWidth
            stackHeader
              ? Column
                (
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: 
                  [
                    titleWidget,
                    const SizedBox(height: 12),
                    filtersWidget,
                  ],
                )
              : Row
                (
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: 
                  [
                    titleWidget,
                    filtersWidget,
                  ],
                ),
            const SizedBox(height: 24),
            if (_collabRetentionData != null)
              Row
              (
                children: 
                [
                  Text
                  (
                    '${_collabRetentionData!.retentionRatePercentage.toStringAsFixed(1)}%', 
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize:   54, 
                      fontWeight: FontWeight.w700, 
                      color:      const Color(0xFF003C82),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded
                  (
                    child: Text
                    (
                      _collabRetentionType == 'year'
                          ? (_collabRetentionData!.retainedMembers == 1 ? '1 collaboratore mantenuto rispetto ai ${_collabRetentionData!.previousYearMembers} attivi nell\'anno precedente.' : '${_collabRetentionData!.retainedMembers} collaboratori mantenuti rispetto ai ${_collabRetentionData!.previousYearMembers} attivi nell\'anno precedente.')
                          : (_collabRetentionData!.retainedMembers == 1 ? '1 collaboratore mantenuto rispetto ai ${_collabRetentionData!.previousYearMembers} attivi nel mese precedente.' : '${_collabRetentionData!.retainedMembers} collaboratori mantenuti rispetto ai ${_collabRetentionData!.previousYearMembers} attivi nel mese precedente.'),
                      style: GoogleFonts.plusJakartaSans
                      (
                        fontSize: 16, 
                        color:    const Color(0xFF64748B), 
                        height:   1.5,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartCard({required String title, required List<MemberTrendItem> data, required bool isMonthly, required bool showFilters, required String resolution, required int startYear, required int endYear, required ValueChanged<String> onResolutionChanged, required ValueChanged<int> onStartYearChanged, required ValueChanged<int> onEndYearChanged}) 
  {
    final filtersWidget = Wrap
    (
      spacing:    12,
      runSpacing: 8,
      alignment:  WrapAlignment.start,
      children: 
      [
        _StatFilterMenu<String>
        (
          hint:      'Risoluzione', 
          value:     resolution, 
          options:   _getResolutionOptions(), 
          onChanged: onResolutionChanged,
        ),
        _StatFilterMenu<int>
        (
          hint:      'Da anno', 
          value:     startYear, 
          options:   _getYearOptions(), 
          onChanged: onStartYearChanged,
        ),
        _StatFilterMenu<int>
        (
          hint:      'A anno', 
          value:     endYear, 
          options:   _getYearOptions(), 
          onChanged: onEndYearChanged,
        ),
      ],
    );

    final titleWidget = Text
    (
      title, 
      style: GoogleFonts.plusJakartaSans
      (
        fontSize:   18, 
        fontWeight: FontWeight.w600, 
        color:      const Color(0xFF1E293B),
      ),
    );

    //MakeCardSelectable
    return SelectionArea
    (
      child: Container
      (
        padding:    const EdgeInsets.all(24),
        decoration: BoxDecoration
        (
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    const 
          [
            BoxShadow
            (
              color:      Color(0x0A000000), 
              offset:     Offset(0, 4), 
              blurRadius: 16,
            ),
          ],
        ),
        child: Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            //SwitchBetweenInlineAndStackedHeaderBasedOnAvailableCardWidth
            LayoutBuilder
            (
              builder: (context, constraints) 
              {
                final stackHeader = showFilters && constraints.maxWidth < 760;

                return stackHeader
                  ? Column
                    (
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: 
                      [
                        titleWidget,
                        const SizedBox(height: 12),
                        filtersWidget,
                      ],
                    )
                  : Row
                    (
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: 
                      [
                        titleWidget,
                        if (showFilters) filtersWidget,
                      ],
                    );
              },
            ),
            const SizedBox(height: 48),
            SizedBox
            (
              height: 280,
              child: data.isEmpty 
                ? Center
                  (
                    child: Text
                    (
                      'Nessun dato', 
                      style: GoogleFonts.plusJakartaSans
                      (
                        color:    const Color(0xFF94A3B8), 
                        fontSize: 16,
                      ),
                    ),
                  )
                : _LineChartWidget
                  (
                    data:      data, 
                    isMonthly: isMonthly,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    if (_isLoading) 
    {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)));
    }

    return Navigator
    (
      onGenerateRoute: (settings) => MaterialPageRoute
      (
        builder: (context) => SingleChildScrollView
        (
          physics: const BouncingScrollPhysics(),
          child: Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              Row
              (
                children: 
                [
                  Expanded
                  (
                    child: _buildSummaryCard
                    (
                      title:      'Iscritti Totali', 
                      count:      _currentTotals?.currentTotalMembers ?? 0, 
                      deltaMonth: _currentTotals?.membersDeltaMonth ?? 0,
                      deltaYear:  _currentTotals?.membersDeltaYear ?? 0,
                      icon:       Icons.people_alt_outlined,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded
                  (
                    child: _buildSummaryCard
                    (
                      title:      'Collaboratori Attivi', 
                      count:      _currentTotals?.currentActiveCollaborators ?? 0, 
                      deltaMonth: _currentTotals?.collabDeltaMonth ?? 0,
                      deltaYear:  _currentTotals?.collabDeltaYear ?? 0,
                      icon:       Icons.handshake_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder
              (
                builder: (context, constraints) 
                {
                  final cardWidth   = (constraints.maxWidth - 24) / 2;
                  final stackHeader = cardWidth < 620;

                  return Row
                  (
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: 
                    [
                      Expanded(child: _buildRetentionCard()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildCollabRetentionCard(stackHeader: stackHeader)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildTrendChartCard
              (
                title:               'Trend Iscritti Totali', 
                data:                _trendData, 
                isMonthly:           _trendResolution == 'month', 
                showFilters:         true,
                resolution:          _trendResolution, 
                startYear:           _startTrendYear, 
                endYear:             _endTrendYear,
                onResolutionChanged: (v) 
                { 
                  setState(() => _trendResolution = v); 
                  _loadData(); 
                },
                onStartYearChanged:  (v) 
                { 
                  setState(() 
                  { 
                    _startTrendYear = v; 
                    if (_endTrendYear < v) 
                    {
                      _endTrendYear = v; 
                    }
                  }); 
                  _loadData(); 
                },
                onEndYearChanged:    (v) 
                { 
                  setState(() 
                  { 
                    _endTrendYear = v; 
                    if (_startTrendYear > v) 
                    {
                      _startTrendYear = v; 
                    }
                  }); 
                  _loadData(); 
                },
              ),
              const SizedBox(height: 24),
              _buildTrendChartCard
              (
                title:               'Trend Collaboratori Attivi', 
                data:                _collabTrendData, 
                isMonthly:           _collabTrendResolution == 'month', 
                showFilters:         true,
                resolution:          _collabTrendResolution, 
                startYear:           _startCollabTrendYear, 
                endYear:             _endCollabTrendYear,
                onResolutionChanged: (v) 
                { 
                  setState(() => _collabTrendResolution = v); 
                  _loadData(); 
                },
                onStartYearChanged:  (v) 
                { 
                  setState(() 
                  { 
                    _startCollabTrendYear = v; 
                    if (_endCollabTrendYear < v) 
                    {
                      _endCollabTrendYear = v; 
                    }
                  }); 
                  _loadData(); 
                },
                onEndYearChanged:    (v) 
                { 
                  setState(() 
                  { 
                    _endCollabTrendYear = v; 
                    if (_startCollabTrendYear > v) 
                    {
                      _startCollabTrendYear = v; 
                    }
                  }); 
                  _loadData(); 
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineChartWidget extends StatefulWidget 
{
  final List<MemberTrendItem> data;
  final bool                  isMonthly;

  const _LineChartWidget
  ({
    required this.data, 
    required this.isMonthly,
  });

  @override
  State<_LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<_LineChartWidget> 
{
  Offset? _hoverPosition;
  int?    _hoveredIndex;
  Offset? _popupTargetPosition;
  int?    _cachedMembersValue;

  @override
  Widget build(BuildContext context) 
  {
    final rawMax   = widget.data.map((e) => e.totalMembers).reduce(math.max);
    final mathMax  = rawMax == 0 ? 4 : (rawMax * 1.2).ceil();
    //EnforceGridmaxValueToBeAMultipleOf4ToPreventOverlappingFractions
    final maxValue = mathMax < 4 ? 4 : ((mathMax + 3) ~/ 4) * 4;

    return LayoutBuilder
    (
      builder: (context, constraints) 
      {
        const paddingBottom = 30.0;
        const paddingLeft   = 40.0;
        final chartWidth    = constraints.maxWidth - paddingLeft;
        final chartHeight   = constraints.maxHeight - paddingBottom;

        final points = <Offset>[];
        final stepX  = widget.data.length > 1 ? chartWidth / (widget.data.length - 1) : chartWidth / 2;

        for (int i = 0; i < widget.data.length; i++) 
        {
          points.add(Offset(paddingLeft + (i * stepX), chartHeight - ((widget.data[i].totalMembers / maxValue) * chartHeight)));
        }

        return Stack
        (
          clipBehavior: Clip.none,
          children: 
          [
            Positioned.fill
            (
              child: MouseRegion
              (
                onHover: (event) 
                {
                  final pos = event.localPosition;
                  int? foundIndex;
                  for (int i = 0; i < points.length; i++) 
                  {
                    if (math.sqrt(math.pow(points[i].dx - pos.dx, 2) + math.pow(points[i].dy - pos.dy, 2)) < 16.0) 
                    {
                      foundIndex = i;
                      break;
                    }
                  }
                  setState(() 
                  { 
                    _hoverPosition = pos; 
                    _hoveredIndex  = foundIndex; 
                    if (foundIndex != null) 
                    { 
                      _popupTargetPosition = points[foundIndex]; 
                      _cachedMembersValue  = widget.data[foundIndex].totalMembers; 
                    } 
                  });
                },
                onExit: (_) => setState(() 
                { 
                  _hoverPosition = null; 
                  _hoveredIndex  = null; 
                }),
                child: CustomPaint
                (
                  size:    Size.infinite, 
                  painter: _LineChartPainter
                  (
                    data:          widget.data, 
                    maxValue:      maxValue, 
                    isMonthly:     widget.isMonthly, 
                    hoverPosition: _hoverPosition,
                  ),
                ),
              ),
            ),
            if (_popupTargetPosition != null)
              Positioned
              (
                left: _popupTargetPosition!.dx, 
                top:  _popupTargetPosition!.dy - 10,
                child: IgnorePointer
                (
                  child: FractionalTranslation
                  (
                    translation: const Offset(-0.5, -1.0),
                    child: AnimatedScale
                    (
                      scale:    _hoveredIndex != null ? 1.0 : 0.6, 
                      duration: const Duration(milliseconds: 200), 
                      curve:    Curves.easeOutBack,
                      child: AnimatedOpacity
                      (
                        opacity:  _hoveredIndex != null ? 1.0 : 0.0, 
                        duration: const Duration(milliseconds: 150), 
                        curve:    Curves.easeOut,
                        child: Column
                        (
                          mainAxisSize: MainAxisSize.min,
                          children: 
                          [
                            Container
                            (
                              padding:    const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                              decoration: BoxDecoration
                              (
                                color:        const Color(0xFF1E293B), 
                                borderRadius: BorderRadius.circular(8), 
                                boxShadow:    const 
                                [
                                  BoxShadow
                                  (
                                    color:      Color(0x1F000000), 
                                    offset:     Offset(0, 3), 
                                    blurRadius: 6,
                                  ),
                                ],
                              ), 
                              child: Text
                              (
                                '${_cachedMembersValue ?? 0}', 
                                style: GoogleFonts.plusJakartaSans
                                (
                                  color:      Colors.white, 
                                  fontSize:   14, 
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            CustomPaint
                            (
                              size:    const Size(10, 5), 
                              painter: _TriangleArrowPainter(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TriangleArrowPainter extends CustomPainter 
{
  @override
  void paint(Canvas canvas, Size size) 
  {
    canvas.drawPath
    (
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(), 
      Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter 
{
  final List<MemberTrendItem> data;
  final int                   maxValue;
  final bool                  isMonthly;
  final Offset?               hoverPosition;

  static const List<String> _monthNames = 
  [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
  ];

  _LineChartPainter
  ({
    required this.data, 
    required this.maxValue, 
    required this.isMonthly, 
    this.hoverPosition,
  });

  @override
  void paint(Canvas canvas, Size size) 
  {
    if (data.isEmpty) 
    {
      return;
    }
    
    final paintLine   = Paint()
      ..color       = const Color(0xFF003C82)
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;
      
    final paintGrid   = Paint()
      ..color       = const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style       = PaintingStyle.stroke;
      
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const paddingBottom = 30.0;
    const paddingLeft   = 40.0;
    final chartWidth    = size.width - paddingLeft;
    final chartHeight   = size.height - paddingBottom;

    for (int i = 0; i <= 4; i++) 
    {
      final y = chartHeight - (i * (chartHeight / 4));
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width, y), paintGrid);
      textPainter.text = TextSpan
      (
        text:  '${((maxValue / 4) * i).round()}', 
        style: GoogleFonts.plusJakartaSans
        (
          color:    const Color(0xFF94A3B8), 
          fontSize: 13,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 8, y - 6));
    }

    final points = <Offset>[];
    final stepX  = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth / 2;

    for (int i = 0; i < data.length; i++) 
    {
      final x = paddingLeft + (i * stepX);
      final y = chartHeight - ((data[i].totalMembers / maxValue) * chartHeight);
      points.add(Offset(x, y));

      textPainter.text      = TextSpan
      (
        text:  isMonthly ? '${_monthNames[(data[i].month ?? 1) - 1]}\n${data[i].year}' : '${data[i].year}', 
        style: GoogleFonts.plusJakartaSans
        (
          color:    const Color(0xFF94A3B8), 
          fontSize: 13,
        ),
      );
      textPainter.textAlign = TextAlign.center;
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), chartHeight + 8));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) 
    {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paintLine);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();
      
    canvas.drawPath
    (
      fillPath, 
      Paint()
        ..shader = LinearGradient
        (
          colors: [const Color(0x33003C82), const Color(0x00003C82)], 
          begin:  Alignment.topCenter, 
          end:    Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(paddingLeft, 0, chartWidth, chartHeight))
        ..style  = PaintingStyle.fill,
    );

    for (final point in points) 
    {
      canvas.drawCircle(point, 5, Paint()..color = const Color(0xFF003C82)..style = PaintingStyle.fill);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.hoverPosition != hoverPosition || oldDelegate.data != data;
}

class _StatFilterOption<T> 
{ 
  final T      value; 
  final String label; 
  
  _StatFilterOption
  ({
    required this.value, 
    required this.label,
  }); 
}

class _StatFilterMenu<T> extends StatefulWidget 
{ 
  final String                     hint; 
  final T                          value; 
  final List<_StatFilterOption<T>> options; 
  final ValueChanged<T>            onChanged; 

  const _StatFilterMenu
  ({
    required this.hint, 
    required this.value, 
    required this.options, 
    required this.onChanged,
  }); 

  @override 
  State<_StatFilterMenu<T>> createState() => _StatFilterMenuState<T>(); 
}

class _StatFilterMenuState<T> extends State<_StatFilterMenu<T>> 
{ 
  final GlobalKey                                 _buttonKey = GlobalKey(); 
  OverlayEntry?                                   _overlayEntry; 
  final GlobalKey<_StatFilterOverlayContentState> _menuKey   = GlobalKey(); 
  bool                                            _isHovered = false; 
  bool                                            _isMenuOpen = false; 

  void _toggleMenu() 
  { 
    if (_overlayEntry != null) 
    { 
      _closeMenu(); 
      return; 
    } 

    setState(() => _isMenuOpen = true); 
    
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox; 
    final size      = renderBox.size; 
    //ConvertCoordinatesBasedOnTheRootOverlayToAvoidNestedNavigatorShifts
    final offset    = renderBox.localToGlobal(Offset.zero); 

    _overlayEntry = OverlayEntry
    (
      builder: (context) => Stack
      (
        children: 
        [
          Positioned.fill
          (
            child: GestureDetector
            (
              behavior: HitTestBehavior.opaque, 
              onTap:    _closeMenu, 
              child:    Container(),
            ),
          ), 
          Positioned
          (
            top:  offset.dy + size.height + 8, 
            left: offset.dx, 
            child: _StatFilterOverlayContent<T>
            (
              key:          _menuKey, 
              currentValue: widget.value, 
              options:      widget.options, 
              onSelected:   (val) 
              { 
                widget.onChanged(val); 
                _closeMenu(); 
              },
            ),
          ),
        ],
      ),
    ); 
    //UseRootOverlayToEnsureCorrectScreenSpaceAlignment
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!); 
  }

  void _closeMenu() async 
  { 
    if (_overlayEntry != null) 
    { 
      setState(() => _isMenuOpen = false); 
      await _menuKey.currentState?.hide(); 
      _overlayEntry?.remove(); 
      _overlayEntry = null; 
    } 
  } 

  @override 
  Widget build(BuildContext context) 
  { 
    final selectedOption = widget.options.firstWhere
    (
      (o) => o.value == widget.value, 
      orElse: () => _StatFilterOption(value: widget.value, label: ''),
    ); 
    
    return MouseRegion
    (
      cursor:  SystemMouseCursors.click, 
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit:  (_) => setState(() => _isHovered = false), 
      child: GestureDetector
      (
        onTap: _toggleMenu, 
        child: AnimatedContainer
        (
          key:        _buttonKey, 
          duration:   const Duration(milliseconds: 200), 
          height:     42, 
          padding:    const EdgeInsets.symmetric(horizontal: 16), 
          decoration: BoxDecoration
          (
            color:        _isHovered ? const Color(0xFFF5F8FC) : Colors.white, 
            borderRadius: BorderRadius.circular(20), 
            border:       Border.all
            (
              color: _isHovered ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), 
              width: 1.5,
            ), 
            boxShadow:    const 
            [
              BoxShadow
              (
                color:      Color(0x05000000), 
                offset:     Offset(0, 2), 
                blurRadius: 8,
              ),
            ],
          ), 
          child: Row
          (
            mainAxisSize: MainAxisSize.min, 
            children: 
            [
              Text
              (
                '${widget.hint}: ', 
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   14, 
                  fontWeight: FontWeight.w500, 
                  color:      const Color(0xFF8A8A8A),
                ),
              ), 
              Text
              (
                selectedOption.label, 
                style: GoogleFonts.plusJakartaSans
                (
                  fontSize:   14, 
                  fontWeight: FontWeight.w600, 
                  color:      const Color(0xFF003C82),
                ),
              ), 
              const SizedBox(width: 8), 
              AnimatedRotation
              (
                turns:    _isMenuOpen ? 0.5 : 0.0, 
                duration: const Duration(milliseconds: 200), 
                curve:    Curves.easeInOut, 
                child:    const Icon
                (
                  Icons.keyboard_arrow_down_rounded, 
                  color: Color(0xFF003C82), 
                  size:  18,
                ),
              ),
            ],
          ),
        ),
      ),
    ); 
  } 
}

class _StatFilterOverlayContent<T> extends StatefulWidget 
{ 
  final T                            currentValue; 
  final List<_StatFilterOption<T>>   options; 
  final ValueChanged<T>              onSelected; 

  const _StatFilterOverlayContent
  ({
    super.key, 
    required this.currentValue, 
    required this.options, 
    required this.onSelected,
  }); 

  @override 
  State<_StatFilterOverlayContent<T>> createState() => _StatFilterOverlayContentState<T>(); 
}

class _StatFilterOverlayContentState<T> extends State<_StatFilterOverlayContent<T>> 
{ 
  bool _expanded = false; 

  @override 
  void initState() 
  { 
    super.initState(); 
    WidgetsBinding.instance.addPostFrameCallback((_) 
    { 
      if (mounted) 
      {
        setState(() => _expanded = true); 
      }
    }); 
  } 

  Future<void> hide() async 
  { 
    if (mounted) 
    {
      setState(() => _expanded = false); 
    }
    await Future.delayed(const Duration(milliseconds: 180)); 
  } 

  @override 
  Widget build(BuildContext context) 
  { 
    return Material
    (
      color: Colors.transparent, 
      child: IntrinsicWidth
      (
        child: Container
        (
          constraints: const BoxConstraints(maxHeight: 300, minWidth: 130), 
          decoration:  BoxDecoration
          (
            color:        Colors.white, 
            borderRadius: BorderRadius.circular(16), 
            boxShadow:    const 
            [
              BoxShadow
              (
                color:        Color(0x14000000), 
                blurRadius:   20, 
                spreadRadius: 2,
              ),
            ],
          ), 
          child: AnimatedSize
          (
            duration:  const Duration(milliseconds: 180), 
            curve:     Curves.easeOut, 
            alignment: Alignment.topCenter, 
            child: _expanded 
              ? Padding
                (
                  padding: const EdgeInsets.symmetric(vertical: 8), 
                  child: SingleChildScrollView
                  (
                    child: Column
                    (
                      mainAxisSize:       MainAxisSize.min, 
                      crossAxisAlignment: CrossAxisAlignment.stretch, 
                      children:           widget.options.map((option) 
                      { 
                        return _StatFilterMenuItem
                        (
                          text:       option.label, 
                          isSelected: widget.currentValue == option.value, 
                          onTap:      () => widget.onSelected(option.value),
                        ); 
                      }).toList(),
                    ),
                  ),
                ) 
              : const SizedBox.shrink(),
          ),
        ),
      ),
    ); 
  } 
}

class _StatFilterMenuItem extends StatefulWidget 
{ 
  final String       text; 
  final bool         isSelected; 
  final VoidCallback onTap; 

  const _StatFilterMenuItem
  ({
    required this.text, 
    required this.isSelected, 
    required this.onTap,
  }); 

  @override 
  State<_StatFilterMenuItem> createState() => _StatFilterMenuItemState(); 
}

class _StatFilterMenuItemState extends State<_StatFilterMenuItem> 
{ 
  bool _hover = false; 

  @override 
  Widget build(BuildContext context) 
  { 
    return MouseRegion
    (
      cursor:  SystemMouseCursors.click, 
      onEnter: (_) => setState(() => _hover = true), 
      onExit:  (_) => setState(() => _hover = false), 
      child: GestureDetector
      (
        onTap: widget.onTap, 
        child: Container
        (
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          color:   Colors.transparent, 
          child: Row
          (
            children: 
            [
              AnimatedContainer
              (
                duration:   const Duration(milliseconds: 150), 
                width:      2, 
                height:     (_hover || widget.isSelected) ? 16 : 0, 
                decoration: BoxDecoration
                (
                  color:        const Color(0xFF003C82), 
                  borderRadius: BorderRadius.circular(2),
                ),
              ), 
              const SizedBox(width: 10), 
              Expanded
              (
                child: Text
                (
                  widget.text, 
                  overflow: TextOverflow.ellipsis, 
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   14, 
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500, 
                    color:      const Color(0xFF003C82),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ); 
  } 
}