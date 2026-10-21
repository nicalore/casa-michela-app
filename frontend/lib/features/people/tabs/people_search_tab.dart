import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../edit/person_edit_dialog.dart';
import '../edit/person_edit_form.dart' show kBornInItalyNation;
import '../models/people_filter_state.dart';
import '../models/person_item.dart';
import '../utils/people_filter_matching.dart';
import '../widgets/create_account_dialog.dart';
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
const double _cardGap = 16;

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

  List<String> _availableBirthNations = [];
  List<String> _availableBirthCities = [];
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

    if (created == null || !mounted)
    {
      return;
    }

    await _loadData();

    if (created.isNotEmpty && mounted)
    {
      await _offerAccount(created);
    }
  }

  // A failed read stays silent: the record's account section still offers creation.
  Future<void> _offerAccount(String fiscalCode) async
  {
    final PersonItem person;

    try
    {
      person = await _apiService.getPerson(fiscalCode);
    }
    catch (_)
    {
      return;
    }

    if (!mounted || !mayOpenAccount(person))
    {
      return;
    }

    if (await runAccountCreation(context, person) && mounted)
    {
      await _loadData(quiet: true);
    }
  }

  // quiet: bypasses the cache, and a failure keeps the list without an error.
  Future<void> _loadData({bool quiet = false}) async
  {
    try
    {
      final data = await _apiService.getPeople(refresh: quiet);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _people = data.where((person) => !person.isPaperworkOnly).toList();
        // Italy has its own chip: offering it here too would say the same thing twice.
        _availableBirthNations = _distinctSorted(_people
            .map((person) => person.birthNation)
            .where((nation) => nation?.toLowerCase() != kBornInItalyNation.toLowerCase()));
        _availableBirthCities = _distinctSorted(_people.map((person) => person.birthCity));
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

  bool _matchesFilters(PersonItem person)
  {
    final fullName = '${person.firstName} ${person.lastName}'.toLowerCase();

    return fullName.contains(_searchText.toLowerCase()) && matchesPeopleFilter(person, _filterState);
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
        availableBirthNations: _availableBirthNations,
        availableBirthCities: _availableBirthCities,
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
    final AppEmptyCard? empty = emptyListCard(
      shown: people.length,
      total: _people.length,
      icon: Icons.group_off_rounded,
      none: 'Nessuna persona registrata',
    );

    if (empty != null)
    {
      return Expanded(
        child: Center(child: PageTransitionItem(slot: PageTransitionItem.list, child: empty)),
      );
    }

    // Measured outside the scroll view: a SliverLayoutBuilder reruns on every scrolled pixel.
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final available = constraints.maxWidth;
          final bool dense = AppBreakpoints.of(context).isDense;
          final denseLayout = EntityCardGrid.denseLayout(available, kDenseWideCardWidth);

          final columns = _columnsFor(available);
          final width = dense
              ? denseLayout.width
              : ((available - _cardGap * (columns - 1)) / columns).clamp(PersonCard.minWidth, PersonCard.maxWidth);

          // Rows use the count that actually fits after the width is clamped.
          final fitting = dense ? denseLayout.perRow : ((available + _cardGap) / (width + _cardGap)).floor();

          return PageTransitionScrollView.slivers(
            slivers: [
              CardRows(
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
                gap: dense ? kDenseCardGap : _cardGap,
                fromStart: dense,
              ),
            ],
          );
        },
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
            action: tabActionButton(
              label: 'NUOVA PERSONA',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: _openCreationDialog,
            ),
          ),
        ),
        const TabHeaderGap(wide: 28, dense: 10),
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: TabFiltersRow(
            countGap: 36,
            countLabel: people.length == 1 ? '1 persona trovata' : '${people.length} persone trovate',
            filters: [
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
        const TabHeaderGap(wide: 16, dense: 12),
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
