import 'package:flutter/material.dart';

import '../../../shared/widgets/pill_tab_bar.dart';
import 'statistics/general_statistics_tab.dart';
import 'statistics/role_specific_statistics_view.dart';

// Label and content of a sub tab declared together, so the navigation and the
// IndexedStack cannot drift out of step: before, they were two parallel lists
// matched by index.
class _StatisticsSection
{
  final String label;
  final Widget content;

  const _StatisticsSection(this.label, this.content);
}

// All six are const widgets, so declaring them here costs nothing: the expensive
// part is the State, which Flutter creates only for the entries the IndexedStack
// actually mounts.
const List<_StatisticsSection> _sections = [
  _StatisticsSection('Generali', GeneralStatisticsTab()),
  _StatisticsSection('Amministratori', RoleSpecificStatisticsView(roleKey: 'administrator')),
  _StatisticsSection('Psicologi', RoleSpecificStatisticsView(roleKey: 'psychologist')),
  _StatisticsSection('Docenti', RoleSpecificStatisticsView(roleKey: 'teacher')),
  _StatisticsSection('Studenti', RoleSpecificStatisticsView(roleKey: 'student')),
  _StatisticsSection('Corsisti', RoleSpecificStatisticsView(roleKey: 'course_participant')),
];

class PeopleStatisticsTab extends StatefulWidget
{
  const PeopleStatisticsTab({super.key});

  @override
  State<PeopleStatisticsTab> createState() => _PeopleStatisticsTabState();
}

class _PeopleStatisticsTabState extends State<PeopleStatisticsTab>
{
  int _selectedTab = 0;

  // Records which sub tabs have been opened: once visited a tab stays mounted in
  // the IndexedStack, so its data is not refetched on every switch. Reset only
  // when the parent destroys this tab.
  final Set<int> _visitedTabs = {0};

  void _selectTab(int index)
  {
    setState(()
    {
      _selectedTab = index;
      _visitedTabs.add(index);
    });
  }

  Widget _buildTabContent()
  {
    return IndexedStack(
      index: _selectedTab,
      children: [
        for (var index = 0; index < _sections.length; index++)
          if (_visitedTabs.contains(index)) _sections[index].content else const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PillTabBar(
          labels: [for (final section in _sections) section.label],
          selectedIndex: _selectedTab,
          onSelected: _selectTab,
        ),
        Expanded(child: _buildTabContent()),
      ],
    );
  }
}