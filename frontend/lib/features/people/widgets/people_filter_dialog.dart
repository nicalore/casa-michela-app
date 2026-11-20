import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_range_slider.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../models/people_filter_state.dart';

class PeopleFilterDialog extends StatefulWidget
{
  final PeopleFilterState                 initialState;
  final List<String>                      availableBirthNations;
  final List<String>                      availableBirthCities;
  final List<String>                      availableCities;
  final List<String>                      availableSchools;
  final List<String>                      availableStudyPrograms;
  final List<String>                      availableSubjects;
  final ValueChanged<PeopleFilterState>   onApply;

  // For a list holding only these roles: no roles filter, their sections always shown.
  final List<String>?                     fixedRoles;

  final String?                           eyebrow;
  final bool                              enrollmentFilter;
  final bool                              earlyExitFilter;
  final bool                              methodologicalNotesFilter;

  const PeopleFilterDialog({
    super.key,
    required this.initialState,
    required this.availableBirthNations,
    required this.availableBirthCities,
    required this.availableCities,
    required this.availableSchools,
    required this.availableStudyPrograms,
    required this.availableSubjects,
    required this.onApply,
    this.fixedRoles,
    this.eyebrow,
    this.enrollmentFilter = true,
    this.earlyExitFilter = true,
    this.methodologicalNotesFilter = false,
  });

  @override
  State<PeopleFilterDialog> createState() => _PeopleFilterDialogState();
}

// The chip's words for a role the filter keeps in Italian.
String _roleLabel(String role) => switch (role)
{
  'Amministratore' => tr('Amministratore', 'Administrator'),
  'Docente' => tr('Docente', 'Teacher'),
  'Psicologo' => tr('Psicologo', 'Psychologist'),
  'Genitore' => tr('Genitore', 'Parent'),
  'Associato' => tr('Associato', 'Member'),
  'Studente' => tr('Studente', 'Student'),
  'Corsista' => tr('Corsista', 'Course participant'),
  _ => role,
};

class _PeopleFilterDialogState extends State<PeopleFilterDialog>
{
  static const double _cardWidth = 560;

  int _card = 0;
  bool _movingForward = true;

  late PeopleFilterState _currentState;

  final TextEditingController _birthNationController  = TextEditingController();
  final TextEditingController _birthCityController    = TextEditingController();
  final TextEditingController _cityController         = TextEditingController();
  final TextEditingController _schoolController       = TextEditingController();
  final TextEditingController _studyProgramController = TextEditingController();
  final TextEditingController _subjectController      = TextEditingController();
  final TextEditingController _courseTypeController   = TextEditingController();
  final ScrollController      _scrollController       = ScrollController();

  // Italian, as the server names them: the filter compares them with each person's roles.
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

    _courseTypeController.text   = _currentState.courseType     ?? '';
  }

  @override
  void dispose()
  {
    _birthNationController.dispose();
    _birthCityController.dispose();
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

  void _setBirthPlace(String? place)
  {
    setState(()
    {
      _currentState = _currentState.copyWith(
        birthPlace:        place,
        clearBirthPlace:   place == null,
        clearBirthNations: place != PeopleFilterState.bornAbroad,
      );

      if (place != PeopleFilterState.bornAbroad)
      {
        _birthNationController.clear();
      }
    });
  }

  void _resetFilters()
  {
    setState(()
    {
      _currentState = const PeopleFilterState();

      _birthNationController.clear();
      _birthCityController.clear();
      _cityController.clear();
      _schoolController.clear();
      _studyProgramController.clear();
      _subjectController.clear();
      _courseTypeController.clear();
    });
  }

  // No chip selected means "any".
  Widget _buildChoiceChips<T>({
    required T? value,
    required List<(T, String)> options,
    required ValueChanged<T?> onChanged,
  })
  {
    return Wrap(
      spacing:    10,
      runSpacing: 10,
      children: [
        for (final (option, label) in options)
          AppSelectableChip(
            label: label,
            selected: value == option,
            onSelected: (selected) => onChanged(selected ? option : null),
          ),
      ],
    );
  }

  Widget _buildMultiChips({
    required List<String> values,
    required List<(String, String)> options,
    required ValueChanged<List<String>> onChanged,
  })
  {
    return Wrap(
      spacing:    10,
      runSpacing: 10,
      children: [
        for (final (option, label) in options)
          AppSelectableChip(
            label: label,
            selected: values.contains(option),
            onSelected: (selected) => onChanged(
              selected
                  ? [...values, option]
                  : [for (final value in values) if (value != option) value],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildMultiAutocomplete({
    required TextEditingController controller,
    required String hint,
    required List<String> options,
    required List<String> values,
    required void Function(List<String> values) onChanged,
  })
  {
    return [
      _AutocompleteField(
        controller:  controller,
        hint:        hint,
        options:     [for (final option in options) if (!values.contains(option)) option],
        onChanged:   (_) {},
        onSubmitted: (picked)
        {
          final value = picked.trim();

          if (options.contains(value) && !values.contains(value))
          {
            setState(() => onChanged([...values, value]));
          }
        },
      ),
      if (values.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing:    8,
          runSpacing: 8,
          children: [
            for (final value in values)
              AppDeletableChip(
                label:    value,
                onDelete: () => setState(() => onChanged([for (final kept in values) if (kept != value) kept])),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: AppFieldLabel(text),
    );
  }

  // Marker consumed by _cardsOf: the body is cut into cards at these.
  Widget _buildSectionTitle(String title) => _SectionBreak(title);

  // Marker: starts a new piece on the same card.
  Widget _buildPillBreak() => const _PillBreak();

  List<Widget> _cardsOf(List<Widget> parts)
  {
    final cards = <Widget>[];

    var pieces = <Widget>[];
    var current = <Widget>[];
    String? title;

    void closePiece()
    {
      if (current.every((part) => part is SizedBox))
      {
        current = [];

        return;
      }

      final heading = pieces.isEmpty ? title : null;

      pieces.add(AppDialogPill(
        expand: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heading != null) ...[
              Text(
                heading.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: AppTheme.trialMutedText,
                ),
              ),
              const SizedBox(height: 4),
            ],
            ...current,
          ],
        ),
      ));

      current = [];
    }

    void closeCard()
    {
      closePiece();

      if (pieces.isEmpty)
      {
        return;
      }

      cards.add(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < pieces.length; i++) ...[
            if (i > 0) const SizedBox(height: _pieceGap),
            // Index 0 is the title and 1 the body, so pieces start at 1.
            AppDialogPiece(index: 1 + i, named: false, child: pieces[i]),
          ],
        ],
      ));

      pieces = [];
    }

    for (final part in parts)
    {
      if (part is _SectionBreak)
      {
        closeCard();
        title = part.title;

        continue;
      }

      if (part is _PillBreak)
      {
        closePiece();

        continue;
      }

      current.add(part);
    }

    closeCard();

    return cards;
  }

  void _goToCard(int card)
  {
    setState(()
    {
      _movingForward = card > _card;
      _card = card;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final roles = widget.fixedRoles ?? _currentState.selectedRoles;

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

    return AppDialogStack(
      eyebrow: widget.eyebrow ?? tr('Persone', 'People'),
      title: tr('Filtri di ricerca', 'Search filters'),
      maxWidth: _cardWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap),
      footer: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppDialogFooter(
          secondary: AppGradientButton(
            label: tr('AZZERA', 'RESET'),
            icon: Icons.refresh_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDangerText,
            height: 52,
            fontSize: 14,
            onPressed: _resetFilters,
          ),
          primary: AppGradientButton(
            label: tr('APPLICA', 'APPLY'),
            icon: Icons.check_rounded,
            height: 52,
            fontSize: 14,
            onPressed: ()
            {
              widget.onApply(_currentState);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      children: [_buildCarousel([
                        _buildSectionTitle(tr('Generali', 'General')),
                        if (widget.fixedRoles == null) ...[
                          _buildFieldLabel(tr('Ruoli', 'Roles')),
                          Wrap(
                            spacing:    10,
                            runSpacing: 10,
                            children:   _availableRoles.map((role)
                            {
                              return AppSelectableChip(
                                label: _roleLabel(role),
                                selected: _currentState.selectedRoles.contains(role),
                                onSelected: (val) => _toggleRole(role, val),
                              );
                            }).toList(),
                          ),

                          _buildPillBreak(),
                        ],
                        _buildFieldLabel(tr('Nazione di nascita', 'Country of birth')),
                        _buildChoiceChips<String>(
                          value: _currentState.birthPlace,
                          options: [
                            (PeopleFilterState.bornInItaly, tr('Italia', 'Italy')),
                            (PeopleFilterState.bornAbroad, tr('Estero', 'Abroad')),
                          ],
                          onChanged: _setBirthPlace,
                        ),
                        if (_currentState.birthPlace == PeopleFilterState.bornAbroad) ...[
                          const SizedBox(height: 12),
                          ..._buildMultiAutocomplete(
                            controller: _birthNationController,
                            hint:       tr('Es. Romania', 'E.g. Romania'),
                            options:    widget.availableBirthNations,
                            values:     _currentState.birthNations,
                            onChanged:  (values) => _currentState = _currentState.copyWith(
                              birthNations:      values,
                              clearBirthNations: values.isEmpty,
                            ),
                          ),
                        ],

                        _buildFieldLabel(tr('Città di nascita', 'City of birth')),
                        ..._buildMultiAutocomplete(
                          controller: _birthCityController,
                          hint:       tr('Es. Thiene', 'E.g. Thiene'),
                          options:    widget.availableBirthCities,
                          values:     _currentState.birthCities,
                          onChanged:  (values) => _currentState = _currentState.copyWith(
                            birthCities:      values,
                            clearBirthCities: values.isEmpty,
                          ),
                        ),

                        _buildFieldLabel(tr('Città di residenza', 'City of residence')),
                        ..._buildMultiAutocomplete(
                          controller: _cityController,
                          hint:       tr('Es. Thiene', 'E.g. Thiene'),
                          options:    widget.availableCities,
                          values:     _currentState.cities,
                          onChanged:  (values) => _currentState = _currentState.copyWith(
                            cities:      values,
                            clearCities: values.isEmpty,
                          ),
                        ),

                        _buildFieldLabel(tr('Fascia di età', 'Age range')),
                        const SizedBox(height: 8),
                        AppRangeSlider(
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
                        Center(
                          child: Text(
                            isFullAgeRange
                                ? tr('Tutte le età', 'All ages')
                                : '${_currentState.ageRange!.start.round()} - ${_currentState.ageRange!.end.round() == 99 ? '99+' : _currentState.ageRange!.end.round()} ${tr('anni', 'years')}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   14,
                              color:      AppTheme.trialMutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        if (showParentFilters) ...[
                          _buildSectionTitle(tr('Filtri Genitore', 'Parent filters')),
                          _buildFieldLabel(tr('Numero figli associati', 'Number of member children')),
                          _buildChoiceChips<String>(
                            value: _currentState.childrenCount,
                            options: [('1', '1'), ('2', '2'), ('3', '3'), ('4+', tr('4 o più', '4 or more'))],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                childrenCount:      val,
                                clearChildrenCount: val == null,
                              );
                            }),
                          ),
                        ],

                        if (showAssociateFilters) ...[
                          _buildSectionTitle(tr('Filtri Associato', 'Member filters')),
                          if (widget.enrollmentFilter) ...[
                            _buildFieldLabel(tr('Stato iscrizione', 'Enrolment status')),
                            _buildChoiceChips<bool>(
                              value: _currentState.isEnrolled,
                              options: [(true, tr('Iscritto', 'Enrolled')), (false, tr('Non iscritto', 'Not enrolled'))],
                              onChanged: (val) => setState(()
                              {
                                _currentState = _currentState.copyWith(
                                  isEnrolled:    val,
                                  clearEnrolled: val == null,
                                );
                              }),
                            ),
                          ],
                          _buildFieldLabel(tr('Stato collaborazione', 'Collaboration status')),
                          _buildChoiceChips<bool>(
                            value: _currentState.isActiveCollaborator,
                            options: [(true, tr('Attiva', 'Active')), (false, tr('Inattiva', 'Inactive'))],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                isActiveCollaborator: val,
                                clearCollaborator:    val == null,
                              );
                            }),
                          ),
                          _buildFieldLabel(tr('Anno di prima iscrizione', 'Year of first enrolment')),
                          AppDropdownField<String?>(
                            hint:    tr('Qualsiasi anno', 'Any year'),
                            value:   _currentState.enrollmentYear,
                            options: [
                              AppDropdownOption(value: null,   label: tr('Qualsiasi anno', 'Any year')),
                              AppDropdownOption(value: '2026', label: '2026'),
                              AppDropdownOption(value: '2025', label: '2025'),
                              AppDropdownOption(value: '2024', label: '2024'),
                              AppDropdownOption(value: '2023', label: '2023'),
                              AppDropdownOption(value: '2022', label: '2022'),
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

                        if (showStudentFilters) ...[
                          _buildSectionTitle(tr('Filtri Studente', 'Student filters')),
                          _buildFieldLabel(tr('Livello di istruzione', 'Education level')),
                          _buildChoiceChips<String>(
                            value: _currentState.educationLevel,
                            options: [('Scuola primaria', tr('Primaria', 'Primary school')),
                              ('Scuola secondaria di I grado', tr('Secondaria I grado', 'Lower secondary')),
                              ('Scuola secondaria di II grado', tr('Secondaria II grado', 'Upper secondary'))],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                educationLevel:      val,
                                clearEducationLevel: val == null,
                              );
                            }),
                          ),
                          _buildFieldLabel(tr('Scuola frequentata', 'School attended')),
                          ..._buildMultiAutocomplete(
                            controller: _schoolController,
                            hint:       tr('Es. Liceo Statale "F. Corradini"', 'E.g. Liceo Statale "F. Corradini"'),
                            options:    widget.availableSchools,
                            values:     _currentState.schoolNames,
                            onChanged:  (values) => _currentState = _currentState.copyWith(
                              schoolNames:      values,
                              clearSchoolNames: values.isEmpty,
                            ),
                          ),
                          _buildFieldLabel(tr('Classe', 'Class')),
                          _buildChoiceChips<String>(
                            value: _currentState.schoolClass,
                            options: const [('I', 'I'), ('II', 'II'), ('III', 'III'), ('IV', 'IV'), ('V', 'V')],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                schoolClass:      val,
                                clearSchoolClass: val == null,
                              );
                            }),
                          ),
                          _buildFieldLabel(tr('Indirizzo di studio', 'Course of study')),
                          ..._buildMultiAutocomplete(
                            controller: _studyProgramController,
                            hint:       tr('Es. Amministrazione, finanza e marketing', 'E.g. Amministrazione, finanza e marketing'),
                            options:    widget.availableStudyPrograms,
                            values:     _currentState.studyPrograms,
                            onChanged:  (values) => _currentState = _currentState.copyWith(
                              studyPrograms:      values,
                              clearStudyPrograms: values.isEmpty,
                            ),
                          ),
                          _buildFieldLabel(tr('Certificazione', 'Certification')),
                          _buildMultiChips(
                            values: _currentState.certifications,
                            options: [
                              (PeopleFilterState.noCertification, tr('Nessuna', 'None')),
                              ('DSA', tr('DSA', 'SLD')),
                              ('BES', tr('BES', 'SEN')),
                              ('ADHD', 'ADHD'),
                              ('OTHER', tr('Altro', 'Other')),
                            ],
                            onChanged: (values) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                certifications:      values,
                                clearCertifications: values.isEmpty,
                              );
                            }),
                          ),
                          if (widget.earlyExitFilter) ...[
                            _buildFieldLabel(tr('Uscita anticipata', 'Early departure')),
                            _buildChoiceChips<bool>(
                              value: _currentState.earlyExit,
                              options: [(true, tr('Sì', 'Yes')), (false, 'No')],
                              onChanged: (val) => setState(()
                              {
                                _currentState = _currentState.copyWith(
                                  earlyExit:      val,
                                  clearEarlyExit: val == null,
                                );
                              }),
                            ),
                          ],
                          if (widget.methodologicalNotesFilter) ...[
                            _buildFieldLabel(tr('Osservazioni metodologiche', 'Methodological observations')),
                            _buildChoiceChips<bool>(
                              value: _currentState.hasMethodologicalNotes,
                              options: [(true, tr('Presenti', 'Present')), (false, tr('Assenti', 'Absent'))],
                              onChanged: (val) => setState(()
                              {
                                _currentState = _currentState.copyWith(
                                  hasMethodologicalNotes:    val,
                                  clearMethodologicalNotes:  val == null,
                                );
                              }),
                            ),
                          ],
                        ],

                        if (showStaffFilters) ...[
                          _buildSectionTitle(tr('Filtri Staff', 'Staff filters')),
                          _buildFieldLabel(tr('Tipo collaborazione', 'Collaboration type')),
                          _buildChoiceChips<String>(
                            value: _currentState.collaborationType,
                            options: [
                              ('Volontario', tr('Volontario', 'Volunteer')),
                              ('Retribuito', tr('Retribuito', 'Paid')),
                              ('FSL (Ex PCTO)', 'FSL (Ex PCTO)'),
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

                        if (showTeacherFilters) ...[
                          _buildSectionTitle(tr('Filtri Docente', 'Teacher filters')),

                          _buildFieldLabel(tr('Discipline insegnate', 'Disciplines taught')),
                          ..._buildMultiAutocomplete(
                            controller: _subjectController,
                            hint:       tr('Es. Aritmetica', 'E.g. Aritmetica'),
                            options:    widget.availableSubjects,
                            values:     _currentState.taughtSubjects,
                            onChanged:  (values) => _currentState = _currentState.copyWith(
                              taughtSubjects:      values,
                              clearTaughtSubjects: values.isEmpty,
                            ),
                          ),

                          _buildFieldLabel(tr('Numero materie insegnate', 'Number of subjects taught')),
                          const SizedBox(height: 8),
                          AppRangeSlider(
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
                          Center(
                            child: Text(
                              isFullSubjectRange
                                  ? tr('Qualsiasi', 'Any')
                                  : '${_currentState.taughtSubjectsCount!.start.round()} - ${_currentState.taughtSubjectsCount!.end.round() == 15 ? '15+' : _currentState.taughtSubjectsCount!.end.round()} ${tr('materie', 'subjects')}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize:   14,
                                color:      AppTheme.trialMutedText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        if (showCourseFilters) ...[
                          _buildSectionTitle(tr('Filtri Corsista', 'Course participant filters')),
                          _buildFieldLabel(tr('Tipo di corso', 'Course type')),
                          _buildTextField(
                            _courseTypeController,
                            tr('Es. Yoga', 'E.g. Yoga'),
                            (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                courseType:      val,
                                clearCourseType: val.isEmpty,
                              );
                            }),
                          ),
                          _buildFieldLabel(tr('Certificato medico', 'Medical certificate')),
                          _buildChoiceChips<bool>(
                            value: _currentState.isMedicalCertificateValid,
                            options: [(true, tr('Non scaduto', 'Valid')), (false, tr('Scaduto', 'Expired'))],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                isMedicalCertificateValid: val,
                                clearMedicalCert:          val == null,
                              );
                            }),
                          ),
                        ],
      ])],
    );
  }

  Widget _buildTextField(
    TextEditingController  controller,
    String                 hint,
    ValueChanged<String>   onChanged, {
    ValueChanged<String>?  onSubmitted,
  })
  {
    return _HoverFieldBox(builder: (hover) => AnimatedContainer(
      duration: _fieldFade,
      curve: Curves.easeOut,
      height:     50,
      padding:    const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: _fieldSurface,
        borderRadius: BorderRadius.circular(_fieldRadius),
        border: Border.all(
          color: hover ? AppTheme.trialGold : AppTheme.trialLine,
          width: _fieldBorder,
        ),
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
                color:      AppTheme.trialInk,
              ),
              decoration: InputDecoration(
                hintText:    hint,
                hintStyle:   GoogleFonts.plusJakartaSans(
                  fontSize:   15,
                  fontWeight: FontWeight.w500,
                  color:      AppTheme.trialMutedText,
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
    ));
  }

  Widget _buildCarousel(List<Widget> parts)
  {
    final cards = _cardsOf(parts);

    // Ticking a role off can take the card being shown out of existence.
    final card = _card.clamp(0, cards.length - 1);

    return AppCarouselFrame(
      index: card,
      movingForward: _movingForward,
      maxContentWidth: _cardWidth,
      canGoBack: card > 0,
      canGoForward: card < cards.length - 1,
      onBack: () => _goToCard(card - 1),
      onForward: () => _goToCard(card + 1),
      child: cards[card],
    );
  }
}

Color get _fieldSurface => ThemeColours.of(0xFFFBFDFC);
const double _fieldRadius = 14;
const double _fieldBorder = 2;

const Duration _fieldFade = Duration(milliseconds: 180);

const double _pieceGap = 20;

class _HoverFieldBox extends StatefulWidget
{
  final Widget Function(bool hover) builder;

  const _HoverFieldBox({required this.builder});

  @override
  State<_HoverFieldBox> createState() => _HoverFieldBoxState();
}

class _HoverFieldBoxState extends State<_HoverFieldBox>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.builder(_hover),
    );
  }
}

class _PillBreak extends StatelessWidget
{
  const _PillBreak();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SectionBreak extends StatelessWidget
{
  final String title;

  const _SectionBreak(this.title);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

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
  bool _isHovered = false;

  final FocusNode _focusNode = FocusNode();

  bool _isFocused = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged()
  {
    if (_focusNode.hasFocus != _isFocused)
    {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose()
  {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      // Never wider than the field: in a narrow window a fixed width would leave the window.
      builder: (context, constraints) => RawAutocomplete<String>(
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
            // clear() leaves the selection at -1 (no visible cursor): reset it and refocus.
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
          return MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: _fieldFade,
              curve: Curves.easeOut,
              height:     50,
              padding:    const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                color: _fieldSurface,
                borderRadius: BorderRadius.circular(_fieldRadius),
                border: Border.all(
                  color: _isFocused || _isHovered ? AppTheme.trialGold : AppTheme.trialLine,
                  width: _fieldBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.trialGold.withValues(alpha: _isFocused ? 0.15 : 0),
                    spreadRadius: _isFocused ? 4 : 0,
                  ),
                ],
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
                      // Enter confirms RawAutocomplete's highlighted option, never the free text.
                      onSubmitted: (_) => onFieldSubmitted(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        color:      AppTheme.trialInk,
                      ),
                      decoration: InputDecoration(
                        hintText:    widget.hint,
                        hintStyle:   GoogleFonts.plusJakartaSans(
                          fontSize:   15,
                          fontWeight: FontWeight.w500,
                          color:      AppTheme.trialMutedText,
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
                            color:        AppTheme.trialDanger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size:  16,
                            color: AppTheme.trialDangerText,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
        )
        {
          return AutocompleteOptionsList<String>(
            options:    options,
            label:      (option) => option,
            // The overlay does not inherit the field's width; 436 matches the card's fields.
            width:      math.min(436, constraints.maxWidth),
            onSelected: onSelected,
          );
        },
      ),
    );
  }
}
