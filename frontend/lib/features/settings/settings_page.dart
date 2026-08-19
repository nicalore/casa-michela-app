import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'tabs/account_tab.dart';
import 'tabs/info_tab.dart';
import 'tabs/profile_tab.dart';

const List<RailGroup> _sections = [
  RailGroup(
    title: 'Profilo',
    entries: ['Informazioni personali', 'Informazioni associative'],
  ),
  RailGroup(entries: ['Account', 'Informazioni']),
];

const int _personalProfileIndex = 0;
const int _associationProfileIndex = 1;
const int _accountIndex = 2;
const int _infoIndex = 3;

class SettingsPage extends StatefulWidget
{
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SectionVisits
{
  int _selectedSection = _personalProfileIndex;

  @override
  void initState()
  {
    super.initState();
    visitedSections.add(_selectedSection);
  }

  // The two profile sections are one tab showing one half or the other, so the
  // rail's four entries stand over three children. Keeping them a single tab is
  // what makes the profile load once instead of once per half.
  bool get _showingProfile => _selectedSection <= _associationProfileIndex;

  bool get _profileVisited =>
      visitedSections.contains(_personalProfileIndex) ||
      visitedSections.contains(_associationProfileIndex);

  int get _stackIndex => _showingProfile ? 0 : _selectedSection - 1;

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
                    // Aligned to the top rather than stretched, unlike the other
                    // module pages: this page has no fixed height, it is as tall
                    // as its content, and stretching a row inside an unbounded
                    // height has nothing to stretch to.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The rail steps aside below the breakpoint; the drawer
                        // behind the bar is holding these same sections.
                        if (size.hasRail) ...[
                          // First out and first back in on a change of page: the
                          // rail is what frames the content beside it.
                          PageTransitionItem(
                            slot: PageTransitionItem.frame,
                            child: AppSectionRail(
                              title: 'Impostazioni',
                              groups: _sections,
                              selectedIndex: _selectedSection,
                              onSelected: _selectSection,
                            ),
                          ),
                          const SizedBox(width: AppSectionRail.gap),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // What the rail was saying about where you are has
                              // to keep being said.
                              if (size.isCompact) ...[
                                PageTransitionItem(
                                  slot: PageTransitionItem.frame,
                                  child: AppSectionHeading(
                                    module: 'Impostazioni',
                                    section: railEntryAt(_sections, _selectedSection),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              // Nothing wrapped out here: each of the three
                              // sections times its own cards, one under the
                              // next, the way a list page times its own.
                              // Wrapped as one element from this side, a section
                              // would leave in a single slab.
                              PageSections(
                                index: _stackIndex,
                                children: [
                                  _profileVisited
                                      ? ProfileTab(
                                          section: _selectedSection == _associationProfileIndex
                                              ? ProfileSection.association
                                              : ProfileSection.personal,
                                        )
                                      : const SizedBox.shrink(),
                                  visitedSections.contains(_accountIndex)
                                      ? const AccountTab()
                                      : const SizedBox.shrink(),
                                  visitedSections.contains(_infoIndex)
                                      ? const InfoTab()
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Last in the stack, so the bar and the menu it opens stay above
                // the page.
                AppTopBar(
                  currentRoute: '/settings',
                  sectionTitle: 'Impostazioni',
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
