import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';

import 'tabs/schools_tab.dart';
import 'tabs/study_programs_tab.dart';
import 'tabs/association_subjects_tab.dart';
import 'tabs/ministry_subjects_tab.dart';

class AssociationPage extends StatefulWidget 
{
  const AssociationPage({super.key});

  @override
  State<AssociationPage> createState() => _AssociationPageState();
}

class _AssociationPageState extends State<AssociationPage> 
{
  int _mainSelectedTab = 0;
  int _didatticaSelectedTab = 0;

  //TieneTracciaDiQualiTabSonoStatiAperti_UnaVoltaVisitatoRestaMontatoNellIndexedStack
  //VieneAzzeratoSoloQuandoAssociationPageVieneDistruttaDaGoRouter_UscendoDallaPagina
  final Set<int> _visitedTabs = {};

  final List<String> _mainTabs = ['Scuole', 'Didattica'];

  final List<String> _didatticaTabs = [
    'Discipline interne',
    'Materie ministeriali',
    'Percorsi di studio',
  ];

  @override
  void initState()
  {
    super.initState();
    _visitedTabs.add(_computeContentIndex());
  }

  //MappaLaCoppia(mainTab,didatticaTab)SuUnIndiceUnicoPerLIndexedStack
  //0=Scuole_1=DisciplineInterne_2=MaterieMinisteriali_3=PercorsiDiStudio
  int _computeContentIndex()
  {
    if (_mainSelectedTab == 0) return 0;
    return 1 + _didatticaSelectedTab;
  }

  //StacksToNewLineInsteadOfOverflowing_WasAPlainRowBeforeWithNoWrapAndNoScroll
  Widget _buildSubNavigation() 
  {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(_didatticaTabs.length, (index) 
        {
          final isSelected = _didatticaSelectedTab == index;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () 
              {
                setState(() 
                {
                  _didatticaSelectedTab = index;
                  _visitedTabs.add(_computeContentIndex());
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
                  child: Text(_didatticaTabs[index]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  //IndexedStack_TieneVivoLoStatoDeiTabGiaVisitati_IlPlaceholderVieneSostituitoSoloAllaPrimaVisita
  //DopoDiCheIlTabRestaMontatoENonSiRicaricaPiuFinoAllaChiusuraDellIntoraPagina
  Widget _buildTabContent() 
  {
    return IndexedStack(
      index: _computeContentIndex(),
      children: [
        _visitedTabs.contains(0) ? const SchoolsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(1) ? const AssociationSubjectsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(2) ? const MinistrySubjectsTab() : const SizedBox.shrink(),
        _visitedTabs.contains(3) ? const StudyProgramsTab() : const SizedBox.shrink(),
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
          final viewportWidth = MediaQuery.of(context).size.width;

          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF4F7F9),
            child: Stack(
              children: [
                Positioned(
                  right: -800,
                  top: -800,
                  child: IgnorePointer(
                    child: Container(
                      width: 1600,
                      height: 1600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -800,
                  bottom: -800,
                  child: IgnorePointer(
                    child: Container(
                      width: 1600,
                      height: 1600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                if (viewportWidth > 1024)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: 0.04,
                          child: Image.asset(
                            'assets/images/house_watermark.png',
                            width: 800,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(40),
                                splashFactory: NoSplash.splashFactory,
                                overlayColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                                onTap: () 
                                {
                                  context.go('/dashboard');
                                },
                                child: Container(
                                  width: 88,
                                  height: 54,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(40),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        offset: Offset(0, 4),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Color(0xFF003C82),
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(40),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    offset: Offset(0, 4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Associazione',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF003C82),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppCustomTabBar(
                          tabs: _mainTabs,
                          selectedIndex: _mainSelectedTab,
                          onTabSelected: (index) 
                          {
                            setState(() 
                            {
                              _mainSelectedTab = index;
                              _visitedTabs.add(_computeContentIndex());
                            });
                          },
                          maxWidth: viewportWidth - 80,
                        ),
                        _mainSelectedTab == 1
                            ? _buildSubNavigation()
                            : const SizedBox(height: 24, width: double.infinity),
                        Expanded(
                          child: _buildTabContent(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}