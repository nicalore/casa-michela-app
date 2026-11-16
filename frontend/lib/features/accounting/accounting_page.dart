import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_section_tabs.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'tabs/accounting_stats_tab.dart';
import 'tabs/payments_month_tab.dart';
import 'tabs/student_hours_tab.dart';
import 'tabs/student_month_tab.dart';
import 'tabs/teacher_hours_tab.dart';
import 'tabs/teacher_month_tab.dart';
import 'tabs/to_settle_tab.dart';
import 'utils/accounting_jump.dart';
import 'utils/accounting_strings.dart';

const String kAccountingRoute = '/accounting';

// Entries counted across the groups.
const int _dailyTeachers = 0;
const int _dailyStudents = 1;
const int _monthlyTeachers = 2;
const int _monthlyStudents = 3;
const int _monthlyPayments = 4;
const int _toSettle = 5;
const int _statistics = 6;

const List<RailGroup> _sections = [
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

  int _selectedSection = _shownSection;

  @override
  void initState()
  {
    super.initState();

    if (AccountingJumps.teacherHours.isPending)
    {
      _selectedSection = _shownSection = _dailyTeachers;
    }

    visitedSections.add(_selectedSection);
    AccountingJumps.teacherHours.asked.addListener(_jump);
    AccountingJumps.studentHours.asked.addListener(_jumpToStudents);
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
      ],
    );
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
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                const CornerGlow(
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
                                groups: _sections,
                                selectedIndex: _selectedSection,
                                onSelected: _select,
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
                                    groups: _sections,
                                    selectedIndex: _selectedSection,
                                    onSelected: _select,
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
