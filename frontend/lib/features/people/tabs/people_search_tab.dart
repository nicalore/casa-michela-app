import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../edit/person_edit_dialog.dart';
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

const int _maxColumns = 4;
const double _cardGap = 20;

// Must match RoleLabelMapper's spelling.
const String _studentRoleLabel = 'Studente';

class PeopleSearchTab extends StatefulWidget
{
  const PeopleSearchTab({super.key});

  static void clearSavedState()
  {
    _PeopleSearchTabState._savedSearchText = '';
    _PeopleSearchTabState._savedSort = _PeopleSort.nameAsc;
    _PeopleSearchTabState._savedFilterState = const PeopleFilterState();
  }

  @override
  State<PeopleSearchTab> createState() => _PeopleSearchTabState();
}

class _PeopleSearchTabState extends State<PeopleSearchTab> with DestinationRefresh
{
  // Static state survives rebuilds and logout, hence clearSavedState.
  static String _savedSearchText = '';
  static _PeopleSort _savedSort = _PeopleSort.nameAsc;
  static PeopleFilterState _savedFilterState = const PeopleFilterState();

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late String _searchText;
  late _PeopleSort _sort;
  late PeopleFilterState _filterState;

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
  void onDestinationShown() => _loadData(quiet: true);

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _openCreationDialog() async
  {
    final String? created = await showBlurredDialog<String>(
      context: context,
      barrierLabel: 'PersonCreation',
      builder: (context) => const PersonEditDialog.create(),
    );

    if (created != null && mounted)
    {
      await _loadData();
    }
  }

  // quiet: a failure leaves the existing list standing without an error.
  Future<void> _loadData({bool quiet = false}) async
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

      if (!quiet)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Impossibile caricare le anagrafiche dal server.',
          isError: true,
        );
      }
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

    // "Associato" matches plain members only, not teachers or students.
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

    // The top of the slider means "this age and above".
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

  bool _matchesCertifications(PersonItem person)
  {
    return _filterState.matchesCertification(
      certificationTypes: person.certificationTypes,
      isStudent: person.roles.contains(_studentRoleLabel),
    );
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
        _matchesCertifications(person) &&
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

  Widget _buildResultList(List<PersonItem> people)
  {
    return Expanded(
      child: PageTransitionScrollView.slivers(
        slivers: [
          SliverLayoutBuilder(
            builder: (context, constraints)
            {
              final available = constraints.crossAxisExtent;

              final columns = _columnsFor(available);
              final width = ((available - _cardGap * (columns - 1)) / columns)
                  .clamp(PersonCard.minWidth, PersonCard.maxWidth);

              // Rows use the count that actually fits after the width is clamped.
              final fitting = ((available + _cardGap) / (width + _cardGap)).floor();

              return CardRows(
                cards: [
                  for (final person in people)
                    PersonCard(
                      person: person,
                      width: width,
                      onTap: () => context.go('/people/${person.fiscalCode}'),
                    ),
                ],
                cardWidth: width,
                perRow: fitting < 1 ? 1 : fitting,
                gap: _cardGap,
              );
            },
          ),
        ],
      ),
    );
  }

  int _columnsFor(double available)
  {
    for (var columns = _maxColumns; columns > 1; columns--)
    {
      if (columns * PersonCard.minWidth + _cardGap * (columns - 1) <= available)
      {
        return columns;
      }
    }

    return 1;
  }

  @override
  Widget build(BuildContext context)
  {
    final people = _filteredPeople;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: TabHeaderRow(
            search: AppSearchField(
              controller: _searchController,
              onChanged: (value) => setState(()
              {
                _searchText = value;
                _savedSearchText = value;
              }),
              hintText: 'Cerca persona...',
            ),
            action: AppGradientButton(
              label: 'NUOVA PERSONA',
              icon: Icons.person_add_alt_1_rounded,
              height: 50,
              radius: 25,
              fontSize: 14,
              onPressed: _openCreationDialog,
            ),
          ),
        ),
        const SizedBox(height: 28),
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppFilterPill<_PeopleSort>.setting(
                prefix: 'Ordina',
                hint: 'Ordina per',
                icon: Icons.swap_vert_rounded,
                value: _sort,
                menuWidth: 220,
                onChanged: (value) => setState(()
                {
                  _sort = value;
                  _savedSort = value;
                }),
                options: _PeopleSort.values
                    .map((sort) => FilterOption(value: sort, label: sort.label))
                    .toList(),
              ),
              const FilterGroupDivider(),
              AppCountFilterPill(
                label: 'Filtri',
                icon: Icons.tune_rounded,
                count: _filterState.activeFiltersCount,
                onOpen: _showFilterDialog,
                onClear: _clearFilters,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 16),
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: Text(
            people.length == 1 ? '1 persona trovata' : '${people.length} persone trovate',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
          )
        else
          _buildResultList(people),
      ],
    );
  }
}

// Open-ended bucket; label and threshold must stay in step with the filter dialog.
const String _openEndedChildrenCount = '4+';
const int _openEndedChildrenThreshold = 4;
