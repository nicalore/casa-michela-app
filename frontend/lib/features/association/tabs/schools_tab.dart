import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_choice_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../models/ministry_subject_item.dart';
import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/school_card.dart';

class SchoolsTab extends StatefulWidget
{
  final List<SchoolItem> schools;

  // Read only: needed by the card and by the wizard to link study programs,
  // but owned by StudyProgramsTab.
  final List<StudyProgramItem> studyPrograms;

  // Read only and used by the card alone, not by the wizard.
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

  // Built from the schools actually stored, not from a fixed enum.
  List<FilterOption<String>> get _cityOptions
  {
    final cities = widget.schools.map((school) => school.city).toSet().toList();
    cities.sort();

    return cities.map((city) => FilterOption(value: city, label: city)).toList();
  }

  // One entry per city and province pair, so that homonymous towns in
  // different provinces stay distinguishable.
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
      // City and province are deliberately excluded: they have their own filter.
      final matchesSearch = school.name.toLowerCase().contains(query) ||
          (school.mechanographicCode ?? '').toLowerCase().contains(query);
      final matchesCity = _filterCity == null || school.city == _filterCity;

      return matchesSearch && matchesCity;
    }).toList();

    result.sort((a, b) => switch (_sortBy)
    {
      SortCriterion.nameAsc => a.name.compareTo(b.name),
      SortCriterion.nameDesc => b.name.compareTo(a.name),
      SortCriterion.dateAsc => a.createdAt.compareTo(b.createdAt),
      SortCriterion.dateDesc => b.createdAt.compareTo(a.createdAt),
    });

    return result;
  }

  void _showWizard({SchoolItem? school, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SchoolWizard',
      builder: (context) => _SchoolWizardDialog(
        existingSchool: school,
        // Both lists are read here, so they are recomputed from the current
        // widget state every time the wizard is opened.
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
      header: [
        TabHeaderRow(
          search: AppSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            hintText: 'Cerca per nome o codice meccanografico...',
          ),
          action: AppGradientButton(
            label: 'NUOVA SCUOLA',
            icon: Icons.add_rounded,
            height: 50,
            // Half its own height: the shape it had before, and the shape of
            // the search bar it stands beside.
            radius: 25,
            fontSize: 14,
            onPressed: () => _showWizard(),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // A list is always sorted somehow, so this one can never be off and
            // has nothing to clear: it states what it is set to and stays quiet.
            AppFilterPill<SortCriterion>.setting(
              prefix: 'Ordina',
              hint: 'Ordina per',
              icon: Icons.swap_vert_rounded,
              value: _sortBy,
              menuWidth: 190,
              onChanged: (value) => setState(() => _sortBy = value),
              options: SortCriterion.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            const FilterGroupDivider(),
            // Off until you choose a city, and once chosen it is the reason the
            // list is shorter than the truth, so it fills and says so.
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
        const SizedBox(height: 20),
        Text(
          schools.length == 1 ? '1 scuola trovata' : '${schools.length} scuole trovate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 16),
      ],
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
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;
  static const int _provinceLength = 2;
  static const int _maxCitySuggestions = 8;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  // RawAutocomplete requires an explicit FocusNode when an external
  // TextEditingController is supplied.
  final FocusNode _cityFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  // Last city confirmed through the autocomplete, by selection or by Enter.
  // While the field text still equals this value no suggestion is shown, even
  // when the focus comes back; it is reset as soon as the user edits the text.
  String? _lastConfirmedCity;

  // How wide the card in the carousel is allowed to get, and the stack around
  // it: the card plus an arrow and a gap on either side.
  // The programmes are picked from rows carrying the name and, below it, the
  // level and the sector: narrower, both wrapped — a row twice as tall, and half
  // the programmes below the fold.
  static const double _contentMaxWidth = 760;
  static const double _stackMaxWidth =
      _contentMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  // How far the programme list may grow before it starts scrolling.
  //
  // A row carries the name with its level and sector under it, so it costs more
  // height than a chip did. Five or six fit here, which is enough for scrolling
  // to be the exception.
  static const double _optionsMaxHeight = 520;

  int _currentStep = 0;
  bool _movingForward = true;
  bool _isSaving = false;
  List<int> _selectedPrograms = [];

  bool get _isEditing => widget.existingSchool != null;

  @override
  void initState()
  {
    super.initState();

    // The arrow lights up as soon as the mandatory fields are there: without
    // listening to them it would stay dark until something else repainted.
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

      // While editing the city is already definitive, so it starts out as if
      // it had just been confirmed.
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

  void _resetForm()
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
      _currentStep = 0;
      _movingForward = false;
    });
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();

    if (_isEditing)
    {
      widget.onCancelEdit?.call();
    }
  }

  // Why the first step does not let one move on, where it does not. The reason
  // is said on the darkened arrow, before it is pressed.
  String? get _firstStepBlockedReason
  {
    if (_nameController.text.trim().isEmpty || _cityController.text.trim().isEmpty)
    {
      return 'Compila nome e città per andare avanti.';
    }

    if (_provinceController.text.trim().length != _provinceLength)
    {
      return 'La provincia è di due lettere.';
    }

    return null;
  }

  bool _validateFirstStep()
  {
    final reason = _firstStepBlockedReason;

    if (reason != null)
    {
      CustomSnackBar.show(context: context, message: reason, isError: true);

      return false;
    }

    return true;
  }

  void _goToStep(int step)
  {
    setState(()
    {
      _movingForward = step > _currentStep;
      _currentStep = step;
    });
  }

  // Everything is checked from here, whichever phase you are standing on, and
  // whatever is missing is on the phase this puts you on.
  Future<void> _submit() async
  {
    if (!_validateFirstStep())
    {
      _goToStep(0);

      return;
    }

    if (_selectedPrograms.isEmpty)
    {
      _goToStep(1);
      CustomSnackBar.show(context: context, message: 'Associa almeno un percorso di studio alla scuola.', isError: true);

      return;
    }

    setState(() => _isSaving = true);

    // An empty field means no code, and travels as null all the way to the DB.
    final rawCode = _codeController.text.trim().toUpperCase();

    final success = await widget.onSave(
      rawCode.isEmpty ? null : rawCode,
      _nameController.text.trim(),
      _cityController.text.trim(),
      _provinceController.text.trim().toUpperCase(),
      _selectedPrograms,
      (errorMessage)
      {
        if (mounted)
        {
          CustomSnackBar.show(context: context, message: errorMessage, isError: true);
        }
      },
    );

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (!success)
    {
      return;
    }

    if (_isEditing)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
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

            // Contains, not prefix: "bonif" has to find "San Bonifacio" too.
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

            // Deferred to the next frame because RawAutocomplete completes its
            // own closing logic after onSelected returns.
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
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options)
          {
            // RawAutocomplete recomputes the option list only when the text
            // changes, not when the focus comes back, and its internal cache
            // keeps the pre-selection query (flutter/flutter#167712). The
            // suppression therefore has to read the live controller text here
            // instead of trusting the options passed in, which may be stale.
            final currentText = _cityController.text.trim();

            if (_lastConfirmedCity != null && currentText == _lastConfirmedCity)
            {
              return const SizedBox.shrink();
            }

            return AutocompleteOptionsList<_CityProvinceOption>(
              options: options,
              label: (option) => option.city,
              // The province at the end of the row, where a level stands on a
              // ministry subject: it is what tells two Bonifacios apart.
              subtitle: (option) => option.province,
              // The list opens in an overlay, where the width of the field
              // under it does not reach through the constraints.
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
            // Name and city form the uniqueness constraint, hence they sit
            // next to each other; the code closes the form as an optional
            // detail.
            AppTextField(
              controller: _nameController,
              label: 'Nome',
              hintText: 'Es. Liceo Statale F. Corradini',
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
                    maxLength: _provinceLength,
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
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      );
  }

  // Between one row of the programme list and the next.
  static const double _programGap = 12;

  Widget _buildStep2()
  {
    final query = _programSearchController.text.toLowerCase();

    // Searched on the full name, sector included: the sector sits under the
    // name and not inside it, but it is still what one types.
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
        // A ceiling rather than the whole of what is left: the phase is a
        // piece floating on the page now, and there is no fixed panel height
        // for it to take a share of. Past this the list scrolls inside it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _optionsMaxHeight),
          child: SingleChildScrollView(
            // Rows to tick instead of chips: programme names are long, and a
            // run of chips each wrapping three times reads as a wall. They are
            // the same rows a person's roles are picked with.
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
    return AppDialogStack(
      eyebrow: 'Passo ${_currentStep + 1} di 2',
      title: _isEditing ? 'Modifica scuola' : 'Nuova scuola',
      onClose: _closeDialog,
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _submit,
        ),
      ),
      children: [
        AppCarouselFrame(
          index: _currentStep,
          movingForward: _movingForward,
          maxContentWidth: _contentMaxWidth,
          canGoBack: _currentStep > 0,
          canGoForward: _currentStep == 0,
          forwardBlockedReason:
              _currentStep == 0 ? _firstStepBlockedReason : null,
          onBack: () => _goToStep(0),
          onForward: () => _goToStep(1),
          child: AppDialogPill(
            child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
          ),
        ),
      ],
    );
  }
}

class _CityProvinceOption
{
  final String city;
  final String province;

  const _CityProvinceOption({required this.city, required this.province});
}
