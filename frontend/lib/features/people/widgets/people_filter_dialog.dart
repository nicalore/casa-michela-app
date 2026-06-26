import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/shared_components.dart';
import '../models/people_filter_state.dart';

class PeopleFilterDialog extends StatefulWidget {
  final PeopleFilterState initialState;
  final List<String> availableCities;
  final List<String> availableSchools;
  final List<String> availableStudyPrograms;
  final List<String> availableSubjects;
  final ValueChanged<PeopleFilterState> onApply;

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

class _PeopleFilterDialogState extends State<PeopleFilterDialog> {
  late PeopleFilterState _currentState;

  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _studyProgramController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _courseTypeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
  void initState() {
    super.initState();
    _currentState = widget.initialState;

    _cityController.text = _currentState.city ?? '';
    _schoolController.text = _currentState.schoolName ?? '';
    _studyProgramController.text = _currentState.studyProgram ?? '';
    _subjectController.text = '';
    _courseTypeController.text = _currentState.courseType ?? '';
  }

  @override
  void dispose() {
    _cityController.dispose();
    _schoolController.dispose();
    _studyProgramController.dispose();
    _subjectController.dispose();
    _courseTypeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleRole(String role, bool isSelected) {
    setState(() {
      List<String> updatedRoles = List.from(_currentState.selectedRoles);
      if (isSelected) {
        updatedRoles.add(role);
      } else {
        updatedRoles.remove(role);
      }
      _currentState = _currentState.copyWith(
        selectedRoles: updatedRoles,
        clearRoles: updatedRoles.isEmpty,
      );
    });
  }

  void _addSubject(String subject) {
    String s = subject.trim();
    if (s.isEmpty || _currentState.taughtSubjects.contains(s)) return;

    setState(() {
      List<String> updated = List.from(_currentState.taughtSubjects)..add(s);
      _currentState = _currentState.copyWith(taughtSubjects: updated);
    });
  }

  void _removeSubject(String subject) {
    setState(() {
      List<String> updated = List.from(_currentState.taughtSubjects)
        ..remove(subject);
      _currentState = _currentState.copyWith(
        taughtSubjects: updated,
        clearTaughtSubjects: updated.isEmpty,
      );
    });
  }

  void _resetFilters() {
    setState(() {
      _currentState = const PeopleFilterState();
      _cityController.clear();
      _schoolController.clear();
      _studyProgramController.clear();
      _subjectController.clear();
      _courseTypeController.clear();
    });
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF003C82),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E5EC)),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF003C82),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    ValueChanged<String> onChanged, {
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5EC), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (val) {
                setState(() {});
                onChanged(val);
              },
              onSubmitted: onSubmitted,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFB3B3B3),
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = _currentState.selectedRoles;

    final bool showParentFilters = roles.contains('Genitore');
    // Mostra filtri associato solo se c'è almeno un ruolo selezionato e se c'è un ruolo diverso da Genitore
    final bool showAssociateFilters =
        roles.isNotEmpty && roles.any((r) => r != 'Genitore');
    final bool showStudentFilters = roles.contains('Studente');
    final bool showStaffFilters = roles.any(
      (r) => ['Amministratore', 'Docente', 'Psicologo'].contains(r),
    );
    final bool showTeacherFilters = roles.contains('Docente');
    final bool showCourseFilters = roles.contains('Corsista');

    final bool isFullAgeRange =
        _currentState.ageRange == null ||
        (_currentState.ageRange!.start == 5 &&
            _currentState.ageRange!.end == 99);
    final bool isFullSubjectRange =
        _currentState.taughtSubjectsCount == null ||
        (_currentState.taughtSubjectsCount!.start == 1 &&
            _currentState.taughtSubjectsCount!.end == 15);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 540,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
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
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF003C82),
                    ),
                  ),
                  StaticHoverIconButton(
                    icon: Icons.close,
                    color: const Color(0xFF003C82),
                    hoverColor: const Color(0xFFE3F2FD),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(10),
                  thumbColor: const Color(0xFFB3B3B3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: 32,
                      right: 32,
                      bottom: 24,
                      top: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Ruoli'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableRoles.map((role) {
                            return CustomChip(
                              label: role,
                              isSelected: _currentState.selectedRoles.contains(
                                role,
                              ),
                              onSelected: (val) => _toggleRole(role, val),
                            );
                          }).toList(),
                        ),

                        _buildSectionTitle('Generali'),
                        _buildFieldLabel('Città di residenza'),
                        _AutocompleteField(
                          controller: _cityController,
                          hint: 'Es. Thiene',
                          options: widget.availableCities,
                          onChanged: (val) => setState(
                            () => _currentState = _currentState.copyWith(
                              city: val,
                              clearCity: val.isEmpty,
                            ),
                          ),
                        ),

                        _buildFieldLabel('Fascia di età'),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF003C82),
                            inactiveTrackColor: const Color(0xFFE0E5EC),
                            thumbColor: const Color(0xFF003C82),
                            valueIndicatorColor: const Color(0xFF003C82),
                            overlayShape: SliderComponentShape.noOverlay,
                            valueIndicatorTextStyle:
                                GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          child: RangeSlider(
                            values:
                                _currentState.ageRange ??
                                const RangeValues(5, 99),
                            min: 5,
                            max: 99,
                            divisions: 94,
                            labels: RangeLabels(
                              _currentState.ageRange?.start
                                      .round()
                                      .toString() ??
                                  '5',
                              _currentState.ageRange?.end.round() == 99
                                  ? '99+'
                                  : _currentState.ageRange?.end
                                            .round()
                                            .toString() ??
                                        '99+',
                            ),
                            onChanged: (RangeValues values) {
                              setState(
                                () => _currentState = _currentState.copyWith(
                                  ageRange: values,
                                ),
                              );
                            },
                          ),
                        ),
                        Center(
                          child: Text(
                            isFullAgeRange
                                ? 'Tutte le età'
                                : '${_currentState.ageRange!.start.round()} - ${_currentState.ageRange!.end.round() == 99 ? '99+' : _currentState.ageRange!.end.round()} anni',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showParentFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Genitore'),
                                    _buildFieldLabel('Numero figli associati'),
                                    _DialogDropdownMenu<String?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState.childrenCount,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(value: '1', label: '1'),
                                        _DropdownOption(value: '2', label: '2'),
                                        _DropdownOption(value: '3', label: '3'),
                                        _DropdownOption(
                                          value: '4+',
                                          label: '4 o più',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              childrenCount: val,
                                              clearChildrenCount: val == null,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showAssociateFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Associato'),
                                    _buildFieldLabel('Stato collaborazione'),
                                    _DialogDropdownMenu<bool?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState.isActiveCollaborator,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(
                                          value: true,
                                          label: 'Attiva',
                                        ),
                                        _DropdownOption(
                                          value: false,
                                          label: 'Inattiva',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              isActiveCollaborator: val,
                                              clearCollaborator: val == null,
                                            ),
                                      ),
                                    ),
                                    _buildFieldLabel(
                                      'Anno di prima iscrizione',
                                    ),
                                    _DialogDropdownMenu<String?>(
                                      hint: 'Qualsiasi anno',
                                      value: _currentState.enrollmentYear,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi anno',
                                        ),
                                        _DropdownOption(
                                          value: '2026',
                                          label: '2026',
                                        ),
                                        _DropdownOption(
                                          value: '2025',
                                          label: '2025',
                                        ),
                                        _DropdownOption(
                                          value: '2024',
                                          label: '2024',
                                        ),
                                        _DropdownOption(
                                          value: '2023',
                                          label: '2023',
                                        ),
                                        _DropdownOption(
                                          value: '2022',
                                          label: '2022',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              enrollmentYear: val,
                                              clearEnrollment: val == null,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showStudentFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Studente'),
                                    _buildFieldLabel('Livello di istruzione'),
                                    _DialogDropdownMenu<String?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState.educationLevel,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(
                                          value: 'Scuola Primaria',
                                          label: 'Scuola Primaria',
                                        ),
                                        _DropdownOption(
                                          value: 'Secondaria I grado',
                                          label: 'Secondaria I grado',
                                        ),
                                        _DropdownOption(
                                          value: 'Secondaria II grado',
                                          label: 'Secondaria II grado',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              educationLevel: val,
                                              clearEducationLevel: val == null,
                                            ),
                                      ),
                                    ),
                                    _buildFieldLabel('Scuola frequentata'),
                                    _AutocompleteField(
                                      controller: _schoolController,
                                      hint: 'Es. Liceo F. Corradini',
                                      options: widget.availableSchools,
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              schoolName: val,
                                              clearSchoolName: val.isEmpty,
                                            ),
                                      ),
                                    ),
                                    _buildFieldLabel('Classe'),
                                    _DialogDropdownMenu<String?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState.schoolClass,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(value: 'I', label: 'I'),
                                        _DropdownOption(
                                          value: 'II',
                                          label: 'II',
                                        ),
                                        _DropdownOption(
                                          value: 'III',
                                          label: 'III',
                                        ),
                                        _DropdownOption(
                                          value: 'IV',
                                          label: 'IV',
                                        ),
                                        _DropdownOption(value: 'V', label: 'V'),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              schoolClass: val,
                                              clearSchoolClass: val == null,
                                            ),
                                      ),
                                    ),
                                    _buildFieldLabel('Indirizzo di studio'),
                                    _AutocompleteField(
                                      controller: _studyProgramController,
                                      hint: 'Es. Liceo Scientifico',
                                      options: widget.availableStudyPrograms,
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              studyProgram: val,
                                              clearStudyProgram: val.isEmpty,
                                            ),
                                      ),
                                    ),
                                    _buildFieldLabel('Uscita anticipata'),
                                    _DialogDropdownMenu<bool?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState.earlyExit,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(
                                          value: true,
                                          label: 'Sì',
                                        ),
                                        _DropdownOption(
                                          value: false,
                                          label: 'No',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              earlyExit: val,
                                              clearEarlyExit: val == null,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showStaffFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Staff'),
                                    _buildFieldLabel('Tipo collaborazione'),
                                    _DialogDropdownMenu<String?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState.collaborationType,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(
                                          value: 'Volontario',
                                          label: 'Volontario',
                                        ),
                                        _DropdownOption(
                                          value: 'Retribuito',
                                          label: 'Retribuito',
                                        ),
                                        _DropdownOption(
                                          value: 'PCTO',
                                          label: 'PCTO',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              collaborationType: val,
                                              clearCollaborationType:
                                                  val == null,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showTeacherFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Docente'),
                                    _buildFieldLabel('Discipline insegnate'),
                                    _AutocompleteField(
                                      controller: _subjectController,
                                      hint: 'Scrivi la disciplina e premi Invio',
                                      options: widget.availableSubjects,
                                      onChanged: (_) {},
                                      onSubmitted: _addSubject,
                                    ),
                                    if (_currentState
                                        .taughtSubjects
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _currentState.taughtSubjects
                                            .map((s) {
                                              return _DeletableChip(
                                                label: s,
                                                onDelete: () =>
                                                    _removeSubject(s),
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ],
                                    _buildFieldLabel(
                                      'Numero materie insegnate',
                                    ),
                                    const SizedBox(height: 8),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: const Color(
                                          0xFF003C82,
                                        ),
                                        inactiveTrackColor: const Color(
                                          0xFFE0E5EC,
                                        ),
                                        thumbColor: const Color(0xFF003C82),
                                        valueIndicatorColor: const Color(
                                          0xFF003C82,
                                        ),
                                        overlayShape:
                                            SliderComponentShape.noOverlay,
                                        valueIndicatorTextStyle:
                                            GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      child: RangeSlider(
                                        values:
                                            _currentState.taughtSubjectsCount ??
                                            const RangeValues(1, 15),
                                        min: 1,
                                        max: 15,
                                        divisions: 14,
                                        labels: RangeLabels(
                                          _currentState
                                                  .taughtSubjectsCount
                                                  ?.start
                                                  .round()
                                                  .toString() ??
                                              '1',
                                          _currentState.taughtSubjectsCount?.end
                                                      .round() ==
                                                  15
                                              ? '15+'
                                              : _currentState
                                                        .taughtSubjectsCount
                                                        ?.end
                                                        .round()
                                                        .toString() ??
                                                    '15+',
                                        ),
                                        onChanged: (RangeValues values) {
                                          setState(
                                            () => _currentState = _currentState
                                                .copyWith(
                                                  taughtSubjectsCount: values,
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        isFullSubjectRange
                                            ? 'Qualsiasi'
                                            : '${_currentState.taughtSubjectsCount!.start.round()} - ${_currentState.taughtSubjectsCount!.end.round() == 15 ? '15+' : _currentState.taughtSubjectsCount!.end.round()} materie',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showCourseFilters
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle('Filtri Corsista'),
                                    _buildFieldLabel('Tipo di corso'),
                                    _buildTextField(
                                      _courseTypeController,
                                      'Es. Yoga',
                                      (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              courseType: val,
                                              clearCourseType: val.isEmpty,
                                            ),
                                      ),
                                    ),
                                    _buildFieldLabel('Certificato medico'),
                                    _DialogDropdownMenu<bool?>(
                                      hint: 'Qualsiasi',
                                      value: _currentState
                                          .isMedicalCertificateValid,
                                      options: [
                                        _DropdownOption(
                                          value: null,
                                          label: 'Qualsiasi',
                                        ),
                                        _DropdownOption(
                                          value: true,
                                          label: 'Non scaduto',
                                        ),
                                        _DropdownOption(
                                          value: false,
                                          label: 'Scaduto',
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _currentState = _currentState
                                            .copyWith(
                                              isMedicalCertificateValid: val,
                                              clearMedicalCert: val == null,
                                            ),
                                      ),
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
            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'AZZERA',
                      icon: Icons.refresh_rounded,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: _resetFilters,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'APPLICA',
                      icon: Icons.check_circle_outline_rounded,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
                      onPressed: () {
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

// ---------------------------------------------------------
// COMPONENTI LOCALI
// ---------------------------------------------------------

class _AutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

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

class _AutocompleteFieldState extends State<_AutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty)
          return const Iterable<String>.empty();
        return widget.options.where(
          (String option) => option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          ),
        );
      },
      onSelected: (String selection) {
        if (widget.onSubmitted != null) {
          widget.onSubmitted!(selection);
          Future.microtask(() => widget.controller.clear());
        } else {
          widget.onChanged(selection);
        }
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return Container(
              height: 50,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E5EC), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      onChanged: (val) {
                        setState(() {});
                        widget.onChanged(val);
                      },
                      onSubmitted: (val) {
                        if (widget.onSubmitted != null)
                          widget.onSubmitted!(val);
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFB3B3B3),
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  if (textEditingController.text.isNotEmpty)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          textEditingController.clear();
                          widget.onChanged('');
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE53935,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return _AutocompleteOptionsList(
              options: options,
              onSelected: onSelected,
            );
          },
    );
  }
}

class _AutocompleteOptionsList extends StatefulWidget {
  final Iterable<String> options;
  final AutocompleteOnSelected<String> onSelected;

  const _AutocompleteOptionsList({
    required this.options,
    required this.onSelected,
  });

  @override
  State<_AutocompleteOptionsList> createState() =>
      _AutocompleteOptionsListState();
}

class _AutocompleteOptionsListState extends State<_AutocompleteOptionsList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 436,
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              thumbColor: const Color(0xFFB3B3B3),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: widget.options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = widget.options.elementAt(index);
                  return _DialogDropdownItem(
                    text: option,
                    isSelected: false,
                    onTap: () => widget.onSelected(option),
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

class _DeletableChip extends StatefulWidget {
  final String label;
  final VoidCallback onDelete;

  const _DeletableChip({required this.label, required this.onDelete});

  @override
  State<_DeletableChip> createState() => _DeletableChipState();
}

class _DeletableChipState extends State<_DeletableChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF5F8FC) : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFFE0E5EC), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF003C82),
              ),
            ),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFFE53935),
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

class CustomChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const CustomChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  @override
  State<CustomChip> createState() => _CustomChipState();
}

class _CustomChipState extends State<CustomChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF003C82)
                : (_isHovered ? const Color(0xFFF5F8FC) : Colors.white),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF003C82)
                  : const Color(0xFFE0E5EC),
              width: 1.0,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? Colors.white : const Color(0xFF003C82),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _DropdownOption<T> {
  final T? value;
  final String label;
  final bool isSeparator;

  _DropdownOption({this.value, this.label = '', this.isSeparator = false});
}

class _DialogDropdownMenu<T> extends StatefulWidget {
  final String hint;
  final T? value;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T?> onChanged;

  const _DialogDropdownMenu({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_DialogDropdownMenu<T>> createState() => _DialogDropdownMenuState<T>();
}

class _DialogDropdownMenuState<T> extends State<_DialogDropdownMenu<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  final GlobalKey<_DialogDropdownOverlayState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }

    final renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenH = MediaQuery.of(context).size.height;

    final spaceBottom = screenH - offset.dy - size.height;
    final spaceTop = offset.dy;
    final showAbove = spaceBottom < 250 && spaceTop > spaceBottom;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: Container(),
            ),
          ),
          Positioned(
            top: showAbove ? null : offset.dy + size.height + 8,
            bottom: showAbove ? screenH - offset.dy + 8 : null,
            left: offset.dx,
            width: size.width,
            child: _DialogDropdownOverlay<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              showAbove: showAbove,
              onSelected: (val) {
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

  void _closeMenu() async {
    if (_overlayEntry != null) {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = widget.options.firstWhere(
      (o) => !o.isSeparator && o.value == widget.value,
      orElse: () => _DropdownOption(value: widget.value, label: widget.hint),
    );
    final String displayText = selectedOption.label;
    final bool isExpanded = _overlayEntry != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered || isExpanded
                ? const Color(0xFFF5F8FC)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered || isExpanded
                  ? const Color(0xFF003C82)
                  : const Color(0xFFE0E5EC),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF003C82),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogDropdownOverlay<T> extends StatefulWidget {
  final T? currentValue;
  final List<_DropdownOption<T>> options;
  final ValueChanged<T?> onSelected;
  final bool showAbove;

  const _DialogDropdownOverlay({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    this.showAbove = false,
  });

  @override
  State<_DialogDropdownOverlay<T>> createState() =>
      _DialogDropdownOverlayState<T>();
}

class _DialogDropdownOverlayState<T> extends State<_DialogDropdownOverlay<T>> {
  bool _expanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _expanded = true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> hide() async {
    if (mounted) setState(() => _expanded = false);
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: widget.showAbove
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          child: _expanded
              ? ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    thumbColor: const Color(0xFFB3B3B3),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.options.map((option) {
                          if (option.isSeparator) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF0F0F0),
                              ),
                            );
                          }

                          return _DialogDropdownItem(
                            text: option.label,
                            isSelected: widget.currentValue == option.value,
                            onTap: () => widget.onSelected(option.value),
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

class _DialogDropdownItem extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _DialogDropdownItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DialogDropdownItem> createState() => _DialogDropdownItemState();
}

class _DialogDropdownItemState extends State<_DialogDropdownItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF003C82),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: const Color(0xFF003C82),
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
