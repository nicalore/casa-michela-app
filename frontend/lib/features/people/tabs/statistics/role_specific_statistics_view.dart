import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/api_service.dart';
import '../../models/current_totals_item.dart';
import '../../models/member_trend_item.dart';
import '../../models/retention_rate_item.dart';
import '../../models/city_distribution_item.dart';
import '../../models/age_distribution_item.dart';
import '../../models/education_distribution_item.dart';
import '../../models/teacher_subjects_statistics_item.dart';
import '../../models/course_distribution_item.dart';

class ChartBarItem 
{
  final String label;
  final int    count;

  ChartBarItem
  ({
    required this.label, 
    required this.count,
  });
}

class ChartPieItem 
{
  final String label;
  final int    count;

  ChartPieItem
  ({
    required this.label, 
    required this.count,
  });
}

class RoleSpecificStatisticsView extends StatefulWidget 
{
  final String roleKey;
  
  const RoleSpecificStatisticsView
  ({
    required this.roleKey, 
    super.key,
  });
  
  @override
  State<RoleSpecificStatisticsView> createState() => _RoleSpecificStatisticsViewState();
}

class _RoleSpecificStatisticsViewState extends State<RoleSpecificStatisticsView> 
{
  bool                            _isLoading                 = true;
  CurrentTotalsItem?              _currentTotals;
  List<MemberTrendItem>           _trendData                 = [];
  List<MemberTrendItem>           _collabTrendData           = [];
  RetentionRateItem?              _retentionData;
  RetentionRateItem?              _collabRetentionData;
  
  List<CityDistributionItem>      _cityData                  = [];
  List<AgeDistributionItem>       _ageData                   = [];
  List<EducationDistributionItem> _educationData             = [];
  List<CourseDistributionItem>    _courseData                = [];
  TeacherSubjectsStatisticsItem?  _teacherStats;

  String                          _trendResolution           = 'year';
  int                             _startTrendYear            = 2022;
  int                             _endTrendYear              = DateTime.now().year;
  String                          _collabTrendResolution     = 'year';
  int                             _startCollabTrendYear      = 2022;
  int                             _endCollabTrendYear        = DateTime.now().year;

  int                             _selectedRetentionYear     = DateTime.now().year;
  String                          _collabRetentionType       = 'month';
  int                             _selectedCollabYear        = DateTime.now().year;
  int                             _selectedCollabMonth       = DateTime.now().month;

  String                          _educationDistributionType = 'school';
  String                          _teacherRankingMode        = 'absolute';

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

  String _translateArea(String area)
  {
    switch (area)
    {
      case 'HUMANITIES':  return 'Area Umanistica';
      case 'LINGUISTICS': return 'Area Linguistica';
      case 'SCIENCES':    return 'Area Scientifica';
      default:            return area;
    }
  }

  List<_FilterMenuOption<int>> _getYearOptions() 
  {
    final currentYear = DateTime.now().year;
    return List.generate(currentYear - 2022 + 1, (index) => currentYear - index)
        .map((y) => _FilterMenuOption(value: y, label: y.toString()))
        .toList();
  }

  List<_FilterMenuOption<int>> _getCollabMonthOptions() 
  {
    if (_selectedCollabYear == 2022) 
    {
      return 
      [
        _FilterMenuOption(value: 11, label: 'Nov'), 
        _FilterMenuOption(value: 12, label: 'Dic'),
      ];
    }
    return List.generate(12, (index) => _FilterMenuOption(value: index + 1, label: _months[index]));
  }

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

  Future<void> _loadEducationData() async 
  {
    if (widget.roleKey != 'student') 
    {
      return;
    }
    try 
    {
      final data = await ApiService().getStudentEducationDistribution(_educationDistributionType);
      if (mounted) 
      {
        setState(() => _educationData = data);
      }
    } 
    catch (_) {}
  }

  Future<void> _loadTeacherData() async 
  {
    if (widget.roleKey != 'teacher') 
    {
      return;
    }
    try 
    {
      final data = await ApiService().getTeacherSubjectsStatistics(_teacherRankingMode);
      if (mounted) 
      {
        setState(() => _teacherStats = data);
      }
    } 
    catch (_) {}
  }

  Future<void> _loadCourseData() async 
  {
    if (widget.roleKey != 'course_participant') 
    {
      return;
    }
    try 
    {
      final data = await ApiService().getCourseParticipantDistribution();
      if (mounted) 
      {
        setState(() => _courseData = data);
      }
    } 
    catch (_) {}
  }

  Future<void> _loadData() async 
  {
    setState(() => _isLoading = true);

    try 
    {
      final api = ApiService();
      
      final totalsFuture      = api.getRoleCurrentTotals(widget.roleKey);
      final trendFuture       = api.getRoleMembersTrend(role: widget.roleKey, resolution: _trendResolution, startYear: _startTrendYear, endYear: _endTrendYear);
      final collabTrendFuture = api.getRoleCollaboratingTrend(role: widget.roleKey, resolution: _collabTrendResolution, startYear: _startCollabTrendYear, endYear: _endCollabTrendYear);
      final retFuture         = api.getRoleRetentionRate(widget.roleKey, _selectedRetentionYear);

      Future<RetentionRateItem> collabRetFuture;
      if (_collabRetentionType == 'year') 
      {
        collabRetFuture = api.getRoleRetentionRate(widget.roleKey, _selectedCollabYear);
      } 
      else 
      {
        collabRetFuture = api.getRoleCollaboratingRetentionRate(widget.roleKey, _selectedCollabYear, _selectedCollabMonth);
      }

      final fetchCity = (widget.roleKey == 'teacher' || widget.roleKey == 'student' || widget.roleKey == 'course_participant');
      final fetchAge  = (widget.roleKey == 'teacher' || widget.roleKey == 'student' || widget.roleKey == 'course_participant');

      final cityFuture = fetchCity ? api.getRoleCityDistribution(widget.roleKey) : Future.value(<CityDistributionItem>[]);
      final ageFuture  = fetchAge  ? api.getRoleAgeDistribution(widget.roleKey)  : Future.value(<AgeDistributionItem>[]);

      final results = await Future.wait([totalsFuture, trendFuture, collabTrendFuture, retFuture, collabRetFuture, cityFuture, ageFuture]);

      final rawTrend       = results[1] as List<MemberTrendItem>;
      final rawCollabTrend = results[2] as List<MemberTrendItem>;

      _currentTotals       = results[0] as CurrentTotalsItem;
      _trendData           = _padTrendData(rawTrend, _trendResolution, _startTrendYear, _endTrendYear);
      _collabTrendData     = _padTrendData(rawCollabTrend, _collabTrendResolution, _startCollabTrendYear, _endCollabTrendYear);
      _retentionData       = results[3] as RetentionRateItem;
      _collabRetentionData = results[4] as RetentionRateItem;
      
      _cityData            = results[5] as List<CityDistributionItem>;
      _ageData             = AntiquityHelper.sortAgeGroups(results[6] as List<AgeDistributionItem>);

      if (widget.roleKey == 'student') 
      {
        await _loadEducationData();
      } 
      else if (widget.roleKey == 'teacher') 
      {
        await _loadTeacherData();
      }
      else if (widget.roleKey == 'course_participant')
      {
        await _loadCourseData();
      }
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

  List<_FilterMenuOption<String>> _getResolutionOptions() 
  {
    return 
    [
      _FilterMenuOption(value: 'year',  label: 'Annuale'), 
      _FilterMenuOption(value: 'month', label: 'Mensile'),
    ];
  }

  Widget _buildStatBlock(String label, int value, bool isDelta, {double? percentage}) 
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline:       TextBaseline.alphabetic,
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
              if (percentage != null)
                Padding
                (
                  padding: const EdgeInsets.only(left: 10),
                  child: Text
                  (
                    '${percentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans
                    (
                      fontSize:   24,
                      fontWeight: FontWeight.w600,
                      color:      const Color(0xFF94A3B8),
                    ),
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

  Widget _buildSummaryCard({required String title, required int count, required int deltaMonth, required int deltaYear, required IconData icon, double? percentage}) 
  {
    //IsolateSelectionToCardBody
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
                _buildStatBlock('Totale', count, false, percentage: percentage),
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

  Widget _buildIscrittiRetentionCard() 
  {
    //IsolateSelectionToCardBody
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
                _FilterMenuWidget<int>
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
        _FilterMenuWidget<String>
        (
          hint:    'Tipo', 
          value:   _collabRetentionType, 
          options: 
          [
            _FilterMenuOption(value: 'year',  label: 'Annuale'), 
            _FilterMenuOption(value: 'month', label: 'Mensile'),
          ], 
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
          _FilterMenuWidget<int>
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
        _FilterMenuWidget<int>
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

    //IsolateSelectionToCardBody
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
        _FilterMenuWidget<String>
        (
          hint:      'Risoluzione', 
          value:     resolution, 
          options:   _getResolutionOptions(), 
          onChanged: onResolutionChanged,
        ),
        _FilterMenuWidget<int>
        (
          hint:      'Da anno', 
          value:     startYear, 
          options:   _getYearOptions(), 
          onChanged: onStartYearChanged,
        ),
        _FilterMenuWidget<int>
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

    //IsolateSelectionToCardBody
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
              child:  data.isEmpty 
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

  Widget _buildCityChartCard() 
  {
    //IsolateSelectionToCardBody
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
            Text
            (
              'Distribuzione per città', 
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   18, 
                fontWeight: FontWeight.w600, 
                color:      const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox
            (
              height: 280, 
              child:  _cityData.isEmpty 
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
                : _BarChartWidget
                  (
                    data: _cityData.map((e) => ChartBarItem(label: e.city, count: e.count)).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeChartCard() 
  {
    //IsolateSelectionToCardBody
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
            Text
            (
              'Fasce di età', 
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   18, 
                fontWeight: FontWeight.w600, 
                color:      const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox
            (
              height: 296, 
              child:  _ageData.isEmpty 
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
                : _PieChartWidget
                  (
                    data: _ageData.map((e) => ChartPieItem(label: e.ageGroup, count: e.count)).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationChartCard() 
  {
    //IsolateSelectionToCardBody
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
                  'Distribuzione scolastica', 
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   18, 
                    fontWeight: FontWeight.w600, 
                    color:      const Color(0xFF1E293B),
                  ),
                ),
                _FilterMenuWidget<String>
                (
                  hint:    'Raggruppa per', 
                  value:   _educationDistributionType, 
                  options: 
                  [
                    _FilterMenuOption(value: 'school',  label: 'Scuola'),
                    _FilterMenuOption(value: 'program', label: 'Percorso di studio'),
                    _FilterMenuOption(value: 'level',   label: 'Livello di istruzione'),
                  ], 
                  onChanged: (v) 
                  { 
                    setState(() => _educationDistributionType = v); 
                    _loadEducationData(); 
                  },
                ),
              ],
            ),
            const SizedBox(height: 48),
            SizedBox
            (
              height: 280, 
              child:  _educationData.isEmpty 
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
                : _BarChartWidget
                  (
                    data: _educationData.map((e) => ChartBarItem(label: e.label, count: e.count)).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseChartCard() 
  {
    //IsolateSelectionToCardBody
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
            Text
            (
              'Distribuzione per corso', 
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   18, 
                fontWeight: FontWeight.w600, 
                color:      const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox
            (
              height: 280, 
              child:  _courseData.isEmpty 
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
                : _BarChartWidget
                  (
                    data: _courseData.map((e) => ChartBarItem(label: e.label, count: e.count)).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectRow(SubjectDistributionItem s) 
  {
    final String label = s.count == 1 ? 'docente' : 'docenti';
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 12),
      child: Row
      (
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: 
        [
          Expanded
          (
            child: Text
            (
              s.name, 
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   14, 
                fontWeight: FontWeight.w500, 
                color:      const Color(0xFF64748B),
              ), 
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container
          (
            padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration
            (
              color:        const Color(0xFFE0F2FE), 
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text
            (
              '${s.count} $label', 
              style: GoogleFonts.plusJakartaSans
              (
                fontSize:   12, 
                fontWeight: FontWeight.w700, 
                color:      const Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSubjectsCard() 
  {
    if (_teacherStats == null) 
    {
      return const SizedBox();
    }

    //IsolateSelectionToCardBody
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
                  'Analisi Competenze', 
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   18, 
                    fontWeight: FontWeight.w700, 
                    color:      const Color(0xFF1E293B),
                  ),
                ),
                _FilterMenuWidget<String>
                (
                  hint:    'Classifica', 
                  value:   _teacherRankingMode, 
                  options: 
                  [
                    _FilterMenuOption(value: 'absolute', label: 'Per disciplina'),
                    _FilterMenuOption(value: 'program',  label: 'Per disciplina e percorso'),
                  ], 
                  onChanged: (v) 
                  { 
                    setState(() => _teacherRankingMode = v); 
                    _loadTeacherData(); 
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row
            (
              children: 
              [
                Expanded
                (
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      Text
                      (
                        'Media discipline per docente', 
                        style: GoogleFonts.plusJakartaSans
                        (
                          fontSize:   15, 
                          fontWeight: FontWeight.w600, 
                          color:      const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text
                      (
                        _teacherStats!.avgSubjectsPerTeacher.toStringAsFixed(1), 
                        style: GoogleFonts.plusJakartaSans
                        (
                          fontSize:   36, 
                          fontWeight: FontWeight.w800, 
                          color:      const Color(0xFF003C82),
                        ),
                      ),
                    ],
                  ),
                ),
                Container
                (
                  width:  1, 
                  height: 45, 
                  color:  const Color(0xFFE2E8F0), 
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded
                (
                  child: Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      Text
                      (
                        'Media docenti per disciplina', 
                        style: GoogleFonts.plusJakartaSans
                        (
                          fontSize:   15, 
                          fontWeight: FontWeight.w600, 
                          color:      const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text
                      (
                        _teacherStats!.avgTeachersPerSubject.toStringAsFixed(1), 
                        style: GoogleFonts.plusJakartaSans
                        (
                          fontSize:   36, 
                          fontWeight: FontWeight.w800, 
                          color:      const Color(0xFF003C82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFF1F5F9), thickness: 2),
            const SizedBox(height: 32),
            IntrinsicHeight
            (
              child: Row
              (
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: 
                [
                  Expanded
                  (
                    flex: 4,
                    child: Column
                    (
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: 
                      [
                        Text
                        (
                          '10 discipline più coperte', 
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   16, 
                            fontWeight: FontWeight.w600, 
                            color:      const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_teacherStats!.top10Subjects.isEmpty)
                          Text
                          (
                            'Nessun dato', 
                            style: GoogleFonts.plusJakartaSans
                            (
                              color:    const Color(0xFF94A3B8), 
                              fontSize: 14,
                            ),
                          )
                        else
                          ..._teacherStats!.top10Subjects.map((s) => _buildSubjectRow(s)),
                      ],
                    ),
                  ),
                  const Padding
                  (
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child:   VerticalDivider(color: Color(0xFFF1F5F9), thickness: 2),
                  ),
                  Expanded
                  (
                    flex: 4,
                    child: Column
                    (
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: 
                      [
                        Text
                        (
                          '10 discipline meno coperte', 
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   16, 
                            fontWeight: FontWeight.w600, 
                            color:      const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_teacherStats!.bottom10Subjects.isEmpty)
                          Text
                          (
                            'Nessun dato', 
                            style: GoogleFonts.plusJakartaSans
                            (
                              color:    const Color(0xFF94A3B8), 
                              fontSize: 14,
                            ),
                          )
                        else
                          ..._teacherStats!.bottom10Subjects.map((s) => _buildSubjectRow(s)),
                      ],
                    ),
                  ),
                  const Padding
                  (
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child:   VerticalDivider(color: Color(0xFFF1F5F9), thickness: 2),
                  ),
                  Expanded
                  (
                    flex: 5,
                    child: Column
                    (
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.start,
                      children: 
                      [
                        Text
                        (
                          'Distribuzione per area', 
                          style: GoogleFonts.plusJakartaSans
                          (
                            fontSize:   16, 
                            fontWeight: FontWeight.w600, 
                            color:      const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox
                        (
                          height: 320, 
                          child:  _teacherStats!.areaDistribution.isEmpty 
                            ? Center
                              (
                                child: Text
                                (
                                  'Nessun dato', 
                                  style: GoogleFonts.plusJakartaSans
                                  (
                                    color:    const Color(0xFF94A3B8), 
                                    fontSize: 14,
                                  ),
                                ),
                              ) 
                            : _PieChartWidget
                              (
                                data: _teacherStats!.areaDistribution.map((e) => ChartPieItem(label: _translateArea(e.area), count: e.count)).toList(),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      title:      'Iscritti', 
                      count:      _currentTotals?.currentTotalMembers ?? 0, 
                      deltaMonth: _currentTotals?.membersDeltaMonth ?? 0, 
                      deltaYear:  _currentTotals?.membersDeltaYear ?? 0, 
                      icon:       Icons.person_outline,
                      percentage: _currentTotals?.percentageOfTotalMembers,
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
                      percentage: _currentTotals?.percentageOfTotalCollaborators,
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
                      Expanded(child: _buildIscrittiRetentionCard()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildCollabRetentionCard(stackHeader: stackHeader)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_cityData.isNotEmpty || _ageData.isNotEmpty)
                Padding
                (
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      if (_cityData.isNotEmpty)
                        Expanded(child: _buildCityChartCard()),
                      if (_cityData.isNotEmpty && _ageData.isNotEmpty)
                        const SizedBox(width: 24),
                      if (_ageData.isNotEmpty)
                        Expanded(child: _buildAgeChartCard()),
                    ],
                  ),
                ),
              if (widget.roleKey == 'student')
                Padding
                (
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child:   _buildEducationChartCard(),
                ),
              if (widget.roleKey == 'course_participant')
                Padding
                (
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child:   _buildCourseChartCard(),
                ),
              if (widget.roleKey == 'teacher')
                Padding
                (
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child:   _buildTeacherSubjectsCard(),
                ),
              _buildTrendChartCard
              (
                title:               'Trend Iscritti', 
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
                }
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
                }
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
                              painter: _TriangleArrowPainter(color: const Color(0xFF1E293B)),
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

class _BarChartWidget extends StatefulWidget 
{
  final List<ChartBarItem> data;
  const _BarChartWidget({required this.data});
  @override
  State<_BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<_BarChartWidget> 
{
  Offset? _hoverPosition;
  int?    _hoveredIndex;
  Offset? _popupTargetPosition;
  int?    _cachedCountValue;
  String? _cachedLabelName;

  @override
  Widget build(BuildContext context) 
  {
    final rawMax     = widget.data.map((e) => e.count).reduce(math.max);
    final mathMax    = rawMax == 0 ? 4 : (rawMax * 1.2).ceil();
    final maxValue   = mathMax < 4 ? 4 : ((mathMax + 3) ~/ 4) * 4;
    final totalCount = widget.data.fold(0, (sum, item) => sum + item.count);

    return LayoutBuilder
    (
      builder: (context, constraints) 
      {
        const paddingBottom = 40.0;
        const paddingLeft   = 45.0;
        final minBarWidth   = 75.0;
        final innerWidth    = math.max(constraints.maxWidth - paddingLeft, widget.data.length * minBarWidth);
        final chartHeight   = constraints.maxHeight - paddingBottom;
        
        final barWidth = (innerWidth / widget.data.length) * 0.6;
        final stepX    = innerWidth / widget.data.length;
        final barRects = <Rect>[];

        for (int i = 0; i < widget.data.length; i++) 
        {
          final x    = (i * stepX) + (stepX / 2) - (barWidth / 2);
          final barH = (widget.data[i].count / maxValue) * chartHeight;
          barRects.add(Rect.fromLTWH(x, chartHeight - barH, barWidth, barH));
        }

        return Row
        (
          children: 
          [
            SizedBox
            (
              width: paddingLeft,
              child: CustomPaint
              (
                size:    Size(paddingLeft, constraints.maxHeight),
                painter: _YAxisPainter(maxValue: maxValue, paddingBottom: paddingBottom),
              ),
            ),
            Expanded
            (
              child: SingleChildScrollView
              (
                scrollDirection: Axis.horizontal,
                physics:         const BouncingScrollPhysics(),
                child: SizedBox
                (
                  width: innerWidth,
                  child: Stack
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
                            for (int i = 0; i < barRects.length; i++) 
                            {
                              if (barRects[i].contains(pos)) 
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
                                _popupTargetPosition = Offset(barRects[foundIndex].center.dx, barRects[foundIndex].top); 
                                _cachedCountValue    = widget.data[foundIndex].count; 
                                _cachedLabelName     = widget.data[foundIndex].label; 
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
                            painter: _BarChartPainter
                            (
                              data:          widget.data, 
                              maxValue:      maxValue, 
                              hoverPosition: _hoverPosition, 
                              barRects:      barRects,
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
                                          '${_cachedLabelName ?? ""}: ${_cachedCountValue ?? 0} (${((_cachedCountValue ?? 0) / totalCount * 100).toStringAsFixed(1)}%)', 
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
                                        painter: _TriangleArrowPainter(color: const Color(0xFF1E293B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _YAxisPainter extends CustomPainter 
{
  final int    maxValue;
  final double paddingBottom;

  _YAxisPainter
  ({
    required this.maxValue, 
    required this.paddingBottom,
  });

  @override
  void paint(Canvas canvas, Size size) 
  {
    final paintGrid   = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1..style = PaintingStyle.stroke;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final chartHeight = size.height - paddingBottom;

    for (int i = 0; i <= 4; i++) 
    {
      final y = chartHeight - (i * (chartHeight / 4));
      canvas.drawLine(Offset(size.width - 5, y), Offset(size.width, y), paintGrid);
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
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 12, y - 6));
    }
  }

  @override
  bool shouldRepaint(covariant _YAxisPainter oldDelegate) => oldDelegate.maxValue != maxValue;
}

class _BarChartPainter extends CustomPainter 
{
  final List<ChartBarItem> data;
  final int                maxValue;
  final Offset?            hoverPosition;
  final List<Rect>         barRects;

  _BarChartPainter
  ({
    required this.data, 
    required this.maxValue, 
    this.hoverPosition, 
    required this.barRects,
  });

  @override
  void paint(Canvas canvas, Size size) 
  {
    final paintGrid   = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1..style = PaintingStyle.stroke;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const paddingBottom = 40.0;
    final chartHeight   = size.height - paddingBottom;

    for (int i = 0; i <= 4; i++) 
    {
      final y = chartHeight - (i * (chartHeight / 4));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final barPaint = Paint()..color = const Color(0xFF0284C7)..style = PaintingStyle.fill;
    
    for (int i = 0; i < barRects.length; i++) 
    {
      canvas.drawRRect(RRect.fromRectAndRadius(barRects[i], const Radius.circular(6)), barPaint);

      textPainter.text = TextSpan
      (
        text:  data[i].label, 
        style: GoogleFonts.plusJakartaSans
        (
          color:      const Color(0xFF94A3B8), 
          fontSize:   13, 
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.textAlign = TextAlign.center;
      textPainter.maxLines  = 1;
      textPainter.ellipsis  = '...';
      textPainter.layout(maxWidth: size.width / data.length);
      textPainter.paint(canvas, Offset(barRects[i].center.dx - (textPainter.width / 2), chartHeight + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => oldDelegate.hoverPosition != hoverPosition || oldDelegate.data != data;
}

class _PieChartWidget extends StatefulWidget 
{
  final List<ChartPieItem> data;
  
  const _PieChartWidget({required this.data});
  
  @override
  State<_PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<_PieChartWidget> 
{
  Offset? _hoverPosition;
  int?    _hoveredIndex;
  Offset? _popupTargetPosition;
  String? _cachedLabel;
  int?    _cachedCount;
  double? _cachedPercentage;

  final List<Color> _colors = const 
  [
    Color(0xFF003C82), Color(0xFF0284C7), Color(0xFF38BDF8), 
    Color(0xFF818CF8), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)
  ];

  @override
  Widget build(BuildContext context) 
  {
    final total = widget.data.fold(0, (sum, item) => sum + item.count);

    return LayoutBuilder
    (
      builder: (context, constraints) 
      {
        final center = Offset(constraints.maxWidth * 0.35, constraints.maxHeight / 2);
        final radius = math.min(constraints.maxWidth * 0.6, constraints.maxHeight) / 2 - 20;

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
                  final dx = pos.dx - center.dx;
                  final dy = pos.dy - center.dy;
                  final dist = math.sqrt(dx * dx + dy * dy);

                  if (dist <= radius + 15 && dist >= radius - 35) 
                  {
                    final angle = math.atan2(dy, dx);
                    final normalizedAngle = angle < 0 ? angle + 2 * math.pi : angle;
                    
                    double startAngle = -math.pi / 2;
                    final gap = widget.data.length > 1 ? 0.04 : 0.0;
                    
                    for (int i = 0; i < widget.data.length; i++) 
                    {
                      final sweepAngle = (widget.data[i].count / total) * 2 * math.pi;
                      final startCheck = startAngle < 0 ? startAngle + 2 * math.pi : startAngle;
                      double endCheck  = startCheck + sweepAngle - gap;
                      
                      if (endCheck > 2 * math.pi) 
                      {
                        if (normalizedAngle >= startCheck || normalizedAngle <= endCheck - 2 * math.pi) 
                        {
                          foundIndex = i; 
                          break;
                        }
                      } 
                      else 
                      {
                        if (normalizedAngle >= startCheck && normalizedAngle <= endCheck) 
                        {
                          foundIndex = i; 
                          break;
                        }
                      }
                      startAngle += sweepAngle;
                    }
                  }
                  
                  setState(() 
                  { 
                    _hoverPosition = pos; 
                    _hoveredIndex  = foundIndex; 
                    if (foundIndex != null) 
                    { 
                      _popupTargetPosition = pos; 
                      _cachedLabel         = widget.data[foundIndex].label;
                      _cachedCount         = widget.data[foundIndex].count;
                      _cachedPercentage    = (_cachedCount! / total) * 100;
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
                  painter: _PieChartPainter
                  (
                    data:         widget.data, 
                    total:        total, 
                    colors:       _colors, 
                    center:       center, 
                    radius:       radius, 
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
              ),
            ),
            if (_popupTargetPosition != null)
              Positioned
              (
                left: _popupTargetPosition!.dx, 
                top:  _popupTargetPosition!.dy - 15,
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
                                '${_cachedLabel ?? ""}: ${_cachedCount ?? 0} (${_cachedPercentage?.toStringAsFixed(1) ?? "0"}%)', 
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
                              painter: _TriangleArrowPainter(color: const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned
            (
              right:  24, 
              top:    0, 
              bottom: 0,
              child: Center
              (
                child: Column
                (
                  mainAxisSize:       MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(widget.data.length, (i) 
                  {
                    final p = (widget.data[i].count / total) * 100;
                    return Padding
                    (
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row
                      (
                        children: 
                        [
                          Container
                          (
                            width:  14, 
                            height: 14, 
                            decoration: BoxDecoration
                            (
                              color: _colors[i % _colors.length], 
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text
                          (
                            '${widget.data[i].label} ', 
                            style: GoogleFonts.plusJakartaSans
                            (
                              fontSize:   14, 
                              fontWeight: FontWeight.w600, 
                              color:      const Color(0xFF1E293B),
                            ),
                          ),
                          Text
                          (
                            '(${p.toStringAsFixed(1)}%)', 
                            style: GoogleFonts.plusJakartaSans
                            (
                              fontSize:   14, 
                              fontWeight: FontWeight.w500, 
                              color:      const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            )
          ],
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter 
{
  final List<ChartPieItem> data;
  final int                total;
  final List<Color>        colors;
  final Offset             center;
  final double             radius;
  final int?               hoveredIndex;

  _PieChartPainter
  ({
    required this.data, 
    required this.total, 
    required this.colors, 
    required this.center, 
    required this.radius, 
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) 
  {
    if (data.isEmpty) 
    {
      return;
    }
    
    double startAngle = -math.pi / 2;
    for (int i = 0; i < data.length; i++) 
    {
      final sweepAngle = (data[i].count / total) * 2 * math.pi;
      final gap = data.length > 1 ? 0.04 : 0.0;
      
      final paint = Paint()
        ..color       = colors[i % colors.length]
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 30.0
        ..strokeCap   = StrokeCap.butt;
        
      canvas.drawArc
      (
        Rect.fromCircle(center: center, radius: radius), 
        startAngle + gap / 2, 
        math.max(0, sweepAngle - gap), 
        false, 
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => oldDelegate.hoveredIndex != hoveredIndex || oldDelegate.data != data;
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
    final paintLine = Paint()
      ..color       = const Color(0xFF003C82)
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;
      
    final paintGrid = Paint()
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

      textPainter.text = TextSpan
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
        ..style = PaintingStyle.fill,
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

class _TriangleArrowPainter extends CustomPainter 
{
  final Color color;

  _TriangleArrowPainter({required this.color});

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
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterMenuOption<T> 
{ 
  final T      value; 
  final String label; 

  _FilterMenuOption
  ({
    required this.value, 
    required this.label,
  }); 
}

class _FilterMenuWidget<T> extends StatefulWidget 
{ 
  final String                     hint; 
  final T                          value; 
  final List<_FilterMenuOption<T>> options; 
  final ValueChanged<T>            onChanged; 
  
  const _FilterMenuWidget
  ({
    required this.hint, 
    required this.value, 
    required this.options, 
    required this.onChanged,
  }); 

  @override 
  State<_FilterMenuWidget<T>> createState() => _FilterMenuWidgetState<T>(); 
}

class _FilterMenuWidgetState<T> extends State<_FilterMenuWidget<T>> 
{ 
  final GlobalKey                     _buttonKey = GlobalKey(); 
  OverlayEntry?                       _overlayEntry; 
  final GlobalKey<_OverlayContentState> _menuKey   = GlobalKey(); 
  bool                                _isHovered = false; 
  bool                                _isMenuOpen = false; 
  
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
            child: _OverlayContent<T>
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
      orElse: () => _FilterMenuOption(value: widget.value, label: ''),
    ); 

    return MouseRegion
    (
      cursor: SystemMouseCursors.click, 
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit:  (_) => setState(() => _isHovered = false), 
      child: GestureDetector
      (
        onTap: _toggleMenu, 
        child: AnimatedContainer
        (
          key:      _buttonKey, 
          duration: const Duration(milliseconds: 200), 
          height:   42, 
          padding:  const EdgeInsets.symmetric(horizontal: 16), 
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

class _OverlayContent<T> extends StatefulWidget 
{ 
  final T                        currentValue; 
  final List<_FilterMenuOption<T>> options; 
  final ValueChanged<T>          onSelected; 

  const _OverlayContent
  ({
    super.key, 
    required this.currentValue, 
    required this.options, 
    required this.onSelected,
  }); 

  @override 
  State<_OverlayContent<T>> createState() => _OverlayContentState<T>(); 
}

class _OverlayContentState<T> extends State<_OverlayContent<T>> 
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
                      children: widget.options.map((option) 
                      { 
                        return _ItemWidget
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

class _ItemWidget extends StatefulWidget 
{ 
  final String       text; 
  final bool         isSelected; 
  final VoidCallback onTap; 
  
  const _ItemWidget
  ({
    required this.text, 
    required this.isSelected, 
    required this.onTap,
  }); 

  @override 
  State<_ItemWidget> createState() => _ItemWidgetState(); 
}

class _ItemWidgetState extends State<_ItemWidget> 
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

class AntiquityHelper
{
  static List<AgeDistributionItem> sortAgeGroups(List<AgeDistributionItem> rawList)
  {
    final Map<String, int> order = 
    { 
      "< 11":  1, 
      "11-14": 2, 
      "15-18": 3, 
      "19-25": 4, 
      "26-35": 5, 
      "36-50": 6, 
      "> 50":  7, 
    };
    rawList.sort((a, b) => (order[a.ageGroup] ?? 99).compareTo(order[b.ageGroup] ?? 99));
    return rawList;
  }
}