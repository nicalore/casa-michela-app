import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'statistics/administrators_statistics_tab.dart';
import 'statistics/course_participants_statistics_tab.dart';
import 'statistics/general_statistics_tab.dart';
import 'statistics/psychologists_statistics_tab.dart';
import 'statistics/students_statistics_tab.dart';
import 'statistics/teachers_statistics_tab.dart';

class PeopleStatisticsTab extends StatefulWidget 
{
  const PeopleStatisticsTab({super.key});

  @override
  State<PeopleStatisticsTab> createState() => _PeopleStatisticsTabState();
}

class _PeopleStatisticsTabState extends State<PeopleStatisticsTab> 
{
  int                _selectedTab = 0;
  final List<String> _tabs        = [
    'Generali',
    'Amministratori',
    'Psicologi',
    'Docenti',
    'Studenti',
    'Corsisti',
  ];

  //TieneTracciaDiQualiSottoTabSonoStatiAperti_UnaVoltaVisitatoRestaMontatoNellIndexedStack
  //VieneAzzeratoSoloQuandoPeopleStatisticsTabVieneDistruttoDalPadre_UscendoDaPersoneOTornandoSuRicerca
  final Set<int> _visitedTabs = {0};

  //StacksToNewLineInsteadOfScrollingOffScreenInvisibly_SameWrapNotShrinkPrinciple
  //UsedForTheChildrenAndParentsChipsElsewhereInTheApp
  Widget _buildSubNavigation() 
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Wrap(
        spacing:    12,
        runSpacing: 12,
        children: List.generate(_tabs.length, (index) 
        {
          final isSelected = _selectedTab == index;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () 
              {
                setState(() 
                {
                  _selectedTab = index;
                  _visitedTabs.add(index);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF003C82) : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF003C82)
                        : const Color(0xFFE2E8F0),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                  child: Text(_tabs[index]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() 
  {
    return IndexedStack(
      index: _selectedTab,
      children: [
        _visitedTabs.contains(0) ? const GeneralStatisticsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(1) ? const AdministratorsStatisticsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(2) ? const PsychologistsStatisticsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(3) ? const TeachersStatisticsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(4) ? const StudentsStatisticsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(5) ? const CourseParticipantsStatisticsTab() : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubNavigation(),
        Expanded(
          child: _buildTabContent(),
        ),
      ],
    );
  }
}