import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/snackbar.dart';
import '../../services/api_service.dart';

import 'models/school_item.dart';
import 'models/study_program_item.dart';
import 'models/ministry_subject_item.dart';
import 'models/association_subject_item.dart';

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
  final ApiService _apiService = ApiService();

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

  //FonteUnicaDiVeritaPerLeEntitaCondiviseTraITab_CaricataUnaSolaVoltaAllAperturaDellaPagina
  //RisolveIlDisallineamentoDeiTabCongelatiNellIndexedStack_OgniSetStateQuiPropagaAiFigliTramiteDidUpdateWidget
  bool _isLoading = true;
  List<SchoolItem> _schools = [];
  List<StudyProgramItem> _studyPrograms = [];
  List<MinistrySubjectItem> _ministrySubjects = [];
  List<AssociationSubjectItem> _associationSubjects = [];

  @override
  void initState()
  {
    super.initState();
    _visitedTabs.add(_computeContentIndex());
    _loadAllData();
  }

  Future<void> _loadAllData() async
  {
    try
    {
      final results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
        _apiService.getMinistrySubjects(),
        _apiService.getAssociationSubjects(),
      ]);

      if (mounted)
      {
        setState(()
        {
          _schools = results[0] as List<SchoolItem>;
          _studyPrograms = results[1] as List<StudyProgramItem>;
          _ministrySubjects = results[2] as List<MinistrySubjectItem>;
          _associationSubjects = results[3] as List<AssociationSubjectItem>;
          _isLoading = false;
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: 'Impossibile caricare i dati dal server.', isError: true);
      }
    }
  }

  // -----------------------------------------------------------------------
  // RifetchMiratoDelLivelloDipendente
  // -----------------------------------------------------------------------
  //OgniEntitaIncorporaUnaCopiaDenormalizzataDellEntitaSottostante(EsMinistrySubjectItem.associationSubjects)
  //RicevutaDalBackendAlMomentoDelFetch_QuestaCopiaNonVieneAggiornataDaUnaModificaOEliminazioneASeStante
  //QuindiDopoUnEditODeleteRifacciamoIlFetchDelLivelloSuperioreCosiLaCopiaAnnidataTornaFresca

  Future<void> _refreshMinistrySubjects() async
  {
    try
    {
      final refreshed = await _apiService.getMinistrySubjects();
      if (mounted) setState(() { _ministrySubjects = refreshed; });
    }
    catch (e)
    {
      //LOperazionePrimariaEGiaAndataABuonFine_NonBlocchiamoLUtentePerUnFallimentoDelSoloRefresh
    }
  }

  Future<void> _refreshStudyPrograms() async
  {
    try
    {
      final refreshed = await _apiService.getStudyPrograms();
      if (mounted) setState(() { _studyPrograms = refreshed; });
    }
    catch (e)
    {
      //LOperazionePrimariaEGiaAndataABuonFine_NonBlocchiamoLUtentePerUnFallimentoDelSoloRefresh
    }
  }

  Future<void> _refreshSchools() async
  {
    try
    {
      final refreshed = await _apiService.getSchools();
      if (mounted) setState(() { _schools = refreshed; });
    }
    catch (e)
    {
      //LOperazionePrimariaEGiaAndataABuonFine_NonBlocchiamoLUtentePerUnFallimentoDelSoloRefresh
    }
  }

  // -----------------------------------------------------------------------
  // DisciplineInterne (AssociationSubject)
  // -----------------------------------------------------------------------

  Future<bool> _executeCreateAssociationSubject(String name, String area, String description, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createAssociationSubject(name, area, description);
      setState(() { _associationSubjects = [..._associationSubjects, created]; });
      if (mounted) CustomSnackBar.show(context: context, message: 'Disciplina interna creata con successo!', isError: false);
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> _executeEditAssociationSubject(int id, String name, String area, String description, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateAssociationSubject(id, name, area, description);
      setState(() { _associationSubjects = _associationSubjects.map((s) => s.id == id ? updated : s).toList(); });
      //SnackBarDiSuccessoAggiuntoAncheSuModifica_PrimaCEraSoloSuCreazione
      if (mounted) CustomSnackBar.show(context: context, message: 'Disciplina interna modificata con successo!', isError: false);
      //InvalidaLaCopiaAnnidataDentroOgniMinistrySubjectItem_AltrimentiRestaConIlNomeVecchio
      await _refreshMinistrySubjects();
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void _executeDeleteAssociationSubject(AssociationSubjectItem item) async
  {
    try
    {
      await _apiService.deleteAssociationSubject(item.id);
      setState(() { _associationSubjects = _associationSubjects.where((s) => s.id != item.id).toList(); });
      //SnackBarDiSuccessoAggiuntoAncheSuCancellazione_PrimaCEraSoloLerroreInCatch
      if (mounted) CustomSnackBar.show(context: context, message: 'Disciplina interna eliminata con successo!', isError: false);
      //InvalidaLaCopiaAnnidataDentroOgniMinistrySubjectItem_AltrimentiContinuaAComparireComeAssociata
      await _refreshMinistrySubjects();
    }
    catch (e)
    {
      if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  // -----------------------------------------------------------------------
  // MaterieMinisteriali (MinistrySubject)
  // -----------------------------------------------------------------------

  Future<bool> _executeCreateMinistrySubject(String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createMinistrySubject(name: name, level: level, areas: areas, description: description, associationSubjectIds: associationIds);
      setState(() { _ministrySubjects = [..._ministrySubjects, created]; });
      if (mounted) CustomSnackBar.show(context: context, message: 'Materia ministeriale creata con successo!', isError: false);
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> _executeEditMinistrySubject(int id, String name, String level, List<String> areas, String description, List<int> associationIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateMinistrySubject(id: id, name: name, level: level, areas: areas, description: description, associationSubjectIds: associationIds);
      setState(() { _ministrySubjects = _ministrySubjects.map((s) => s.id == id ? updated : s).toList(); });
      //SnackBarDiSuccessoAggiuntoAncheSuModifica_PrimaCEraSoloSuCreazione
      if (mounted) CustomSnackBar.show(context: context, message: 'Materia ministeriale modificata con successo!', isError: false);
      //InvalidaLaCopiaAnnidataDentroOgniStudyProgramItem_AltrimentiRestaConIlNomeVecchio
      await _refreshStudyPrograms();
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void _executeDeleteMinistrySubject(MinistrySubjectItem item) async
  {
    try
    {
      await _apiService.deleteMinistrySubject(item.id);
      setState(() { _ministrySubjects = _ministrySubjects.where((s) => s.id != item.id).toList(); });
      //SnackBarDiSuccessoAggiuntoAncheSuCancellazione_PrimaCEraSoloLerroreInCatch
      if (mounted) CustomSnackBar.show(context: context, message: 'Materia ministeriale eliminata con successo!', isError: false);
      //InvalidaLaCopiaAnnidataDentroOgniStudyProgramItem_AltrimentiContinuaAComparireComeAssociata
      await _refreshStudyPrograms();
    }
    catch (e)
    {
      if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  // -----------------------------------------------------------------------
  // PercorsiDiStudio (StudyProgram)
  // -----------------------------------------------------------------------

  Future<bool> _executeCreateStudyProgram(String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) async
  {
    try
    {
      final created = await _apiService.createStudyProgram(name: name, level: level, minYear: minYear, maxYear: maxYear, description: description, ministrySubjectIds: subjectIds);
      setState(() { _studyPrograms = [..._studyPrograms, created]; });
      if (mounted) CustomSnackBar.show(context: context, message: 'Percorso creato con successo!', isError: false);
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> _executeEditStudyProgram(int id, String name, String level, int minYear, int maxYear, String description, List<int> subjectIds, Function(String) onError) async
  {
    try
    {
      final updated = await _apiService.updateStudyProgram(id: id, name: name, level: level, minYear: minYear, maxYear: maxYear, description: description, ministrySubjectIds: subjectIds);
      setState(() { _studyPrograms = _studyPrograms.map((p) => p.id == id ? updated : p).toList(); });
      if (mounted) CustomSnackBar.show(context: context, message: 'Percorso modificato con successo!', isError: false);
      //InvalidaLaCopiaAnnidataDentroOgniSchoolItem_AltrimentiRestaConIlNomeVecchio
      await _refreshSchools();
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void _executeDeleteStudyProgram(StudyProgramItem item) async
  {
    try
    {
      await _apiService.deleteStudyProgram(item.id);
      setState(() { _studyPrograms = _studyPrograms.where((p) => p.id != item.id).toList(); });
      if (mounted) CustomSnackBar.show(context: context, message: 'Percorso eliminato con successo!', isError: false);
      //InvalidaLaCopiaAnnidataDentroOgniSchoolItem_AltrimentiContinuaAComparireComeAssociato
      await _refreshSchools();
    }
    catch (e)
    {
      if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  // -----------------------------------------------------------------------
  // Scuole (School)
  // -----------------------------------------------------------------------

  Future<bool> _executeCreateSchool(String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) async
  {
    try
    {
      final createdSchool = await _apiService.createSchool(code: code, name: name, city: city, province: prov, studyProgramIds: programIds);
      setState(() { _schools = [..._schools, createdSchool]; });
      if (mounted) CustomSnackBar.show(context: context, message: 'Scuola creata con successo!', isError: false);
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> _executeEditSchool(int id, String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) async
  {
    try
    {
      final updatedSchool = await _apiService.updateSchool(id: id, code: code, name: name, city: city, province: prov, studyProgramIds: programIds);
      setState(() { _schools = _schools.map((s) => s.id == id ? updatedSchool : s).toList(); });
      //SnackBarDiSuccessoAggiuntoAncheSuModifica_PrimaCEraSoloSuCreazione
      if (mounted) CustomSnackBar.show(context: context, message: 'Scuola modificata con successo!', isError: false);
      return true;
    }
    catch (e)
    {
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void _executeDeleteSchool(SchoolItem item) async
  {
    try
    {
      await _apiService.deleteSchool(item.id);
      setState(() { _schools = _schools.where((s) => s.id != item.id).toList(); });
      //SnackBarDiSuccessoAggiuntoAncheSuCancellazione_PrimaCEraSoloLerroreInCatch
      if (mounted) CustomSnackBar.show(context: context, message: 'Scuola eliminata con successo!', isError: false);
    }
    catch (e)
    {
      if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
    }
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
  //IDatiCondivisiOraArrivanoDallAltoTramiteWidgetProperty_UnSetStateQuiPropagaAiTabGiaMontatiTramiteDidUpdateWidget
  //SenzaDisposeERicreazioneDelLoroStatoInterno(ScrollFiltriRicerca)
  Widget _buildTabContent() 
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)));
    }

    return IndexedStack(
      index: _computeContentIndex(),
      children: [
        _visitedTabs.contains(0)
            ? SchoolsTab(
                schools: _schools,
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                onCreate: _executeCreateSchool,
                onEdit: _executeEditSchool,
                onDelete: _executeDeleteSchool,
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(1)
            ? AssociationSubjectsTab(
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateAssociationSubject,
                onEdit: _executeEditAssociationSubject,
                onDelete: _executeDeleteAssociationSubject,
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(2)
            ? MinistrySubjectsTab(
                ministrySubjects: _ministrySubjects,
                associationSubjects: _associationSubjects,
                onCreate: _executeCreateMinistrySubject,
                onEdit: _executeEditMinistrySubject,
                onDelete: _executeDeleteMinistrySubject,
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(3)
            ? StudyProgramsTab(
                studyPrograms: _studyPrograms,
                ministrySubjects: _ministrySubjects,
                onCreate: _executeCreateStudyProgram,
                onEdit: _executeEditStudyProgram,
                onDelete: _executeDeleteStudyProgram,
              )
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