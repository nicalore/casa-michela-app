import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_choice_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
import '../models/ministry_subject_item.dart';
import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/school_card.dart';

class SchoolsTab extends StatefulWidget
{
  final List<SchoolItem> schools;

  final List<StudyProgramItem> studyPrograms;

  final List<MinistrySubjectItem> ministrySubjects;

  final Future<bool> Function(String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError) onEdit;
  final void Function(SchoolItem item) onDelete;

  const SchoolsTab({
    super.key,
    required this.schools,
    required this.studyPrograms,
    required this.ministrySubjects,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SchoolsTab> createState() => _SchoolsTabState();
}

class _SchoolsTabState extends State<SchoolsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  SortCriterion _sortBy = SortCriterion.nameAsc;
  String? _filterCity;

  List<FilterOption<String>> get _cityOptions
  {
    final cities = widget.schools.map((school) => school.city).toSet().toList();
    cities.sort();

    return cities.map((city) => FilterOption(value: city, label: city)).toList();
  }

  List<_CityProvinceOption> get _citySuggestions
  {
    final unique = <String, _CityProvinceOption>{};

    for (final school in widget.schools)
    {
      final key = '${school.city.toLowerCase()}|${school.province.toUpperCase()}';
      unique[key] = _CityProvinceOption(city: school.city, province: school.province);
    }

    final result = unique.values.toList();
    result.sort((a, b) => a.city.compareTo(b.city));

    return result;
  }

  List<SchoolItem> get _filteredSchools
  {
    final query = _searchText.toLowerCase();

    final result = widget.schools.where((school)
    {
      final matchesSearch = school.name.toLowerCase().contains(query) ||
          (school.mechanographicCode ?? '').toLowerCase().contains(query);
      final matchesCity = _filterCity == null || school.city == _filterCity;

      return matchesSearch && matchesCity;
    }).toList();

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

  void _showWizard({SchoolItem? school, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SchoolWizard',
      builder: (context) => _SchoolWizardDialog(
        existingSchool: school,
        availableStudyPrograms: widget.studyPrograms,
        citySuggestions: _citySuggestions,
        onCancelEdit: onCancelEdit,
        onSave: (code, name, city, provinceCode, programIds, onError) async
        {
          if (school == null)
          {
            return await widget.onCreate(code, name, city, provinceCode, programIds, onError);
          }

          return await widget.onEdit(school.id, code, name, city, provinceCode, programIds, onError);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final schools = _filteredSchools;

    return TabContent(
      header: entityTabHeader(
        searchController: _searchController,
        onSearchChanged: (value) => setState(() => _searchText = value),
        searchHint: 'Cerca per nome o codice meccanografico...',
        actionLabel: 'NUOVA SCUOLA',
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: schools.length == 1
            ? '1 scuola trovata'
            : '${schools.length} scuole trovate',
        filters: [
          const FilterGroupDivider(),
          AppFilterPill<String>.filter(
            prefix: 'Città',
            hint: 'Tutte le città',
            icon: Icons.location_city_outlined,
            value: _filterCity,
            menuWidth: 210,
            onChanged: (value) => setState(() => _filterCity = value),
            onClear: () => setState(() => _filterCity = null),
            options: _cityOptions,
          ),
        ],
      ),
      body: EntityCardGrid(
        children: schools.map((school)
        {
          return SchoolCard(
            school: school,
            availableStudyPrograms: widget.studyPrograms,
            availableMinistrySubjects: widget.ministrySubjects,
            onEditRequested: (onCancel) => _showWizard(school: school, onCancelEdit: onCancel),
            onDelete: () => widget.onDelete(school),
          );
        }).toList(),
      ),
    );
  }
}

class _SchoolWizardDialog extends StatefulWidget
{
  final SchoolItem? existingSchool;
  final List<StudyProgramItem> availableStudyPrograms;
  final List<_CityProvinceOption> citySuggestions;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String? code, String name, String city, String provinceCode, List<int> programIds, Function(String) onError) onSave;

  const _SchoolWizardDialog({
    this.existingSchool,
    required this.availableStudyPrograms,
    required this.citySuggestions,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_SchoolWizardDialog> createState() => _SchoolWizardDialogState();
}

class _SchoolWizardDialogState extends State<_SchoolWizardDialog>
    with WizardDialogState, TwoStepWizardState
{
  static const int _maxCitySuggestions = 8;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  final FocusNode _cityFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  String? _lastConfirmedCity;

  static const double _contentMaxWidth = 760;

  static const double _optionsMaxHeight = 520;

  List<int> _selectedPrograms = [];

  @override
  bool get isEditing => widget.existingSchool != null;

  @override
  VoidCallback? get onCancelEdit => widget.onCancelEdit;

  @override
  void initState()
  {
    super.initState();

    _nameController.addListener(_refresh);
    _cityController.addListener(_refresh);
    _provinceController.addListener(_refresh);

    final school = widget.existingSchool;

    if (school != null)
    {
      _codeController.text = school.mechanographicCode ?? '';
      _nameController.text = school.name;
      _cityController.text = school.city;
      _provinceController.text = school.province;
      _selectedPrograms = school.studyPrograms.map((program) => program.id).toList();

      _lastConfirmedCity = school.city;
    }
  }

  void _refresh()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  @override
  void dispose()
  {
    _nameController.removeListener(_refresh);
    _cityController.removeListener(_refresh);
    _provinceController.removeListener(_refresh);
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _programSearchController.dispose();
    _cityFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  void resetForm()
  {
    setState(()
    {
      _codeController.clear();
      _nameController.clear();
      _cityController.clear();
      _provinceController.clear();
      _programSearchController.clear();
      _selectedPrograms.clear();
      _lastConfirmedCity = null;
      rewindSteps();
    });
  }

  @override
  String? get firstStepBlockedReason
  {
    if (_nameController.text.trim().isEmpty || _cityController.text.trim().isEmpty)
    {
      return 'Compila nome e città per andare avanti.';
    }

    if (_provinceController.text.trim().length != FieldLimits.province)
    {
      return 'La provincia è di due lettere.';
    }

    return null;
  }

  Future<void> _submit() async
  {
    if (!validateFirstStep())
    {
      goToStep(0);

      return;
    }

    if (_selectedPrograms.isEmpty)
    {
      goToStep(1);
      showError('Associa almeno un percorso di studio alla scuola.');

      return;
    }

    final rawCode = _codeController.text.trim().toUpperCase();

    await runSave(
      (onError) => widget.onSave(
        rawCode.isEmpty ? null : rawCode,
        _nameController.text.trim(),
        _cityController.text.trim(),
        _provinceController.text.trim().toUpperCase(),
        _selectedPrograms,
        onError,
      ),
    );
  }

  Widget _buildCityAutocomplete()
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        return RawAutocomplete<_CityProvinceOption>(
          textEditingController: _cityController,
          focusNode: _cityFocusNode,
          displayStringForOption: (option) => option.city,
          optionsBuilder: (textEditingValue)
          {
            final currentText = textEditingValue.text.trim();

            if (currentText.isEmpty)
            {
              return const Iterable<_CityProvinceOption>.empty();
            }

            if (_lastConfirmedCity != null && currentText == _lastConfirmedCity)
            {
              return const Iterable<_CityProvinceOption>.empty();
            }

            final query = currentText.toLowerCase();

            return widget.citySuggestions
                .where((option) => option.city.toLowerCase().contains(query))
                .take(_maxCitySuggestions);
          },
          onSelected: (option)
          {
            setState(()
            {
              _provinceController.text = option.province;
              _lastConfirmedCity = option.city;
            });

            WidgetsBinding.instance.addPostFrameCallback((_)
            {
              if (!mounted)
              {
                return;
              }

              _codeFocusNode.requestFocus();
              _codeController.selection = TextSelection.collapsed(offset: _codeController.text.length);
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted)
          {
            return AppTextField(
              controller: controller,
              focusNode: focusNode,
              label: 'Città',
              hintText: 'Es. Thiene',
              maxLength: FieldLimits.city,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options)
          {
            final currentText = _cityController.text.trim();

            if (_lastConfirmedCity != null && currentText == _lastConfirmedCity)
            {
              return const SizedBox.shrink();
            }

            return AutocompleteOptionsList<_CityProvinceOption>(
              options: options,
              label: (option) => option.city,
              subtitle: (option) => option.province,
              width: constraints.maxWidth,
              onSelected: onSelected,
            );
          },
        );
      },
    );
  }

  Widget _buildStep1()
  {
    return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Nome',
              hintText: 'Es. Liceo Statale F. Corradini',
              maxLength: FieldLimits.name,
              textCapitalization: TextCapitalization.words,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildCityAutocomplete()),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: AppTextField(
                    controller: _provinceController,
                    label: 'Provincia',
                    hintText: 'Es. VI',
                    maxLength: FieldLimits.province,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            AppTextField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              label: 'Codice meccanografico (opzionale)',
              hintText: 'Es. VIPC02000P',
              maxLength: FieldLimits.mechanographicCode,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      );
  }

  static const double _programGap = 12;

  Widget _buildStep2()
  {
    final query = _programSearchController.text.toLowerCase();

    final availablePrograms = widget.availableStudyPrograms
        .where((program) => program.fullName.toLowerCase().contains(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleziona i percorsi di studio attivi in questa scuola',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppTheme.trialMutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        AppSearchField(
          controller: _programSearchController,
          onChanged: (_) => setState(() {}),
          hintText: 'Cerca percorso di studio...',
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _optionsMaxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _programGap,
              children: [
                for (final program in availablePrograms)
                  AppChoiceCard(
                    title: program.name,
                    subtitle: programScopeTitle(
                      level: program.level,
                      sector: program.sector,
                    ),
                    selected: _selectedPrograms.contains(program.id),
                    onSelected: (selected) => setState(()
                    {
                      if (selected)
                      {
                        _selectedPrograms.add(program.id);
                      }
                      else
                      {
                        _selectedPrograms.remove(program.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return buildTwoStepDialog(
      title: isEditing ? 'Modifica scuola' : 'Nuova scuola',
      contentMaxWidth: _contentMaxWidth,
      onSubmit: _submit,
      firstStep: _buildStep1,
      secondStep: _buildStep2,
    );
  }
}

class _CityProvinceOption
{
  final String city;
  final String province;

  const _CityProvinceOption({required this.city, required this.province});
}
