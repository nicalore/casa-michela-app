import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'association_strings.dart';
import 'tabs/opening_hours/combined_hours_view.dart';
import 'tabs/pupil_subjects_tab.dart';
import 'tabs/pupil_teachers_tab.dart';

const String _teacherRole = 'TEACHER';
const String _parentRole = 'PARENT';

const int _hoursIndex = 0;
const int _subjectsIndex = 1;
const int _teachersIndex = 2;

const String _hours = kAssociationHoursLabel;
const String _meetings = 'Colloqui';
const String _notices = kAssociationNoticesLabel;

// Order matches the PageSections below; the constants above index both.
List<RailGroup> _sectionsFor(String role)
{
  return [
    if (role == _teacherRole)
      const RailGroup(entries: [_hours, _notices], unavailable: {_notices})
    else
      RailGroup(
        entries: [_hours, 'Discipline', 'Docenti', if (role == _parentRole) _meetings, _notices],
        unavailable: const {_meetings, _notices},
      ),
  ];
}

// A parent always; a pupil only when no parent answers for them.
bool _canSpeak(String role)
{
  final bool answeredFor = ApiService().lastKnownIdentity?.hasParentalResponsibility ?? false;

  return role == _parentRole || !answeredFor;
}

class RoleAssociationPage extends StatefulWidget
{
  final String role;

  const RoleAssociationPage({super.key, required this.role});

  @override
  State<RoleAssociationPage> createState() => _RoleAssociationPageState();
}

class _RoleAssociationPageState extends State<RoleAssociationPage> with SectionVisits
{
  int _selectedSection = _hoursIndex;

  late final List<RailGroup> _sections = _sectionsFor(widget.role);

  @override
  void initState()
  {
    super.initState();
    visitedSections.add(_selectedSection);
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);
  }

  // Visited sections stay mounted so each keeps its week and its fetches.
  Widget _buildSectionContent()
  {
    return PageSections(
      index: _selectedSection,
      children: [
        visitedSections.contains(_hoursIndex) ? const CombinedHoursView() : const SizedBox.shrink(),
        if (widget.role != _teacherRole) ...[
          visitedSections.contains(_subjectsIndex)
              ? PupilSubjectsTab(canReport: _canSpeak(widget.role))
              : const SizedBox.shrink(),
          visitedSections.contains(_teachersIndex)
              ? PupilTeachersTab(role: widget.role, canReport: _canSpeak(widget.role))
              : const SizedBox.shrink(),
        ],
        // Not built yet: named on the rail, never opened.
        if (widget.role == _parentRole) const SizedBox.shrink(),
        const SizedBox.shrink(),
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
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    // Top inset clears the bar overlaid on the content.
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
                                title: 'Associazione',
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
                                        module: 'Associazione',
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
                // Last in the stack so the bar and its menu stay above the page.
                AppTopBar(
                  currentRoute: '${homeForRole(widget.role)}/association',
                  sectionTitle: 'Associazione',
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
