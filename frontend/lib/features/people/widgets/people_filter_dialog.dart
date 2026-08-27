import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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
  static const double _cardWidth = 560;

  int _card = 0;
  bool _movingForward = true;

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

  // No chip lit means "any"; pressing the lit one switches it off.
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

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: AppFieldLabel(text),
    );
  }

  // Marker, not a heading: _cardsOf cuts the body into cards at these.
  Widget _buildSectionTitle(String title) => _SectionBreak(title);

  // Marker: starts a new piece on the same card.
  Widget _buildPillBreak() => const _PillBreak();

  // Which cards exist changes as roles are ticked, so the card on screen is
  // clamped back into range on every build.
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
            // The stack counts the title as 0 and the body as 1; pieces carry on.
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

    return AppDialogStack(
      eyebrow: 'Persone',
      title: 'Filtri di ricerca',
      maxWidth: _cardWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap),
      footer: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'AZZERA',
            icon: Icons.refresh_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: 52,
            fontSize: 14,
            onPressed: _resetFilters,
          ),
          primary: AppGradientButton(
            label: 'APPLICA',
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
                        _buildSectionTitle('Generali'),
                        _buildFieldLabel('Ruoli'),
                        Wrap(
                          spacing:    10,
                          runSpacing: 10,
                          children:   _availableRoles.map((role)
                          {
                            return AppSelectableChip(
                              label: role,
                              selected: _currentState.selectedRoles.contains(role),
                              onSelected: (val) => _toggleRole(role, val),
                            );
                          }).toList(),
                        ),

                        _buildPillBreak(),
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
                                ? 'Tutte le età'
                                : '${_currentState.ageRange!.start.round()} - ${_currentState.ageRange!.end.round() == 99 ? '99+' : _currentState.ageRange!.end.round()} anni',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   14,
                              color:      AppTheme.trialMutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        if (showParentFilters) ...[
                          _buildSectionTitle('Filtri Genitore'),
                          _buildFieldLabel('Numero figli associati'),
                          _buildChoiceChips<String>(
                            value: _currentState.childrenCount,
                            options: const [('1', '1'), ('2', '2'), ('3', '3'), ('4+', '4 o più')],
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
                          _buildSectionTitle('Filtri Associato'),
                          _buildFieldLabel('Stato collaborazione'),
                          _buildChoiceChips<bool>(
                            value: _currentState.isActiveCollaborator,
                            options: const [(true, 'Attiva'), (false, 'Inattiva')],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                isActiveCollaborator: val,
                                clearCollaborator:    val == null,
                              );
                            }),
                          ),
                          _buildFieldLabel('Anno di prima iscrizione'),
                          AppDropdownField<String?>(
                            hint:    'Qualsiasi anno',
                            value:   _currentState.enrollmentYear,
                            options: [
                              AppDropdownOption(value: null,   label: 'Qualsiasi anno'),
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
                          _buildSectionTitle('Filtri Studente'),
                          _buildFieldLabel('Livello di istruzione'),
                          _buildChoiceChips<String>(
                            value: _currentState.educationLevel,
                            options: const [('Scuola primaria', 'Primaria'),
                              ('Scuola secondaria di I grado', 'Secondaria di I grado'),
                              ('Scuola secondaria di II grado', 'Secondaria di II grado')],
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
                          _buildFieldLabel('Indirizzo di studio'),
                          _AutocompleteField(
                            controller: _studyProgramController,
                            hint:       'Es. Amministrazione finanza e marketing',
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
                          _buildChoiceChips<bool>(
                            value: _currentState.earlyExit,
                            options: const [(true, 'Sì'), (false, 'No')],
                            onChanged: (val) => setState(()
                            {
                              _currentState = _currentState.copyWith(
                                earlyExit:      val,
                                clearEarlyExit: val == null,
                              );
                            }),
                          ),
                        ],

                        if (showStaffFilters) ...[
                          _buildSectionTitle('Filtri Staff'),
                          _buildFieldLabel('Tipo collaborazione'),
                          _buildChoiceChips<String>(
                            value: _currentState.collaborationType,
                            options: const [('Volontario', 'Volontario'), ('Retribuito', 'Retribuito'), ('FSL (Ex PCTO)', 'FSL (Ex PCTO)')],
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
                          _buildSectionTitle('Filtri Docente'),

                          _buildFieldLabel('Discipline insegnate'),
                          _AutocompleteField(
                            controller:  _subjectController,
                            hint:        'Es. Aritmetica',
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
                                return AppDeletableChip(
                                  label:    s,
                                  onDelete: () => _removeSubject(s),
                                );
                              }).toList(),
                            ),
                          ],

                          _buildFieldLabel('Numero materie insegnate'),
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
                                  ? 'Qualsiasi'
                                  : '${_currentState.taughtSubjectsCount!.start.round()} - ${_currentState.taughtSubjectsCount!.end.round() == 15 ? '15+' : _currentState.taughtSubjectsCount!.end.round()} materie',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize:   14,
                                color:      AppTheme.trialMutedText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        if (showCourseFilters) ...[
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
                          _buildChoiceChips<bool>(
                            value: _currentState.isMedicalCertificateValid,
                            options: const [(true, 'Non scaduto'), (false, 'Scaduto')],
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
        // Cannot simply be AppTextField: these fields carry their own suggestions.
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

const Color _fieldSurface = Color(0xFFFBFDFC);
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
                    // Enter confirms RawAutocomplete's highlighted option (arrow-selected or the first result),
                    // never the free text, so only an option that really exists in widget.options can be submitted.
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
                        child: const Icon(
                          Icons.close_rounded,
                          size:  16,
                          color: AppTheme.trialDanger,
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
          // The overlay does not inherit the field's width; this is the card's
          // field width.
          width:      436,
          onSelected: onSelected,
        );
      },
    );
  }
}
