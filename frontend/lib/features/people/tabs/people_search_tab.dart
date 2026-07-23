import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/people_filter_state.dart';
import '../models/person_item.dart';
import '../widgets/people_filter_dialog.dart';
import '../widgets/person_card.dart';

enum _PeopleSort
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  surnameAsc('Cognome (A-Z)'),
  surnameDesc('Cognome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const _PeopleSort(this.label);
}

class PeopleSearchTab extends StatefulWidget
{
  const PeopleSearchTab({super.key});

  /// Drops the search, sorting and filters kept across navigation. Called when
  /// the caller wants the tab to reopen in its pristine state.
  static void clearSavedState()
  {
    _PeopleSearchTabState._savedSearchText = '';
    _PeopleSearchTabState._savedSort = _PeopleSort.nameAsc;
    _PeopleSearchTabState._savedFilterState = const PeopleFilterState();
  }

  @override
  State<PeopleSearchTab> createState() => _PeopleSearchTabState();
}

class _PeopleSearchTabState extends State<PeopleSearchTab>
{
  // Static on purpose: search text, sorting and filters have to survive
  // navigating to a person and back, and the tab itself is rebuilt from scratch
  // each time.
  static String _savedSearchText = '';
  static _PeopleSort _savedSort = _PeopleSort.nameAsc;
  static PeopleFilterState _savedFilterState = const PeopleFilterState();

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late String _searchText;
  late _PeopleSort _sort;
  late PeopleFilterState _filterState;

  bool _newPersonHover = false;
  bool _filtersHover = false;
  bool _isLoading = true;

  List<PersonItem> _people = [];

  List<String> _availableCities = [];
  List<String> _availableSchools = [];
  List<String> _availableStudyPrograms = [];
  List<String> _availableSubjects = [];

  @override
  void initState()
  {
    super.initState();

    _searchText = _savedSearchText;
    _sort = _savedSort;
    _filterState = _savedFilterState;
    _searchController.text = _searchText;

    _loadData();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  // The filter dialog offers only values that actually occur in the loaded
  // people, so no filter can produce an empty result by construction.
  List<String> _distinctSorted(Iterable<String?> values)
  {
    final result = values
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    result.sort();

    return result;
  }

  Future<void> _loadData() async
  {
    try
    {
      final data = await _apiService.getPeople();

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _people = data;
        _availableCities = _distinctSorted(_people.map((person) => person.city));
        _availableSchools = _distinctSorted(_people.map((person) => person.schoolName));
        _availableStudyPrograms = _distinctSorted(_people.map((person) => person.studyProgram));
        _availableSubjects = _distinctSorted(_people.expand((person) => person.taughtSubjects));
        _isLoading = false;
      });
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _isLoading = false);
      CustomSnackBar.show(
        context: context,
        message: 'Impossibile caricare le anagrafiche dal server.',
        isError: true,
      );
    }
  }

  bool _matchesRoles(PersonItem person)
  {
    final selectedRoles = _filterState.selectedRoles;

    if (selectedRoles.isEmpty)
    {
      return true;
    }

    final specificRoles = selectedRoles.where((role) => role != RoleLabelMapper.memberLabel);

    if (person.roles.any(specificRoles.contains))
    {
      return true;
    }

    // Selecting "Associato" is meant to find plain members, so somebody who is
    // also a teacher or a student does not qualify.
    return selectedRoles.contains(RoleLabelMapper.memberLabel) &&
        RoleLabelMapper.hasOnlyMemberRole(person.roles);
  }

  bool _matchesAgeRange(PersonItem person)
  {
    final range = _filterState.ageRange;

    if (range == null)
    {
      return true;
    }

    final age = person.age;

    if (age == null)
    {
      return false;
    }

    if (age >= range.start && age <= range.end)
    {
      return true;
    }

    // The top of the slider means "this age and above", so it must not exclude
    // anybody older than the maximum.
    return range.end == PeopleFilterState.defaultAgeRange.end &&
        age >= PeopleFilterState.defaultAgeRange.end;
  }

  bool _matchesChildrenCount(PersonItem person)
  {
    final expected = _filterState.childrenCount;

    if (expected == null)
    {
      return true;
    }

    final count = person.childrenCount;

    if (count == null)
    {
      return false;
    }

    // The last option is open ended rather than an exact figure.
    if (expected == _openEndedChildrenCount)
    {
      return count >= _openEndedChildrenThreshold;
    }

    return count.toString() == expected;
  }

  bool _matchesSubjects(PersonItem person)
  {
    // Selecting several subjects means "teaches all of them", not "any of them".
    if (!_filterState.taughtSubjects.every(person.taughtSubjects.contains))
    {
      return false;
    }

    final range = _filterState.taughtSubjectsCount;

    if (range == null)
    {
      return true;
    }

    final count = person.taughtSubjects.length;

    if (count >= range.start && count <= range.end)
    {
      return true;
    }

    return range.end == PeopleFilterState.defaultTaughtSubjectsCount.end &&
        count >= PeopleFilterState.defaultTaughtSubjectsCount.end;
  }

  bool _matchesText(String? value, String? expected)
  {
    if (expected == null || expected.isEmpty)
    {
      return true;
    }

    return value?.toLowerCase() == expected.toLowerCase();
  }

  bool _matchesExactly(Object? value, Object? expected)
  {
    return expected == null || value == expected;
  }

  bool _matchesFilters(PersonItem person)
  {
    final fullName = '${person.firstName} ${person.lastName}'.toLowerCase();

    return fullName.contains(_searchText.toLowerCase()) &&
        _matchesRoles(person) &&
        _matchesAgeRange(person) &&
        _matchesChildrenCount(person) &&
        _matchesSubjects(person) &&
        _matchesText(person.city, _filterState.city) &&
        _matchesText(person.schoolName, _filterState.schoolName) &&
        _matchesText(person.studyProgram, _filterState.studyProgram) &&
        _matchesText(person.courseType, _filterState.courseType) &&
        _matchesExactly(person.isActiveCollaborator, _filterState.isActiveCollaborator) &&
        _matchesExactly(person.enrollmentYear, _filterState.enrollmentYear) &&
        _matchesExactly(person.educationLevel, _filterState.educationLevel) &&
        _matchesExactly(person.schoolClass, _filterState.schoolClass) &&
        _matchesExactly(person.earlyExit, _filterState.earlyExit) &&
        _matchesExactly(person.collaborationType, _filterState.collaborationType) &&
        _matchesExactly(person.isMedicalCertificateValid, _filterState.isMedicalCertificateValid);
  }

  int _compare(PersonItem a, PersonItem b)
  {
    return switch (_sort)
    {
      _PeopleSort.nameAsc => a.firstName.compareTo(b.firstName),
      _PeopleSort.nameDesc => b.firstName.compareTo(a.firstName),
      _PeopleSort.surnameAsc => a.lastName.compareTo(b.lastName),
      _PeopleSort.surnameDesc => b.lastName.compareTo(a.lastName),
      _PeopleSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      _PeopleSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }

  List<PersonItem> get _filteredPeople
  {
    final result = _people.where(_matchesFilters).toList();
    result.sort(_compare);

    return result;
  }

  void _showFilterDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'PeopleFilter',
      builder: (context) => PeopleFilterDialog(
        initialState: _filterState,
        availableCities: _availableCities,
        availableSchools: _availableSchools,
        availableStudyPrograms: _availableStudyPrograms,
        availableSubjects: _availableSubjects,
        onApply: (newState) => setState(()
        {
          _filterState = newState;
          _savedFilterState = newState;
        }),
      ),
    );
  }

  void _clearFilters()
  {
    setState(()
    {
      _filterState = const PeopleFilterState();
      _savedFilterState = const PeopleFilterState();
    });
  }

  Widget _buildNewPersonButton()
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _newPersonHover = true),
      onExit: (_) => setState(() => _newPersonHover = false),
      child: GestureDetector(
        onTap: () => context.go('/people/new'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: _newPersonHover ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Center(
            child: Text(
              'Nuova persona',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBadge()
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _filterState.activeFiltersCount.toString(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildFiltersButton({required bool isFilterActive})
  {
    final isHighlighted = _filtersHover || isFilterActive;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _filtersHover = true),
      onExit: (_) => setState(() => _filtersHover = false),
      child: GestureDetector(
        onTap: _showFilterDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          padding: EdgeInsets.only(left: 16, right: isFilterActive ? 12 : 16),
          decoration: BoxDecoration(
            color: isHighlighted ? AppTheme.surfaceHover : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Filtri',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: isFilterActive ? AppTheme.primary : AppTheme.mutedText,
                ),
              ),
              if (isFilterActive) ...[
                const SizedBox(width: 8),
                _buildActiveFiltersBadge(),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _clearFilters,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultList(List<PersonItem> people)
  {
    return Expanded(
      child: SingleChildScrollView(
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: people.map((person)
            {
              return PersonCard(
                person: person,
                onTap: () => context.go('/people/${person.fiscalCode}'),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final people = _filteredPeople;
    final isFilterActive = _filterState.hasActiveFilters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSearchBar(
                controller: _searchController,
                hintText: 'Cerca persona...',
                onChanged: (value) => setState(()
                {
                  _searchText = value;
                  _savedSearchText = value;
                }),
              ),
            ),
            const SizedBox(width: 24),
            _buildNewPersonButton(),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CustomFilterMenu<_PeopleSort>(
              hint: 'Ordina per',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 200,
              showClearIcon: false,
              onClear: () {},
              onChanged: (value) => setState(()
              {
                _sort = value;
                _savedSort = value;
              }),
              options: _PeopleSort.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            _buildFiltersButton(isFilterActive: isFilterActive),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          people.length == 1 ? '1 persona trovata' : '${people.length} persone trovate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          )
        else
          _buildResultList(people),
      ],
    );
  }
}

// Last option of the children filter: an open ended bucket rather than an exact
// figure. The label and the threshold must stay in step with the filter dialog.
const String _openEndedChildrenCount = '4+';
const int _openEndedChildrenThreshold = 4;