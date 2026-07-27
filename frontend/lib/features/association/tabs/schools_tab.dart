import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/ministry_subject_item.dart';
import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../widgets/school_card.dart';

// Shared between the ListView itemExtent and the height of a single tile:
// the two must match exactly or the scroll math below lands on the wrong row.
const double _cityOptionItemHeight = 44.0;

class SchoolsTab extends StatefulWidget
{
  final List<SchoolItem> schools;

  // Read only: needed by the card and by the wizard to link study programs,
  // but owned by StudyProgramsTab.
  final List<StudyProgramItem> studyPrograms;

  // Read only and used by the card alone, not by the wizard.
  final List<MinistrySubjectItem> ministrySubjects;

  final Future<bool> Function(String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) onCreate;
  final Future<bool> Function(int id, String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) onEdit;
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
        onSave: (code, name, city, prov, programIds, onError) async
        {
          if (school == null)
          {
            return await widget.onCreate(code, name, city, prov, programIds, onError);
          }

          return await widget.onEdit(school.id, code, name, city, prov, programIds, onError);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final schools = _filteredSchools;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca per nome o codice meccanografico...',
              ),
            ),
            const SizedBox(width: 24),
            // The one thing this page is for, so it wears the button the app
            // keeps for exactly that. Cut down to the height of the search bar
            // beside it: at its full size it would be shouting over a field the
            // user is far more likely to reach for.
            AppGradientButton(
              label: 'NUOVA SCUOLA',
              icon: Icons.add_rounded,
              height: 50,
              // Half its own height: the shape it had before, and the shape of
              // the search bar it stands beside.
              radius: 25,
              fontSize: 14,
              onPressed: () => _showWizard(),
            ),
          ],
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
            // The rule of the row: what is left of this line arranges the list,
            // what is right of it shortens it.
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: AppTheme.trialLine,
            ),
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
        // Only the card area scrolls, so header and filters stay pinned.
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 20,
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
            ),
          ),
        ),
      ],
    );
  }
}

class _SchoolWizardDialog extends StatefulWidget
{
  final SchoolItem? existingSchool;
  final List<StudyProgramItem> availableStudyPrograms;
  final List<_CityProvinceOption> citySuggestions;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String? code, String name, String city, String prov, List<int> programIds, Function(String) onError) onSave;

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
  static const Duration _stepTransition = Duration(milliseconds: 300);

  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;
  static const int _provinceLength = 2;
  static const int _maxCitySuggestions = 8;

  final PageController _pageController = PageController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  // RawAutocomplete requires an explicit FocusNode when an external
  // TextEditingController is supplied.
  final FocusNode _cityFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  // Last city confirmed through the autocomplete, by selection or by Enter.
  // While the field text still equals this value no suggestion is shown, even
  // when the focus comes back; it is reset as soon as the user edits the text.
  String? _lastConfirmedCity;

  int _currentStep = 0;
  bool _isSaving = false;
  List<int> _selectedPrograms = [];

  bool get _isEditing => widget.existingSchool != null;

  @override
  void initState()
  {
    super.initState();

    final school = widget.existingSchool;

    if (school != null)
    {
      _codeController.text = school.mechanographicCode ?? '';
      _nameController.text = school.name;
      _cityController.text = school.city;
      _provController.text = school.province;
      _selectedPrograms = school.studyPrograms.map((program) => program.id).toList();

      // While editing the city is already definitive, so it starts out as if
      // it had just been confirmed.
      _lastConfirmedCity = school.city;
    }
  }

  @override
  void dispose()
  {
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _provController.dispose();
    _programSearchController.dispose();
    _cityFocusNode.dispose();
    _codeFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(()
    {
      _codeController.clear();
      _nameController.clear();
      _cityController.clear();
      _provController.clear();
      _programSearchController.clear();
      _selectedPrograms.clear();
      _lastConfirmedCity = null;
      _currentStep = 0;
      _pageController.jumpToPage(0);
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

  bool _validateFirstStep()
  {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final province = _provController.text.trim().toUpperCase();

    if (name.isEmpty || city.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Compila tutti i campi richiesti.', isError: true);
      return false;
    }

    if (province.length != _provinceLength)
    {
      CustomSnackBar.show(context: context, message: 'La provincia deve essere esattamente di 2 lettere.', isError: true);
      return false;
    }

    return true;
  }

  Future<void> _nextStep() async
  {
    if (_currentStep == 0)
    {
      if (!_validateFirstStep())
      {
        return;
      }

      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: _stepTransition, curve: Curves.easeInOut);

      return;
    }

    if (_selectedPrograms.isEmpty)
    {
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
      _provController.text.trim().toUpperCase(),
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

  void _prevStep()
  {
    if (_currentStep <= 0)
    {
      return;
    }

    setState(() => _currentStep--);
    _pageController.animateToPage(_currentStep, duration: _stepTransition, curve: Curves.easeInOut);
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
              _provController.text = option.province;
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

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                shadowColor: const Color(0x33000000),
                // Keeps the highlighted row from painting over the rounded corners.
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: _CityOptionsListView(
                      options: options.toList(),
                      onSelected: onSelected,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStep1()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
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
                    controller: _provController,
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
      ),
    );
  }

  Widget _buildStep2()
  {
    final query = _programSearchController.text.toLowerCase();

    final availablePrograms = widget.availableStudyPrograms
        .where((program) => program.name.toLowerCase().contains(query))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
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
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availablePrograms.map((program)
                {
                  return AppSelectableChip(
                    label: program.name,
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
                  );
                }).toList(),
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
    final isLastStep = _currentStep == 1;

    return AppDialogShell(
      // Which step you are on belongs over the title, not inside it: the title
      // is what you are doing, the eyebrow is where you are in doing it.
      eyebrow: 'Passo ${_currentStep + 1} di 2',
      title: _isEditing ? 'Modifica scuola' : 'Nuova scuola',
      width: 600,
      // Pinned, or the dialog would change height between a step of fields and
      // a step of chips while you are still working through it.
      height: 560,
      footer: AppDialogFooter(
        secondary: _currentStep > 0
            ? AppGradientButton(
                label: 'INDIETRO',
                icon: Icons.arrow_back_rounded,
                gradient: AppTheme.dismissGradient,
                accent: AppTheme.trialViolet,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                onPressed: _prevStep,
              )
            : AppGradientButton(
                label: 'ANNULLA',
                icon: Icons.close_rounded,
                gradient: AppTheme.dismissGradient,
                accent: AppTheme.trialViolet,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                onPressed: _closeDialog,
              ),
        primary: AppGradientButton(
          label: isLastStep ? (_isEditing ? 'SALVA' : 'CREA') : 'AVANTI',
          icon: isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _nextStep,
        ),
      ),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2()],
      ),
    );
  }
}

class _CityProvinceOption
{
  final String city;
  final String province;

  const _CityProvinceOption({required this.city, required this.province});
}

class _CityOptionsListView extends StatefulWidget
{
  final List<_CityProvinceOption> options;
  final AutocompleteOnSelected<_CityProvinceOption> onSelected;

  const _CityOptionsListView({required this.options, required this.onSelected});

  @override
  State<_CityOptionsListView> createState() => _CityOptionsListViewState();
}

class _CityOptionsListViewState extends State<_CityOptionsListView>
{
  // Vertical padding of the ListView, on one side: it is the offset before the
  // first item in the scroll computation below.
  static const double _verticalPadding = 8;

  final ScrollController _scrollController = ScrollController();

  int? _lastHighlightedIndex;

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  // Scrolls by the minimum needed to reveal the arrow-highlighted option,
  // rather than always centring it.
  void _ensureHighlightedVisible(int index)
  {
    if (!_scrollController.hasClients)
    {
      return;
    }

    final itemTop = _verticalPadding + (index * _cityOptionItemHeight);
    final itemBottom = itemTop + _cityOptionItemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final visibleTop = _scrollController.offset;
    final visibleBottom = visibleTop + viewportHeight;

    double? target;

    if (itemTop < visibleTop)
    {
      target = itemTop;
    }
    else if (itemBottom > visibleBottom)
    {
      target = itemBottom - viewportHeight;
    }

    if (target == null)
    {
      return;
    }

    _scrollController.jumpTo(target.clamp(0.0, _scrollController.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context)
  {
    // Reading it here is what creates the reactive dependency on the notifier,
    // so this widget rebuilds on every arrow key press.
    final highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (_lastHighlightedIndex != highlightedIndex)
    {
      _lastHighlightedIndex = highlightedIndex;

      // Deferred: the scrollable must already be laid out to expose
      // viewportDimension and maxScrollExtent.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _ensureHighlightedVisible(highlightedIndex);
        }
      });
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      shrinkWrap: true,
      itemExtent: _cityOptionItemHeight,
      itemCount: widget.options.length,
      itemBuilder: (context, index)
      {
        final option = widget.options[index];

        return _CityOptionTile(
          option: option,
          isHighlighted: index == highlightedIndex,
          onTap: () => widget.onSelected(option),
        );
      },
    );
  }
}

class _CityOptionTile extends StatefulWidget
{
  final _CityProvinceOption option;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _CityOptionTile({
    required this.option,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_CityOptionTile> createState() => _CityOptionTileState();
}

class _CityOptionTileState extends State<_CityOptionTile>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final isActive = widget.isHighlighted || _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: _cityOptionItemHeight,
          color: isActive ? AppTheme.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: isActive ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.option.city,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.iconHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.option.province,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
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