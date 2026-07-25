import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/shared_components.dart';
import '../models/people_filter_state.dart';

class PeopleFilterDialog extends StatefulWidget
{
  final PeopleFilterState                 initialState;
  final List<String>                      availableCities;
  final List<String>                      availableSchools;
  final List<String>                      availableStudyPrograms;
  final List<String>                      availableSubjects;
  final ValueChanged<PeopleFilterState>   onApply;

  const PeopleFilterDialog({
    super.key,
    required this.initialState,
    required this.availableCities,
    required this.availableSchools,
    required this.availableStudyPrograms,
    required this.availableSubjects,
    required this.onApply,
  });

  @override
  State<PeopleFilterDialog> createState() => _PeopleFilterDialogState();
}

class _PeopleFilterDialogState extends State<PeopleFilterDialog>
{
  late PeopleFilterState _currentState;

  final TextEditingController _cityController         = TextEditingController();
  final TextEditingController _schoolController       = TextEditingController();
  final TextEditingController _studyProgramController = TextEditingController();
  final TextEditingController _subjectController      = TextEditingController();
  final TextEditingController _courseTypeController   = TextEditingController();
  final ScrollController      _scrollController       = ScrollController();

  final List<String> _availableRoles = [
    'Amministratore',
    'Docente',
    'Psicologo',
    'Genitore',
    'Associato',
    'Studente',
    'Corsista',
  ];

  @override
  void initState()
  {
    super.initState();
    _currentState = widget.initialState;

    _cityController.text         = _currentState.city           ?? '';
    _schoolController.text       = _currentState.schoolName     ?? '';
    _studyProgramController.text = _currentState.studyProgram   ?? '';
    _subjectController.text      = '';
    _courseTypeController.text   = _currentState.courseType     ?? '';
  }

  @override
  void dispose()
  {
    _cityController.dispose();
    _schoolController.dispose();
    _studyProgramController.dispose();
    _subjectController.dispose();
    _courseTypeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleRole(String role, bool isSelected)
  {
    setState(()
    {
      List<String> updatedRoles = List.from(_currentState.selectedRoles);

      if (isSelected)
      {
        updatedRoles.add(role);
      }
      else
      {
        updatedRoles.remove(role);
      }

      _currentState = _currentState.copyWith(
        selectedRoles: updatedRoles,
        clearRoles:    updatedRoles.isEmpty,
      );
    });
  }

  void _addSubject(String subject)
  {
    String s = subject.trim();
    // Defence in depth: only accept subjects that actually exist in widget.availableSubjects.
    if (s.isEmpty || !widget.availableSubjects.contains(s) || _currentState.taughtSubjects.contains(s))
    {
      return;
    }

    setState(()
    {
      List<String> updated = List.from(_currentState.taughtSubjects)..add(s);
      _currentState        = _currentState.copyWith(taughtSubjects: updated);
    });
  }

  void _removeSubject(String subject)
  {
    setState(()
    {
      List<String> updated = List.from(_currentState.taughtSubjects)..remove(subject);

      _currentState = _currentState.copyWith(
        taughtSubjects:      updated,
        clearTaughtSubjects: updated.isEmpty,
      );
    });
  }

  void _resetFilters()
  {
    setState(()
    {
      _currentState = const PeopleFilterState();

      _cityController.clear();
      _schoolController.clear();
      _studyProgramController.clear();
      _subjectController.clear();
      _courseTypeController.clear();
    });
  }

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color:      AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize:   14,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(height: 1, thickness: 1, color: AppTheme.border),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize:   16,
            fontWeight: FontWeight.w700,
            color:      AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController  controller,
    String                 hint,
    ValueChanged<String>   onChanged, {
    ValueChanged<String>?  onSubmitted,
  })
  {
    return Container(
      height:     50,
      padding:    const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:  controller,
              onChanged:   (val)
              {
                setState(() {});
                onChanged(val);
              },
              onSubmitted: onSubmitted,
              style:       GoogleFonts.plusJakartaSans(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      Colors.black87,
              ),
              decoration: InputDecoration(
                hintText:    hint,
                hintStyle:   GoogleFonts.plusJakartaSans(
                  fontSize:   15,
                  fontWeight: FontWeight.w500,
                  color:      AppTheme.hint,
                ),
                border:      InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: ()
                {
                  controller.clear();
                  onChanged('');
                  setState(() {});
                },
                child: Container(
                  padding:    const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:        AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size:  16,
                    color: AppTheme.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final roles = _currentState.selectedRoles;

    final bool showParentFilters    = roles.contains('Genitore');
    final bool showAssociateFilters = roles.isNotEmpty && roles.any((r) => r != 'Genitore');
    final bool showStudentFilters   = roles.contains('Studente');
    final bool showStaffFilters     = roles.any((r) => ['Amministratore', 'Docente', 'Psicologo'].contains(r));
    final bool showTeacherFilters   = roles.contains('Docente');
    final bool showCourseFilters    = roles.contains('Corsista');

    final bool isFullAgeRange = _currentState.ageRange == null ||
        (_currentState.ageRange!.start == 5 && _currentState.ageRange!.end == 99);

    final bool isFullSubjectRange = _currentState.taughtSubjectsCount == null ||
        (_currentState.taughtSubjectsCount!.start == 1 && _currentState.taughtSubjectsCount!.end == 15);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation:       0,
      child: Container(
        width:       540,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtri di ricerca',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   20,
                      fontWeight: FontWeight.w700,
                      color:      AppTheme.primary,
                    ),
                  ),
                  StaticHoverIconButton(
                    icon:       Icons.close,
                    color:      AppTheme.primary,
                    hoverColor: AppTheme.iconHover,
                    onTap:      () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppTheme.divider),

            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: RawScrollbar(
                  controller:      _scrollController,
                  thumbVisibility: true,
                  thickness:       6,
                  radius:          const Radius.circular(10),
                  thumbColor:      AppTheme.hint,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding:    const EdgeInsets.only(
                      left:   32,
                      right:  32,
                      bottom: 24,
                      top:    8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Ruoli'),
                        Wrap(
                          spacing:    10,
                          runSpacing: 10,
                          children:   _availableRoles.map((role)
                          {
                            return CustomChip(
                              label:      role,
                              isSelected: _currentState.selectedRoles.contains(role),
                              onSelected: (val) => _toggleRole(role, val),
                            );
                          }).toList(),
                        ),

                        _buildSectionTitle('Generali'),
                        _buildFieldLabel('Città di residenza'),
                        _AutocompleteField(
                          controller: _cityController,
                          hint:       'Es. Thiene',
                          options:    widget.availableCities,
                          onChanged:  (val) => setState(()
                          {
                            _currentState = _currentState.copyWith(
                              city:      val,
                              clearCity: val.isEmpty,
                            );
                          }),
                        ),

                        _buildFieldLabel('Fascia di età'),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor:        AppTheme.primary,
                            inactiveTrackColor:      AppTheme.border,
                            thumbColor:              AppTheme.primary,
                            valueIndicatorColor:     AppTheme.primary,
                            overlayShape:            SliderComponentShape.noOverlay,
                            valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
                              color:      Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: RangeSlider(
                            values:    _currentState.ageRange ?? const RangeValues(5, 99),
                            min:       5,
                            max:       99,
                            divisions: 94,
                            labels: RangeLabels(
                              _currentState.ageRange?.start.round().toString() ?? '5',
                              _currentState.ageRange?.end.round() == 99
                                  ? '99+'
                                  : _currentState.ageRange?.end.round().toString() ?? '99+',
                            ),
                            onChanged: (RangeValues values)
                            {
                              setState(()
                              {
                                _currentState = _currentState.copyWith(ageRange: values);
                              });
                            },
                          ),
                        ),
                        Center(
                          child: Text(
                            isFullAgeRange
                                ? 'Tutte le età'
                                : '${_currentState.ageRange!.start.round()} - ${_currentState.ageRange!.end.round() == 99 ? '99+' : _currentState.ageRange!.end.round()} anni',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   14,
                              color:      AppTheme.slate500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        AnimatedSize(
                          duration:  const Duration(milliseconds: 300),
                          curve:     Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child:     showParentFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Genitore'),
                                    _buildFieldLabel('Numero figli associati'),
                                    _DialogDropdownMenu<String?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.childrenCount,
                                      options: [
                                        _DropdownOption(value: null, label: 'Qualsiasi'),
                                        _DropdownOption(value: '1',  label: '1'),
                                        _DropdownOption(value: '2',  label: '2'),
                                        _DropdownOption(value: '3',  label: '3'),
                                        _DropdownOption(value: '4+', label: '4 o più'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          childrenCount:      val,
                                          clearChildrenCount: val == null,
                                        );
                                      }),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration:  const Duration(milliseconds: 300),
                          curve:     Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child:     showAssociateFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Associato'),
                                    _buildFieldLabel('Stato collaborazione'),
                                    _DialogDropdownMenu<bool?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.isActiveCollaborator,
                                      options: [
                                        _DropdownOption(value: null,  label: 'Qualsiasi'),
                                        _DropdownOption(value: true,  label: 'Attiva'),
                                        _DropdownOption(value: false, label: 'Inattiva'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          isActiveCollaborator: val,
                                          clearCollaborator:    val == null,
                                        );
                                      }),
                                    ),
                                    _buildFieldLabel('Anno di prima iscrizione'),
                                    _DialogDropdownMenu<String?>(
                                      hint:    'Qualsiasi anno',
                                      value:   _currentState.enrollmentYear,
                                      options: [
                                        _DropdownOption(value: null,   label: 'Qualsiasi anno'),
                                        _DropdownOption(value: '2026', label: '2026'),
                                        _DropdownOption(value: '2025', label: '2025'),
                                        _DropdownOption(value: '2024', label: '2024'),
                                        _DropdownOption(value: '2023', label: '2023'),
                                        _DropdownOption(value: '2022', label: '2022'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          enrollmentYear:  val,
                                          clearEnrollment: val == null,
                                        );
                                      }),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration:  const Duration(milliseconds: 300),
                          curve:     Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child:     showStudentFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Studente'),
                                    _buildFieldLabel('Livello di istruzione'),
                                    _DialogDropdownMenu<String?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.educationLevel,
                                      options: [
                                        _DropdownOption(value: null,                            label: 'Qualsiasi'),
                                        _DropdownOption(value: 'Scuola primaria',               label: 'Primaria'),
                                        _DropdownOption(value: 'Scuola secondaria di I grado',  label: 'Secondaria di I grado'),
                                        _DropdownOption(value: 'Scuola secondaria di II grado', label: 'Secondaria di II grado'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          educationLevel:      val,
                                          clearEducationLevel: val == null,
                                        );
                                      }),
                                    ),
                                    _buildFieldLabel('Scuola frequentata'),
                                    _AutocompleteField(
                                      controller: _schoolController,
                                      hint:       'Es. Liceo Statale Francesco Corradini',
                                      options:    widget.availableSchools,
                                      onChanged:  (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          schoolName:      val,
                                          clearSchoolName: val.isEmpty,
                                        );
                                      }),
                                    ),
                                    _buildFieldLabel('Classe'),
                                    _DialogDropdownMenu<String?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.schoolClass,
                                      options: [
                                        _DropdownOption(value: null,  label: 'Qualsiasi'),
                                        _DropdownOption(value: 'I',   label: 'I'),
                                        _DropdownOption(value: 'II',  label: 'II'),
                                        _DropdownOption(value: 'III', label: 'III'),
                                        _DropdownOption(value: 'IV',  label: 'IV'),
                                        _DropdownOption(value: 'V',   label: 'V'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          schoolClass:      val,
                                          clearSchoolClass: val == null,
                                        );
                                      }),
                                    ),
                                    _buildFieldLabel('Indirizzo di studio'),
                                    _AutocompleteField(
                                      controller: _studyProgramController,
                                      hint:       'Es. Liceo Classico',
                                      options:    widget.availableStudyPrograms,
                                      onChanged:  (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          studyProgram:      val,
                                          clearStudyProgram: val.isEmpty,
                                        );
                                      }),
                                    ),
                                    _buildFieldLabel('Uscita anticipata'),
                                    _DialogDropdownMenu<bool?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.earlyExit,
                                      options: [
                                        _DropdownOption(value: null,  label: 'Qualsiasi'),
                                        _DropdownOption(value: true,  label: 'Sì'),
                                        _DropdownOption(value: false, label: 'No'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          earlyExit:      val,
                                          clearEarlyExit: val == null,
                                        );
                                      }),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration:  const Duration(milliseconds: 300),
                          curve:     Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child:     showStaffFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Staff'),
                                    _buildFieldLabel('Tipo collaborazione'),
                                    _DialogDropdownMenu<String?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.collaborationType,
                                      options: [
                                        _DropdownOption(value: null,         label: 'Qualsiasi'),
                                        _DropdownOption(value: 'Volontario', label: 'Volontario'),
                                        _DropdownOption(value: 'Retribuito', label: 'Retribuito'),
                                        _DropdownOption(value: 'PCTO',       label: 'PCTO'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          collaborationType:      val,
                                          clearCollaborationType: val == null,
                                        );
                                      }),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration:  const Duration(milliseconds: 300),
                          curve:     Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child:     showTeacherFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Docente'),

                                    _buildFieldLabel('Discipline insegnate'),
                                    _AutocompleteField(
                                      controller:  _subjectController,
                                      hint:        'Scrivi la disciplina e premi Invio',
                                      options:     widget.availableSubjects,
                                      onChanged:   (_) {},
                                      onSubmitted: _addSubject,
                                    ),
                                    if (_currentState.taughtSubjects.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing:    8,
                                        runSpacing: 8,
                                        children:   _currentState.taughtSubjects.map((s)
                                        {
                                          return _DeletableChip(
                                            label:    s,
                                            onDelete: () => _removeSubject(s),
                                          );
                                        }).toList(),
                                      ),
                                    ],

                                    _buildFieldLabel('Numero materie insegnate'),
                                    const SizedBox(height: 8),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor:        AppTheme.primary,
                                        inactiveTrackColor:      AppTheme.border,
                                        thumbColor:              AppTheme.primary,
                                        valueIndicatorColor:     AppTheme.primary,
                                        overlayShape:            SliderComponentShape.noOverlay,
                                        valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
                                          color:      Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: RangeSlider(
                                        values:    _currentState.taughtSubjectsCount ?? const RangeValues(1, 15),
                                        min:       1,
                                        max:       15,
                                        divisions: 14,
                                        labels: RangeLabels(
                                          _currentState.taughtSubjectsCount?.start.round().toString() ?? '1',
                                          _currentState.taughtSubjectsCount?.end.round() == 15
                                              ? '15+'
                                              : _currentState.taughtSubjectsCount?.end.round().toString() ?? '15+',
                                        ),
                                        onChanged: (RangeValues values)
                                        {
                                          setState(()
                                          {
                                            _currentState = _currentState.copyWith(taughtSubjectsCount: values);
                                          });
                                        },
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        isFullSubjectRange
                                            ? 'Qualsiasi'
                                            : '${_currentState.taughtSubjectsCount!.start.round()} - ${_currentState.taughtSubjectsCount!.end.round() == 15 ? '15+' : _currentState.taughtSubjectsCount!.end.round()} materie',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize:   14,
                                          color:      AppTheme.slate500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration:  const Duration(milliseconds: 300),
                          curve:     Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child:     showCourseFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Corsista'),
                                    _buildFieldLabel('Tipo di corso'),
                                    _buildTextField(
                                      _courseTypeController,
                                      'Es. Yoga',
                                      (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          courseType:      val,
                                          clearCourseType: val.isEmpty,
                                        );
                                      }),
                                    ),
                                    _buildFieldLabel('Certificato medico'),
                                    _DialogDropdownMenu<bool?>(
                                      hint:    'Qualsiasi',
                                      value:   _currentState.isMedicalCertificateValid,
                                      options: [
                                        _DropdownOption(value: null,  label: 'Qualsiasi'),
                                        _DropdownOption(value: true,  label: 'Non scaduto'),
                                        _DropdownOption(value: false, label: 'Scaduto'),
                                      ],
                                      onChanged: (val) => setState(()
                                      {
                                        _currentState = _currentState.copyWith(
                                          isMedicalCertificateValid: val,
                                          clearMedicalCert:          val == null,
                                        );
                                      }),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text:       'AZZERA',
                      icon:       Icons.refresh_rounded,
                      baseColor:  AppTheme.danger,
                      hoverColor: AppTheme.dangerHover,
                      onPressed:  _resetFilters,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text:       'APPLICA',
                      icon:       Icons.check_circle_outline_rounded,
                      baseColor:  AppTheme.primary,
                      hoverColor: AppTheme.primaryHover,
                      onPressed:  ()
                      {
                        widget.onApply(_currentState);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Local components

class _AutocompleteField extends StatefulWidget
{
  final TextEditingController   controller;
  final String                  hint;
  final List<String>            options;
  final ValueChanged<String>    onChanged;
  final ValueChanged<String>?   onSubmitted;

  const _AutocompleteField({
    required this.controller,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<_AutocompleteField>
{
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode:             _focusNode,
      optionsBuilder:        (TextEditingValue textEditingValue)
      {
        if (textEditingValue.text.isEmpty)
        {
          return const Iterable<String>.empty();
        }

        return widget.options.where(
          (String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (String selection)
      {
        if (widget.onSubmitted != null)
        {
          widget.onSubmitted!(selection);
          // clear() alone leaves the selection at -1, which Flutter draws with no visible cursor, so reset it and restore focus.
          Future.microtask(()
          {
            widget.controller.clear();
            widget.controller.selection = const TextSelection.collapsed(offset: 0);
            _focusNode.requestFocus();
          });
        }
        else
        {
          widget.onChanged(selection);
        }
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      )
      {
        return Container(
          height:     50,
          padding:    const EdgeInsets.only(left: 16, right: 8),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textEditingController,
                  focusNode:  focusNode,
                  onChanged:  (val)
                  {
                    setState(() {});
                    widget.onChanged(val);
                  },
                  // Enter confirms RawAutocomplete's highlighted option (arrow-selected or the first result),
                  // never the free text, so only an option that really exists in widget.options can be submitted.
                  onSubmitted: (_) => onFieldSubmitted(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   15,
                    fontWeight: FontWeight.w600,
                    color:      Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText:    widget.hint,
                    hintStyle:   GoogleFonts.plusJakartaSans(
                      fontSize:   15,
                      fontWeight: FontWeight.w500,
                      color:      AppTheme.hint,
                    ),
                    border:      InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              if (textEditingController.text.isNotEmpty)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: ()
                    {
                      textEditingController.clear();
                      widget.onChanged('');
                      setState(() {});
                    },
                    child: Container(
                      padding:    const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:        AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size:  16,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      )
      {
        return _AutocompleteOptionsList(
          options:    options,
          onSelected: onSelected,
        );
      },
    );
  }
}

// Fixed height shared by the ListView itemExtent and each item container; the two must match exactly.
const double _autocompleteOptionItemHeight = 44.0;

// Scrollable suggestion list that follows the keyboard-highlighted item, auto-scrolling when it leaves the visible area.
// Same pattern as CityOptionsListView (schools_tab.dart), here generic over strings instead of city/province pairs.
class _AutocompleteOptionsList extends StatefulWidget
{
  final Iterable<String>               options;
  final AutocompleteOnSelected<String> onSelected;

  const _AutocompleteOptionsList({
    required this.options,
    required this.onSelected,
  });

  @override
  State<_AutocompleteOptionsList> createState() => _AutocompleteOptionsListState();
}

class _AutocompleteOptionsListState extends State<_AutocompleteOptionsList>
{
  // Vertical padding of the ListView (one side), used in the scroll math as the offset before the first item.
  static const double _verticalPadding = 8;

  final ScrollController _scrollController = ScrollController();
  int? _lastHighlightedIndex;

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  // Bring the highlighted item into view, scrolling only the minimum needed rather than always centering it.
  void _ensureHighlightedVisible(int index)
  {
    if (!_scrollController.hasClients)
    {
      return;
    }

    final itemTop        = _verticalPadding + (index * _autocompleteOptionItemHeight);
    final itemBottom      = itemTop + _autocompleteOptionItemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final visibleTop      = _scrollController.offset;
    final visibleBottom   = visibleTop + viewportHeight;

    double? target;
    if (itemTop < visibleTop)
    {
      target = itemTop;
    }
    else if (itemBottom > visibleBottom)
    {
      target = itemBottom - viewportHeight;
    }

    if (target != null)
    {
      final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    // The arrow-highlighted index; reading it here subscribes to the notifier so this widget rebuilds on every change.
    final highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (_lastHighlightedIndex != highlightedIndex)
    {
      _lastHighlightedIndex = highlightedIndex;
      // Scheduled after the frame: the scrollable must be laid out before its viewportDimension and maxScrollExtent are known.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _ensureHighlightedVisible(highlightedIndex);
        }
      });
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width:       436,
          margin:      const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          // Clip.antiAlias stops the last highlighted item's rectangular background from covering the rounded corners.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.overlayShadow,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller:      _scrollController,
              thumbVisibility: true,
              thickness:       6,
              radius:          const Radius.circular(10),
              thumbColor:      AppTheme.hint,
              child: ListView.builder(
                controller:  _scrollController,
                padding:     const EdgeInsets.symmetric(vertical: _verticalPadding),
                shrinkWrap:  true,
                itemExtent:  _autocompleteOptionItemHeight,
                itemCount:   widget.options.length,
                itemBuilder: (BuildContext context, int index)
                {
                  final String option = widget.options.elementAt(index);
                  return _AutocompleteOptionTile(
                    text:          option,
                    isHighlighted: index == highlightedIndex,
                    onTap:         () => widget.onSelected(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A suggestion list item, highlighted on hover or via keyboard arrows (isHighlighted); same visual language as CityOptionTile.
class _AutocompleteOptionTile extends StatefulWidget
{
  final String       text;
  final bool         isHighlighted;
  final VoidCallback onTap;

  const _AutocompleteOptionTile({
    required this.text,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_AutocompleteOptionTile> createState() => _AutocompleteOptionTileState();
}

class _AutocompleteOptionTileState extends State<_AutocompleteOptionTile>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool active = widget.isHighlighted || _hover;

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width:   double.infinity,
          height:  _autocompleteOptionItemHeight,
          color:   active ? AppTheme.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration:   const Duration(milliseconds: 150),
                width:      2,
                height:     active ? 16 : 0,
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color:      AppTheme.primary,
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

class _DeletableChip extends StatefulWidget
{
  final String       label;
  final VoidCallback onDelete;

  const _DeletableChip({
    required this.label,
    required this.onDelete
  });

  @override
  State<_DeletableChip> createState() => _DeletableChipState();
}

class _DeletableChipState extends State<_DeletableChip>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration:   const Duration(milliseconds: 150),
        padding:    const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color:        _isHovered ? AppTheme.surfaceHover : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border:       Border.all(color: AppTheme.border, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize:   14,
                fontWeight: FontWeight.w600,
                color:      AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding:    const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size:  16,
                    color: AppTheme.danger,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownOption<T>
{
  final T?     value;
  final String label;
  final bool   isSeparator;

  _DropdownOption({
    this.value,
    this.label       = '',
    this.isSeparator = false
  });
}

class _DialogDropdownMenu<T> extends StatefulWidget
{
  final String                   hint;
  final T?                       value;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T?>         onChanged;

  const _DialogDropdownMenu({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_DialogDropdownMenu<T>> createState() => _DialogDropdownMenuState<T>();
}

class _DialogDropdownMenuState<T> extends State<_DialogDropdownMenu<T>>
{
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry?   _overlayEntry;

  final GlobalKey<_DialogDropdownOverlayState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size      = renderBox.size;
    final offset    = renderBox.localToGlobal(Offset.zero);
    final screenH   = MediaQuery.of(context).size.height;

    final spaceBottom = screenH - offset.dy - size.height;
    final spaceTop    = offset.dy;
    final showAbove   = spaceBottom < 250 && spaceTop > spaceBottom;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:    _closeMenu,
              child:    Container(),
            ),
          ),
          Positioned(
            top:    showAbove ? null : offset.dy + size.height + 8,
            bottom: showAbove ? screenH - offset.dy + 8 : null,
            left:   offset.dx,
            width:  size.width,
            child: _DialogDropdownOverlay<T>(
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              showAbove:    showAbove,
              onSelected:   (val)
              {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _closeMenu() async
  {
    if (_overlayEntry != null)
    {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted)
      {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final selectedOption = widget.options.firstWhere(
      (o) => !o.isSeparator && o.value == widget.value,
      orElse: () => _DropdownOption(value: widget.value, label: widget.hint),
    );

    final String displayText = selectedOption.label;
    final bool   isExpanded  = _overlayEntry != null;

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key:        _buttonKey,
          duration:   const Duration(milliseconds: 200),
          height:     50,
          padding:    const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered || isExpanded ? AppTheme.surfaceHover : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered || isExpanded ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   15,
                    fontWeight: FontWeight.w600,
                    color:      Colors.black87,
                  ),
                ),
              ),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogDropdownOverlay<T> extends StatefulWidget
{
  final T?                       currentValue;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T?>         onSelected;
  final bool                     showAbove;

  const _DialogDropdownOverlay({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    this.showAbove = false,
  });

  @override
  State<_DialogDropdownOverlay<T>> createState() => _DialogDropdownOverlayState<T>();
}

class _DialogDropdownOverlayState<T> extends State<_DialogDropdownOverlay<T>>
{
  bool                   _expanded         = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> hide() async
  {
    if (mounted)
    {
      setState(() => _expanded = false);
    }
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: AnimatedSize(
          duration:  const Duration(milliseconds: 180),
          curve:     Curves.easeOut,
          alignment: widget.showAbove ? Alignment.bottomCenter : Alignment.topCenter,
          child:     _expanded
              ? ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: RawScrollbar(
                    controller:      _scrollController,
                    thumbVisibility: true,
                    thickness:       6,
                    radius:          const Radius.circular(10),
                    thumbColor:      AppTheme.hint,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding:    const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize:       MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:           widget.options.map((option)
                        {
                          if (option.isSeparator)
                          {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical:   4.0,
                              ),
                              child: Divider(
                                height:    1,
                                thickness: 1,
                                color:     AppTheme.divider,
                              ),
                            );
                          }

                          return _DialogDropdownItem(
                            text:       option.label,
                            isSelected: widget.currentValue == option.value,
                            onTap:      () => widget.onSelected(option.value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                )
              : const SizedBox(height: 0, width: double.infinity),
        ),
      ),
    );
  }
}

class _DialogDropdownItem extends StatefulWidget
{
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const _DialogDropdownItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DialogDropdownItem> createState() => _DialogDropdownItemState();
}

class _DialogDropdownItemState extends State<_DialogDropdownItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color:   Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration:   const Duration(milliseconds: 150),
                width:      2,
                height:     (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color:        AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style:    GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:      AppTheme.primary,
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