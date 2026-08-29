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

  // The profile half last opened, kept apart from _selectedSection so it does
  // not swap back while the profile is leaving.
  int _profileSection = _personalProfileIndex;

  @override
  void initState()
  {
    super.initState();
    visitedSections.add(_selectedSection);
  }

  // The two profile entries share one tab: four rail entries, three children.
  bool get _showingProfile => _selectedSection <= _associationProfileIndex;

  bool get _profileVisited =>
      visitedSections.contains(_personalProfileIndex) ||
      visitedSections.contains(_associationProfileIndex);

  int get _stackIndex => _showingProfile ? 0 : _selectedSection - 1;

  void _selectSection(int index)
  {
    openSection(index, ()
    {
      _selectedSection = index;

      if (index <= _associationProfileIndex)
      {
        _profileSection = index;
      }
    });
  }

  // Not one transition element: each section times its own cards.
  Widget _buildSectionContent()
  {
    return PageSections(
      index: _stackIndex,
      children: [
        _profileVisited
            ? ProfileTab(
                section: _profileSection == _associationProfileIndex
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
    );
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
                    // Top inset clears the bar, which floats over the content.
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
                                title: 'Impostazioni',
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
                                        module: 'Impostazioni',
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
