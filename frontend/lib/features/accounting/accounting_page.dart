import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_section_tabs.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'models/opening_items.dart';
import 'tabs/accounting_stats_tab.dart';
import 'tabs/opening_tab.dart';
import 'tabs/payments_month_tab.dart';
import 'tabs/student_hours_tab.dart';
import 'tabs/student_month_tab.dart';
import 'tabs/teacher_hours_tab.dart';
import 'tabs/teacher_month_tab.dart';
import 'tabs/to_settle_tab.dart';
import 'utils/accounting_jump.dart';
import 'utils/accounting_strings.dart';
import 'utils/opening_strings.dart';

const String kAccountingRoute = '/accounting';

// Entries counted across the groups.
const int _dailyTeachers = 0;
const int _dailyStudents = 1;
const int _monthlyTeachers = 2;
const int _monthlyStudents = 3;
const int _monthlyPayments = 4;
const int _toSettle = 5;
const int _statistics = 6;
const int _openingTeachers = 7;
const int _openingPupils = 8;

// Rail order of the summaries; the initial set-up comes first while it is open.
const List<int> _summaries = [
  _dailyTeachers,
  _dailyStudents,
  _monthlyTeachers,
  _monthlyStudents,
  _monthlyPayments,
  _toSettle,
  _statistics,
];

List<RailGroup> get _sections => [
  RailGroup(
    title: kDailySummaryGroup,
    entries: [kTeachersEntry, kStudentsEntry],
  ),
  RailGroup(
    title: kMonthlySummaryGroup,
    entries: [kTeachersEntry, kStudentsEntry, kPaymentsEntry],
  ),
  RailGroup(entries: [kToSettleEntry, kStatisticsEntry]),
];

class AccountingPage extends StatefulWidget
{
  const AccountingPage({super.key});

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> with SectionVisits
{
  // Kept while the app runs: back from a teacher's pay, the same summary shows.
  static int _shownSection = _dailyTeachers;

  // Kept too, so the rail does not wait for it the next time.
  static AccountingOpening? _knownOpening;

  int _selectedSection = _shownSection;

  AccountingOpening? _opening = _knownOpening;

  bool get _openingShown
  {
    final AccountingOpening? opening = _opening;

    return opening != null && !opening.closed;
  }

  List<int> get _order => [if (_openingShown) ...[_openingTeachers, _openingPupils], ..._summaries];

  List<RailGroup> get _groups
  {
    final AccountingOpening? opening = _opening;

    return [
      if (opening != null && _openingShown)
        RailGroup(
          title: kOpeningGroup,
          entries: [kTeachersEntry, kStudentsEntry],
          trailing: {
            kTeachersEntry: _LeftBadge(opening.teachersLeft),
            kStudentsEntry: _LeftBadge(opening.pupilsLeft),
          },
        ),
      ..._sections,
    ];
  }

  @override
  void initState()
  {
    super.initState();

    if (AccountingJumps.teacherHours.isPending)
    {
      _selectedSection = _shownSection = _dailyTeachers;
    }

    if (!_order.contains(_selectedSection))
    {
      _selectedSection = _shownSection = _dailyTeachers;
    }

    visitedSections.add(_selectedSection);
    AccountingJumps.teacherHours.asked.addListener(_jump);
    AccountingJumps.studentHours.asked.addListener(_jumpToStudents);
    unawaited(_loadOpening());
  }

  Future<void> _loadOpening() async
  {
    try
    {
      _openingChanged(await ApiService().getAccountingOpening());
    }
    on DioException catch (error)
    {
      // No set-up on this server: the rail stays as it is.
      if (error.response?.statusCode == 404)
      {
        _openingChanged(null);
      }
    }
    catch (_)
    {
      // Shown as known; the next visit asks again.
    }
  }

  void _openingChanged(AccountingOpening? opening)
  {
    if (!mounted)
    {
      return;
    }

    _knownOpening = opening;

    setState(()
    {
      _opening = opening;

      if (!_order.contains(_selectedSection))
      {
        _selectedSection = _shownSection = _dailyTeachers;
        visitedSections.add(_selectedSection);
      }
    });
  }

  @override
  void dispose()
  {
    AccountingJumps.teacherHours.asked.removeListener(_jump);
    AccountingJumps.studentHours.asked.removeListener(_jumpToStudents);
    super.dispose();
  }

  // A band asked for, from a teacher's pay or the monthly summary: the daily summary takes it.
  void _jump()
  {
    if (mounted && _selectedSection != _dailyTeachers)
    {
      _select(_dailyTeachers);
    }
  }

  // The same for the pupils, from their monthly summary.
  void _jumpToStudents()
  {
    if (mounted && _selectedSection != _dailyStudents)
    {
      _select(_dailyStudents);
    }
  }

  void _select(int index)
  {
    _shownSection = index;
    openSection(index, () => _selectedSection = index);
  }

  // Visited summaries stay mounted; the one coming in runs in as on the other pages.
  Widget _buildSectionContent()
  {
    return PageSections(
      index: _selectedSection,
      children: [
        visitedSections.contains(_dailyTeachers)
            ? TeacherHoursTab(shown: _selectedSection == _dailyTeachers)
            : const SizedBox.shrink(),
        visitedSections.contains(_dailyStudents)
            ? StudentHoursTab(shown: _selectedSection == _dailyStudents)
            : const SizedBox.shrink(),
        visitedSections.contains(_monthlyTeachers)
            ? TeacherMonthTab(shown: _selectedSection == _monthlyTeachers)
            : const SizedBox.shrink(),
        visitedSections.contains(_monthlyStudents)
            ? StudentMonthTab(shown: _selectedSection == _monthlyStudents)
            : const SizedBox.shrink(),
        visitedSections.contains(_monthlyPayments)
            ? PaymentsMonthTab(shown: _selectedSection == _monthlyPayments)
            : const SizedBox.shrink(),
        visitedSections.contains(_toSettle)
            ? ToSettleTab(shown: _selectedSection == _toSettle)
            : const SizedBox.shrink(),
        visitedSections.contains(_statistics)
            ? AccountingStatsTab(shown: _selectedSection == _statistics)
            : const SizedBox.shrink(),
        _openingSection(OpeningSide.teachers, _openingTeachers),
        _openingSection(OpeningSide.pupils, _openingPupils),
      ],
    );
  }

  Widget _openingSection(OpeningSide side, int index)
  {
    final AccountingOpening? opening = _opening;

    if (opening == null || !visitedSections.contains(index))
    {
      return const SizedBox.shrink();
    }

    return OpeningTab(side: side, opening: opening, onChanged: _openingChanged);
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        // Below the wide window the page is the window: its sections scroll, not the page.
        minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final size = AppBreakpoints.of(context);
          final margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.pagePaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (size.hasRail) ...[
                          Align(
                            alignment: Alignment.topLeft,
                            child: PageTransitionItem(
                              slot: PageTransitionItem.frame,
                              child: AppSectionRail(
                                title: kAccountingTitle,
                                groups: _groups,
                                selectedIndex: _order.indexOf(_selectedSection),
                                onSelected: (position) => _select(_order[position]),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSectionRail.gap),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!size.hasRail) ...[
                                PageTransitionItem(
                                  slot: PageTransitionItem.frame,
                                  child: AppSectionTabs(
                                    title: kAccountingTitle,
                                    groups: _groups,
                                    selectedIndex: _order.indexOf(_selectedSection),
                                    onSelected: (position) => _select(_order[position]),
                                  ),
                                ),
                                const SizedBox(height: kSectionTabsGap),
                              ],
                              Expanded(key: const ValueKey('accounting-sections'), child: _buildSectionContent()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Last in the stack so the bar and its menu stay above the page.
                const AppTopBar(currentRoute: kAccountingRoute),
              ],
            ),
          );
        },
      ),
    );
  }
}

// How many are left beside a set-up entry; a tick once they are all confirmed.
class _LeftBadge extends StatelessWidget
{
  final int left;

  const _LeftBadge(this.left);

  @override
  Widget build(BuildContext context)
  {
    if (left == 0)
    {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: AppTheme.paidSurface, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 16, color: AppTheme.trialTealDeepText),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '$left',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppTheme.modifiedAccent,
        ),
      ),
    );
  }
}
