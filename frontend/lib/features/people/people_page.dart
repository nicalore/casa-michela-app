import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'tabs/people_search_tab.dart';
import 'tabs/statistics/general_statistics_tab.dart';
import 'tabs/statistics/role_specific_statistics_view.dart';

// Order matches the IndexedStack below.
const List<RailGroup> _sections = [
  RailGroup(entries: ['Ricerca']),
  RailGroup(
    title: 'Statistiche',
    entries: [
      'Generali',
      'Amministratori',
      'Psicologi',
      'Docenti',
      'Studenti',
      'Corsisti',
    ],
  ),
];

const List<Widget> _sectionContents = [
  PeopleSearchTab(),
  GeneralStatisticsTab(),
  RoleSpecificStatisticsView(roleKey: 'administrator'),
  RoleSpecificStatisticsView(roleKey: 'psychologist'),
  RoleSpecificStatisticsView(roleKey: 'teacher'),
  RoleSpecificStatisticsView(roleKey: 'student'),
  RoleSpecificStatisticsView(roleKey: 'course_participant'),
];

class PeoplePage extends StatefulWidget
{
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> with SectionVisits
{
  int _selectedSection = 0;

  // Held here: in dispose the context can no longer be asked for it.
  GoRouter? _router;

  @override
  void initState()
  {
    super.initState();
    visitedSections.add(_selectedSection);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
  }

  // Clears the tab's static state at end of session: it must not survive into
  // the next login.
  @override
  void dispose()
  {
    // Read off the configuration: GoRouter.state throws when no route is left.
    final destination = _router?.routerDelegate.currentConfiguration.uri.path ?? '';

    if (!destination.startsWith('/people'))
    {
      PeopleSearchTab.clearSavedState();
    }

    super.dispose();
  }

  Widget _buildSectionContent()
  {
    return PageSections(
      index: _selectedSection,
      children: [
        for (var index = 0; index < _sectionContents.length; index++)
          if (visitedSections.contains(index)) _sectionContents[index] else const SizedBox.shrink(),
      ],
    );
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final size = AppBreakpoints.fromWidth(width);
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
                  animated: true,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                  animated: true,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    // The top inset clears the bar floating above the page.
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
                                title: 'Persone',
                                groups: _sections,
                                selectedIndex: _selectedSection,
                                onSelected: _selectSection,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSectionRail.gap),
                        ],
                        Expanded(
                          child: size.isCompact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    PageTransitionItem(
                                      slot: PageTransitionItem.frame,
                                      child: AppSectionHeading(
                                        module: 'Persone',
                                        section: railEntryAt(_sections, _selectedSection),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Expanded(child: _buildSectionContent()),
                                  ],
                                )
                              : _buildSectionContent(),
                        ),
                      ],
                    ),
                  ),
                ),
                AppTopBar(
                  currentRoute: '/people',
                  sectionTitle: 'Persone',
                  sectionGroups: _sections,
                  selectedSection: _selectedSection,
                  onSectionSelected: _selectSection,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
