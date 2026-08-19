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

// Four cards to a row is the shape of this list: past that they get small
// enough that the grid reads as a wall rather than as people.
const int _maxColumns = 4;
const double _cardGap = 20;

class PeopleSearchTab extends StatefulWidget
{
  const PeopleSearchTab({super.key});

  // Drops the search, sorting and filters kept across navigation. Called when
  // the caller wants the tab to reopen in its pristine state.
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
  // Static on purpose: search text, sorting and filters have to survive the tab
  // being taken down and put back. Since the destinations of the shell are kept
  // alive that no longer happens on the way to a person and back — the tab is
  // simply still there — and what these are left holding is the session: they
  // outlive a logout, which is why clearSavedState above exists.
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

  // People can have been edited while away — by you, from a person's page — so
  // they are asked for again on return. Quietly: the list already there stays on
  // screen until the new one arrives.
  @override
  void onDestinationShown() => _loadData(quiet: true);

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

  // A person is created in a dialog over the list and not on a page of its own:
  // where one started from stays visible, and closing it lands exactly there.
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

  // Quiet means asked for again rather than asked for the first time: the page
  // is already showing a list, so a failure leaves it standing and says nothing
  // instead of raising an error over a list that is perfectly readable.
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

  Widget _buildResultList(List<PersonItem> people)
  {
    return Expanded(
      // A row at a time, not the whole register at once: everybody the
      // association has ever had is a long list, and described whole it is also
      // that many boxes to move and compose on every frame of a step.
      child: PageTransitionScrollView.slivers(
        slivers: [
          SliverLayoutBuilder(
            builder: (context, constraints)
            {
              final available = constraints.crossAxisExtent;

              // Four to a row wherever four fit, and the row shared out between
              // them rather than packed with as many as will go: at 1920 that is
              // six narrow cards or four roomy ones, and four of a person is
              // easier to read than six.
              //
              // Narrower windows drop a column at a time, and past the widest a
              // card is allowed to be the row simply centres what is left over.
              final columns = _columnsFor(available);
              final width = ((available - _cardGap * (columns - 1)) / columns)
                  .clamp(PersonCard.minWidth, PersonCard.maxWidth);

              // Past the widest a card may be, the row has room for more than
              // the count above asked for and takes it. What decides which row a
              // card lands on — and so when it moves on a change of page — is
              // how many actually fit, not how many were aimed at.
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
        // The page head leaves all at once: field, button, filters and count
        // read as a single block, and it is the cards below that carry the
        // stagger from one item to the next.
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
              // Half its own height: the shape of the search bar it stands
              // beside, and of the button that adds a school.
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
              // A list is always sorted somehow, so this one can never be off
              // and has nothing to clear.
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
              // Everything else lives in a window of its own, so the pill says
              // how many of them are on rather than what they are.
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

// Last option of the children filter: an open ended bucket rather than an exact
// figure. The label and the threshold must stay in step with the filter dialog.
const String _openEndedChildrenCount = '4+';
const int _openEndedChildrenThreshold = 4;
