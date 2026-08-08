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

// The order here is the order of the IndexedStack below: search first, then the
// statistics, which used to be a second row of chips inside their own tab.
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

// All six are const widgets, so declaring them here costs nothing: the
// expensive part is the State, which Flutter creates only for the entries the
// IndexedStack actually mounts.
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

class _PeoplePageState extends State<PeoplePage>
{
  int _selectedSection = 0;

  // Tracks which sections have been opened: once visited a section stays
  // mounted in the IndexedStack. Reset only when GoRouter destroys this page.
  final Set<int> _visitedSections = {};

  // Held from here on, because in dispose the context can no longer be asked
  // for it.
  GoRouter? _router;

  @override
  void initState()
  {
    super.initState();
    _visitedSections.add(_selectedSection);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
  }

  // Search text, sorting and filters are static in the tab, so they outlive it.
  //
  // This page is not taken down when you walk to another destination any more —
  // it is kept, and so is everything it was showing — so what is left here is
  // the end of the session: the page goes with the shell when the account does,
  // and what was being looked for must not be waiting for whoever logs in next.
  @override
  void dispose()
  {
    // Read off the configuration rather than off GoRouter.state, which throws
    // when there is no route left at all: on the way down with the whole app,
    // this asks the question at exactly that moment.
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
          if (_visitedSections.contains(index)) _sectionContents[index] else const SizedBox.shrink(),
      ],
    );
  }

  void _selectSection(int index)
  {
    setState(()
    {
      _selectedSection = index;
      _visitedSections.add(index);
    });
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
                // The same pair of glows the dashboard wears, on the same paper.
                // See the note in DashboardLayout for why they both fade towards
                // a blue.
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
                    // The top inset clears the bar floating above the page: it
                    // is laid over the content rather than in the column with
                    // it, so the room it needs has to be left here.
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 24,
                    ),
                    // Stretched, so the content keeps being handed the full
                    // height it was given when it sat in a column; the rail is
                    // pinned back to its own height inside that.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The rail steps aside below the breakpoint. Two hundred
                        // and seventy pixels of a phone cannot go to a column of
                        // section names, and the drawer behind the bar is
                        // already holding them.
                        if (size.hasRail) ...[
                          Align(
                            alignment: Alignment.topLeft,
                            // First out and first back in on a change of page:
                            // the rail is what frames the content beside it.
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
                              // What the rail was saying about where you are has
                              // to keep being said: the module quietly, over the
                              // section you are in.
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
                // Last in the stack, so the bar and the menu it opens stay above
                // the page.
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
