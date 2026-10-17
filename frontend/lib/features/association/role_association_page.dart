import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../routing/app_router.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/page_transition.dart';
import '../notifications/notice_jump.dart';
import '../notifications/week_jump.dart';
import '../../shared/widgets/page_watermark.dart';
import 'association_strings.dart';
import 'association_tour.dart';
import 'notices/notices_tab.dart';
import 'tabs/opening_hours/combined_hours_view.dart';
import 'tabs/pupil_subjects_tab.dart';
import 'tabs/pupil_teachers_tab.dart';
import 'teacher_opinions.dart';

const String _teacherRole = 'TEACHER';
const String _parentRole = 'PARENT';

const int _hoursIndex = 0;
const int _subjectsIndex = 1;
const int _teachersIndex = 2;

// Last on every rail: after the hours alone for teachers, after the meetings for parents.
int _noticesIndexFor(String role) => switch (role)
{
  _teacherRole => 1,
  _parentRole => 4,
  _ => 3,
};

const String _hours = kAssociationHoursLabel;
const String _meetings = kAssociationMeetingsLabel;
const String _notices = kAssociationNoticesLabel;

// Order matches the PageSections below; the constants above index both.
List<RailGroup> _sectionsFor(String role)
{
  return [
    if (role == _teacherRole)
      const RailGroup(entries: [_hours, _notices])
    else
      RailGroup(
        entries: [
          _hours,
          kAssociationSubjectsLabel,
          kAssociationTeachersLabel,
          if (role == _parentRole) _meetings,
          _notices,
        ],
        unavailable: const {_meetings},
      ),
  ];
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

  late final int _noticesIndex = _noticesIndexFor(widget.role);

  @override
  void initState()
  {
    super.initState();

    // Opened from a notification: on the notices, whose tab opens the one it announced.
    if (NoticeJumps.reading.isPending)
    {
      _selectedSection = _noticesIndex;
    }

    visitedSections.add(_selectedSection);
    associationNoticesShown.value = _selectedSection == _noticesIndex;
    associationSection.value = _sectionName(_selectedSection);
    WeekJumps.hours.asked.addListener(_showHours);
    NoticeJumps.reading.asked.addListener(_showNotices);
  }

  @override
  void dispose()
  {
    WeekJumps.hours.asked.removeListener(_showHours);
    NoticeJumps.reading.asked.removeListener(_showNotices);
    super.dispose();
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);

    // Told after the frame: a tour waiting for it redraws itself, which a build in progress forbids.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        associationNoticesShown.value = _selectedSection == _noticesIndex;
        associationSection.value = _sectionName(_selectedSection);
      }
    });
  }

  // The section by name, as the tour waits for it.
  String? _sectionName(int index)
  {
    if (index == _noticesIndex)
    {
      return 'notices';
    }

    return switch (index)
    {
      _hoursIndex => 'hours',
      _subjectsIndex when widget.role != _teacherRole => 'subjects',
      _teachersIndex when widget.role != _teacherRole => 'teachers',
      _ => null,
    };
  }

  // Turns the page to a section by name, when the tour steps back.
  void _show(String name)
  {
    final int index = switch (name)
    {
      'subjects' => _subjectsIndex,
      'teachers' => _teachersIndex,
      'notices' => _noticesIndex,
      _ => _hoursIndex,
    };

    _selectSection(index);
  }

  void _showHours() => _selectSection(_hoursIndex);

  void _showNotices() => _selectSection(_noticesIndex);

  // One tour for the hours and the notices, begun on the hours; once seen, what shows only sometimes comes alone.
  Future<void> _startTours() async
  {
    await WidgetsBinding.instance.endOfFrame;

    // Whose opinions on the teachers the reader gives, by gender, as the Docenti steps word them.
    List<String?> opinions = const [];

    if (widget.role != _teacherRole && canSpeakFor(widget.role))
    {
      try
      {
        opinions = [for (final pupil in await readOpinionPupils(parent: widget.role == _parentRole)) pupil.gender];
      }
      catch (_) {}
    }

    final DesktopTour? main = associationTour(show: _show, opinions: opinions);

    if (!mounted || isDesktopTourShown || main == null)
    {
      return;
    }

    if (!await associationTourSeen(main))
    {
      if (!mounted)
      {
        return;
      }

      if (_selectedSection != _hoursIndex)
      {
        _showHours();
      }

      startAssociationTour(context, main);

      return;
    }

    final DesktopTour? late = await associationLateTour();

    if (late != null && mounted)
    {
      startAssociationTour(context, late);
    }
  }

  // Visited sections stay mounted so each keeps its week and its fetches.
  Widget _buildSectionContent()
  {
    return PageSections(
      index: _selectedSection,
      children: [
        visitedSections.contains(_hoursIndex) ? CombinedHoursView(onShown: _startTours, role: widget.role) : const SizedBox.shrink(),
        if (widget.role != _teacherRole) ...[
          visitedSections.contains(_subjectsIndex)
              ? const PupilSubjectsTab()
              : const SizedBox.shrink(),
          visitedSections.contains(_teachersIndex)
              ? PupilTeachersTab(role: widget.role, canReport: canSpeakFor(widget.role))
              : const SizedBox.shrink(),
        ],
        // Not built yet: named on the rail, never opened.
        if (widget.role == _parentRole) const SizedBox.shrink(),
        visitedSections.contains(_noticesIndex)
            ? NoticesTab(readerRole: widget.role, onShown: _startTours)
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
                                tours: {
                                  if (widget.role != _teacherRole) ...{
                                    _subjectsIndex: kTourAssociationToSubjects,
                                    _teachersIndex: kTourAssociationToTeachers,
                                  },
                                  _noticesIndex: kTourAssociationToNotices,
                                },
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
