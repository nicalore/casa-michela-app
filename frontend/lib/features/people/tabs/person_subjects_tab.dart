import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_service.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/person_item.dart';
import '../models/teacher_subject_item.dart';
import '../person_wizard_components.dart';

class PersonSubjectsTab extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const PersonSubjectsTab({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  @override
  State<PersonSubjectsTab> createState() => _PersonSubjectsTabState();
}

class _PersonSubjectsTabState extends State<PersonSubjectsTab>
{
  final TextEditingController _searchCtrl = TextEditingController();
  String  _searchText = '';
  String  _sortBy     = 'name_asc';
  String? _filterArea;

  @override
  void dispose()
  {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TeacherSubjectItem> get _filteredSubjects
  {
    final List<TeacherSubjectItem> subjects = widget.person.teacherSubjects ?? [];

    var result = subjects.where((subj)
    {
      final query         = _searchText.toLowerCase();
      final matchesSearch = subj.subjectName.toLowerCase().contains(query);
      final matchesArea   = _filterArea == null || subj.subjectArea == _filterArea;
      return matchesSearch && matchesArea;
    }).toList();

    result.sort((a, b)
    {
      if (_sortBy == 'name_asc') return a.subjectName.compareTo(b.subjectName);
      if (_sortBy == 'name_desc') return b.subjectName.compareTo(a.subjectName);
      return 0;
    });

    return result;
  }

  void _openEditDialog(BuildContext context) 
  {
    showGeneralDialog(
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'EditSubjects', 
      barrierColor:       Colors.black.withValues(alpha: .5), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _SubjectsEditDialog(
                person:   widget.person, 
                onUpdate: widget.onUpdate,
              ),
            ),
          ),
        );
      },
    );
  }

  void _openReadOnlyProgramsDialog(BuildContext context, TeacherSubjectItem subject) 
  {
    showGeneralDialog(
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'ViewPrograms', 
      barrierColor:       Colors.black.withValues(alpha: .15), 
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _ReadOnlyProgramsDialog(subject: subject),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final List<TeacherSubjectItem> allSubjects = widget.person.teacherSubjects ?? [];

    if (allSubjects.isEmpty) 
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nessuna disciplina insegnata a sistema.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   16,
                  fontWeight: FontWeight.w500,
                  color:      const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 280,
                child: WizardAnimatedActionButton(
                  text:       'MODIFICA DISCIPLINE',
                  icon:       Icons.edit_rounded,
                  baseColor:  const Color(0xFF003C82),
                  hoverColor: const Color(0xFF004D99),
                  onPressed:  () => _openEditDialog(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final validSubjects = _filteredSubjects;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top:    16,
        left:   0,
        right:  0,
        bottom: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold
              //QuestaRigaNonAvevaMaiRicevutoAlcunTrattamentoResponsive_SforavaSempreASchermiStretti
              _ResponsiveSearchFilterRow(
                breakpoint: 650,
                searchBar: WizardAnimatedSearchBar(
                  controller: _searchCtrl,
                  onChanged:  (value) => setState(() => _searchText = value),
                  hintText:   'Cerca disciplina...',
                ),
                filterWidgets: [
                  WizardFilterMenu<String>(
                    hint:          'Ordina per',
                    icon:          Icons.sort_rounded,
                    value:         _sortBy,
                    menuWidth:     180,
                    showClearIcon: false,
                    onChanged:     (val) => setState(() => _sortBy = val),
                    onClear:       () {},
                    options: [
                      WizardFilterOption(value: 'name_asc', label: 'Nome (A-Z)'),
                      WizardFilterOption(value: 'name_desc', label: 'Nome (Z-A)'),
                    ],
                  ),
                  WizardFilterMenu<String>(
                    hint:          'Tutte le aree',
                    icon:          Icons.category_outlined,
                    value:         _filterArea,
                    menuWidth:     200,
                    showClearIcon: true,
                    onChanged:     (val) => setState(() => _filterArea = val),
                    onClear:       () => setState(() => _filterArea = null),
                    options: [
                      WizardFilterOption(value: 'HUMANITIES', label: 'Area Umanistica'),
                      WizardFilterOption(value: 'LINGUISTICS', label: 'Area Linguistica'),
                      WizardFilterOption(value: 'SCIENCES', label: 'Area Scientifica'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (validSubjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Nessuna disciplina trovata per questa ricerca.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   16,
                        fontWeight: FontWeight.w500,
                        color:      const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing:    16,
                  runSpacing: 16,
                  alignment:  WrapAlignment.start,
                  children:   validSubjects.map((subj) 
                  {
                    return _SubjectReadOnlyCard(
                      subject: subj,
                      onTap:   () => _openReadOnlyProgramsDialog(context, subj),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 48),
              Center(
                child: SizedBox(
                  width: 320,
                  child: WizardAnimatedActionButton(
                    text:       'MODIFICA DISCIPLINE',
                    icon:       Icons.edit_rounded,
                    baseColor:  const Color(0xFF003C82),
                    hoverColor: const Color(0xFF004D99),
                    onPressed:  () => _openEditDialog(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectReadOnlyCard extends StatefulWidget 
{
  final TeacherSubjectItem subject;
  final VoidCallback       onTap;

  const _SubjectReadOnlyCard({
    required this.subject,
    required this.onTap,
  });

  @override
  State<_SubjectReadOnlyCard> createState() => _SubjectReadOnlyCardState();
}

class _SubjectReadOnlyCardState extends State<_SubjectReadOnlyCard> 
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) 
  {
    final int count = widget.subject.studyProgramIds.length;

    return Tooltip(
      message:      widget.subject.subjectName,
      waitDuration: const Duration(milliseconds: 600),
      padding:      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle:    GoogleFonts.plusJakartaSans(
        fontSize:   14, 
        fontWeight: FontWeight.w500, 
        color:      Colors.white,
      ),
      decoration: BoxDecoration(
        color:        const Color(0xFF1E293B).withValues(alpha: .98),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      child: MouseRegion(
        cursor:  SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit:  (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration:    const Duration(milliseconds: 180),
            curve:       Curves.easeOut,
            width:       360,
            constraints: const BoxConstraints(minHeight: 100),
            padding:     const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            alignment:   Alignment.centerLeft,
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _isHovering ? const Color(0xFF003C82) : const Color(0xFFE2E8F0), 
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color:      Color(0x0A000000), 
                  offset:     Offset(0, 4), 
                  blurRadius: 16,
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.subject_rounded,
                  size:  32,
                  color: Color(0xFFB3B3B3),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize:       MainAxisSize.min,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject.subjectName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize:   16,
                          fontWeight: FontWeight.w700,
                          color:      const Color(0xFF2A2A2A),
                          height:     1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count == 1 ? '1 percorso' : '$count percorsi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color:      const Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyProgramsDialog extends StatelessWidget 
{
  final TeacherSubjectItem subject;

  const _ReadOnlyProgramsDialog({
    required this.subject,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container(
        width:       600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color:      Color(0x1A000000),
              offset:     Offset(0, 8),
              blurRadius: 24,
            )
          ],
        ),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subject.subjectName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   22,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF003C82),
                      ),
                    ),
                  ),
                  WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
              child: Text(
                'Percorsi assegnati',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      const Color(0xFF003C82),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                child: Wrap(
                  spacing:    12,
                  runSpacing: 12,
                  children: subject.studyPrograms.map((progName) 
                  {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFE0E5EC), 
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        progName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize:   14, 
                          fontWeight: FontWeight.w600, 
                          color:      const Color(0xFF64748B),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectsEditDialog extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const _SubjectsEditDialog({
    required this.person,
    required this.onUpdate,
  });

  @override
  State<_SubjectsEditDialog> createState() => _SubjectsEditDialogState();
}

class _SubjectsEditDialogState extends State<_SubjectsEditDialog> 
{
  bool                         _isLoadingData = true;
  bool                         _isSubmitting  = false;
  List<AssociationSubjectItem> _allSubjects   = [];
  List<StudyProgramItem>       _allPrograms   = [];

  final TextEditingController _searchSubjectsCtrl         = TextEditingController();
  String                      _searchSubjectsText         = '';
  String                      _sortSubjectsBy             = 'name_asc';
  String?                     _filterSubjectsArea;
  
  final Map<int, bool>        _subjectToggles             = {};
  final Map<int, Set<int>>    _selectedProgramsForSubject = {};

  @override
  void initState() 
  {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() 
  {
    _searchSubjectsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async 
  {
    try 
    {
      final results = await Future.wait([
        ApiService().getAssociationSubjects(),
        ApiService().getStudyPrograms(),
      ]);
      
      if (mounted) 
      {
        setState(() 
        {
          _allSubjects = results[0] as List<AssociationSubjectItem>;
          _allPrograms = results[1] as List<StudyProgramItem>;
          
          if (widget.person.teacherSubjects != null)
          {
            for (final comp in widget.person.teacherSubjects!) 
            {
              _subjectToggles[comp.subjectId]             = true;
              _selectedProgramsForSubject[comp.subjectId] = comp.studyProgramIds.toSet();
            }
          }
          
          _isLoadingData = false;
        });
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        setState(() => _isLoadingData = false);
      }
    }
  }

  List<StudyProgramItem> _getProgramsForSubject(AssociationSubjectItem subject) 
  {
    final List<StudyProgramItem> linkedPrograms = [];
    
    for (final prog in _allPrograms) 
    {
      bool hasMatch = false;
      try 
      {
        final dynamic minSubjects = (prog as dynamic).ministrySubjects;
        if (minSubjects != null && minSubjects is Iterable) 
        {
          for (var m in minSubjects) 
          {
            final dynamic assocSubjects = (m as dynamic).associationSubjects;
            if (assocSubjects != null && assocSubjects is Iterable) 
            {
              for (var assoc in assocSubjects) 
              {
                final int? assocId = (assoc is Map) ? assoc['id'] as int? : (assoc as dynamic).id as int?;
                if (assocId == subject.id)
                {
                  hasMatch = true;
                  break;
                }
              }
            }
            if (hasMatch) break; 
          }
        }
      }
      catch (_) {}
      
      if (hasMatch) linkedPrograms.add(prog);
    }
    
    return linkedPrograms;
  }

  List<AssociationSubjectItem> get _filteredFilteredSubjects 
  {
    var result = _allSubjects.where((subject)
    {
      if (_getProgramsForSubject(subject).isEmpty) return false;
      
      final query         = _searchSubjectsText.toLowerCase();
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea   = _filterSubjectsArea == null || subject.area == _filterSubjectsArea;
      
      return matchesSearch && matchesArea;
    }).toList();

    result.sort((a, b)
    {
      if (_sortSubjectsBy == 'name_asc') return a.name.compareTo(b.name);
      if (_sortSubjectsBy == 'name_desc') return b.name.compareTo(a.name);
      if (_sortSubjectsBy == 'date_asc') return a.createdAt.compareTo(b.createdAt);
      if (_sortSubjectsBy == 'date_desc') return b.createdAt.compareTo(a.createdAt);
      return 0;
    });

    return result;
  }

  void _openProgramsDialog(AssociationSubjectItem subject) 
  {
    final programs = _getProgramsForSubject(subject);
    
    showGeneralDialog(
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'ProgramsSelection', 
      barrierColor:       Colors.black.withValues(alpha: .15), 
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: WizardProgramsSelectionDialog(
                subject:         subject,
                programs:        programs,
                initialSelected: _selectedProgramsForSubject[subject.id] ?? {},
                onSave:          (selected) 
                {
                  setState(() 
                  {
                    if (selected.isEmpty) 
                    {
                      _subjectToggles[subject.id] = false;
                      _selectedProgramsForSubject.remove(subject.id);
                    } 
                    else 
                    {
                      _subjectToggles[subject.id] = true;
                      _selectedProgramsForSubject[subject.id] = selected;
                    }
                  });
                },
                onCancel: ()
                {
                  setState(() 
                  {
                    if (!(_subjectToggles[subject.id] ?? false))
                    {
                      _subjectToggles[subject.id] = false;
                      _selectedProgramsForSubject.remove(subject.id);
                    }
                  });
                }
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async 
  {
    bool hasAtLeastOneSubject = _subjectToggles.values.any((isSelected) => isSelected == true);
    
    if (!hasAtLeastOneSubject)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina per salvare.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try 
    {
      final List<Map<String, dynamic>> competences = _subjectToggles.entries
          .where((e) => e.value) 
          .map((e) => {
                "subject_id":        e.key,
                "study_program_ids": _selectedProgramsForSubject[e.key]?.toList() ?? [],
              })
          .toList();

      await ApiService().updateTeacherCompetences(
        widget.person.fiscalCode, 
        competences,
      );

      if (mounted) 
      {
        CustomSnackBar.show(context: context, message: 'Discipline aggiornate con successo!', isError: false);
        Navigator.of(context).pop();
        widget.onUpdate();
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final validSubjects = _filteredFilteredSubjects;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container(
        width:       MediaQuery.of(context).size.width * 0.85,
        height:      MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration(
          color:        const Color(0xFFF4F7F9),
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const [
            BoxShadow(
              color:      Color(0x1A000000),
              offset:     Offset(0, 8),
              blurRadius: 24,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              Positioned(
                right: -400,
                top:   -400,
                child: IgnorePointer(
                  child: Container(
                    width:  800,
                    height: 800,
                    decoration: const BoxDecoration(
                      shape:    BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops:  [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left:   -400,
                bottom: -400,
                child: IgnorePointer(
                  child: Container(
                    width:  800,
                    height: 800,
                    decoration: const BoxDecoration(
                      shape:    BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x22003C82), Color(0x00003C82)],
                        stops:  [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Modifica Discipline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:   24,
                            fontWeight: FontWeight.w700,
                            color:      const Color(0xFF003C82),
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1140),
                        //SideBySideWhenThereIsRoom_StacksOnlyBelowTheThreshold
                        child: _ResponsiveSearchFilterRow(
                          breakpoint: 650,
                          searchBar: WizardAnimatedSearchBar(
                            controller: _searchSubjectsCtrl, 
                            onChanged:  (value) => setState(() => _searchSubjectsText = value), 
                            hintText:   'Cerca disciplina...',
                          ),
                          filterWidgets: [
                            WizardFilterMenu<String>(
                              hint:          'Ordina per', 
                              icon:          Icons.sort_rounded, 
                              value:         _sortSubjectsBy, 
                              menuWidth:     180, 
                              showClearIcon: false, 
                              onChanged:     (val) => setState(() => _sortSubjectsBy = val), 
                              onClear:       () {}, 
                              options: [
                                WizardFilterOption(value: 'name_asc', label: 'Nome (A-Z)'), 
                                WizardFilterOption(value: 'name_desc', label: 'Nome (Z-A)'),
                                WizardFilterOption(value: 'date_desc', label: 'Più recente'), 
                                WizardFilterOption(value: 'date_asc', label: 'Meno recente'), 
                              ]
                            ),
                            WizardFilterMenu<String>(
                              hint:          'Tutte le aree', 
                              icon:          Icons.category_outlined, 
                              value:         _filterSubjectsArea, 
                              menuWidth:     200, 
                              showClearIcon: true, 
                              onChanged:     (val) => setState(() => _filterSubjectsArea = val), 
                              onClear:       () => setState(() => _filterSubjectsArea = null), 
                              options: [
                                WizardFilterOption(value: 'HUMANITIES', label: 'Area Umanistica'), 
                                WizardFilterOption(value: 'LINGUISTICS', label: 'Area Linguistica'), 
                                WizardFilterOption(value: 'SCIENCES', label: 'Area Scientifica')
                              ]
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingData 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: validSubjects.isEmpty
                            ? Center(
                                child: Text(
                                  'Nessuna disciplina trovata per questa ricerca.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize:   16,
                                    fontWeight: FontWeight.w500,
                                    color:      const Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1140),
                                  child: Wrap(
                                    spacing:    16,
                                    runSpacing: 16,
                                    alignment:  WrapAlignment.start,
                                    children:   validSubjects.map((subject) 
                                    {
                                      final isSelected    = _subjectToggles[subject.id] ?? false;
                                      final selectedCount = (_selectedProgramsForSubject[subject.id] ?? {}).length;
                                      
                                      return WizardSubjectGridCard(
                                        subject:       subject,
                                        isSelected:    isSelected,
                                        selectedCount: selectedCount,
                                        onTap:         () => _openProgramsDialog(subject),
                                        onRemove:      () 
                                        {
                                          setState(() 
                                          {
                                            _subjectToggles[subject.id] = false;
                                            _selectedProgramsForSubject.remove(subject.id);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    //StacksVerticallyWhenTheDialogIsTooNarrowForBothButtonsSideBySide
                    //QuestaRigaNonAvevaMaiRicevutoAlcunTrattamentoResponsive
                    child: _ResponsiveDialogButtonsRow(
                      secondaryButton: WizardAnimatedActionButton(
                        text:       'ANNULLA',
                        icon:       Icons.close_rounded,
                        baseColor:  const Color(0xFFE53935),
                        hoverColor: const Color(0xFFEF5350),
                        onPressed:  () => Navigator.of(context).pop(),
                      ),
                      primaryButton: WizardAnimatedActionButton(
                        text:       _isSubmitting ? 'SALVATAGGIO...' : 'CONFERMA',
                        icon:       Icons.check_circle_outline,
                        baseColor:  const Color(0xFF003C82),
                        hoverColor: const Color(0xFF004D99),
                        onPressed:  _isSubmitting ? () {} : _submitForm,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//DecideSeAffiancareRicercaEFiltriOImpilarli_SoloSottoSoglia_StessoCriterioUsatoAltroveInQuestaApp
class _ResponsiveSearchFilterRow extends StatelessWidget
{
  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;
  final double spacing;

  const _ResponsiveSearchFilterRow
  ({
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              searchBar,
              SizedBox(height: spacing),
              Wrap
              (
                spacing:    spacing,
                runSpacing: spacing,
                children:   filterWidgets,
              ),
            ],
          );
        }

        final List<Widget> rowChildren = [Expanded(child: searchBar)];
        for (final w in filterWidgets)
        {
          rowChildren.add(SizedBox(width: spacing));
          rowChildren.add(w);
        }

        return Row(children: rowChildren);
      },
    );
  }
}

//DecideSoloSeAffiancareOImpilare_LaModalitaAffiancataRestaComEra(50/50)_SoloLoStackingUsaLarghezzaFissa
//StessoCriterioGiaUsatoInPersonEditDialog
class _ResponsiveDialogButtonsRow extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;
  final double breakpoint;

  const _ResponsiveDialogButtonsRow
  ({
    required this.secondaryButton,
    required this.primaryButton,
    this.breakpoint = 460,
  });

  static const double _kStackedButtonWidth = 240;

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            mainAxisSize: MainAxisSize.min,
            children: 
            [
              SizedBox(width: _kStackedButtonWidth, child: primaryButton),
              const SizedBox(height: 16),
              SizedBox(width: _kStackedButtonWidth, child: secondaryButton),
            ],
          );
        }

        return Row
        (
          children: 
          [
            Expanded(child: secondaryButton),
            const SizedBox(width: 16),
            Expanded(child: primaryButton),
          ],
        );
      },
    );
  }
}