import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/alphabetical_order.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../core/utils/time_bucket.dart';
import '../../association/models/opening_day_item.dart';
import '../../people/models/person_face.dart';
import '../../people/models/person_item.dart';
import '../models/availability_group.dart';
import '../models/availability_item.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';
import '../widgets/availability_card.dart';
import '../widgets/availability_wizard.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/lessons_toolbar.dart';

class AvailabilityTab extends StatefulWidget
{
  final List<AvailabilityItem> availabilities;
  final List<PersonItem> teachers;

  final List<DateTime> availableDays;
  final DateTime selectedDay;

  final List<OpeningDayItem> openingDays;

  // A day outside the booking window: shown, never changed.
  final bool readOnly;

  // False once the day has no band left to add to: the new button goes.
  final bool canAdd;

  final LessonsDayView view;
  final ValueChanged<LessonsDayView> onViewSelected;

  final Future<bool> Function(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreate;
  final Future<bool> Function(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEdit;

  final Future<bool> Function(AvailabilityItem item, Function(String) onError) onDeleteSlot;
  final void Function(List<AvailabilityItem> slots) onDeleteGroup;

  const AvailabilityTab({
    super.key,
    required this.availabilities,
    required this.teachers,
    required this.availableDays,
    required this.selectedDay,
    required this.openingDays,
    this.readOnly = false,
    this.canAdd = true,
    required this.view,
    required this.onViewSelected,
    required this.onCreate,
    required this.onEdit,
    required this.onDeleteSlot,
    required this.onDeleteGroup,
  });

  @override
  State<AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<AvailabilityTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  String? _filterMode;
  TimeBucket? _filterBucket;

  Set<String> _filterSubjects = {};

  bool get _hasFilters => _filterMode != null || _filterBucket != null || _filterSubjects.isNotEmpty;

  List<AvailabilityGroup> get _dayGroups
  {
    final selectedDay = widget.selectedDay;

    final onTheDay = widget.availabilities
        .where((availability) => isSameDate(availability.date, selectedDay))
        .toList();

    final groups = groupAvailabilities(onTheDay);

    groups.sort((a, b)
    {
      final startComparison = a.startMinutes.compareTo(b.startMinutes);

      if (startComparison != 0)
      {
        return startComparison;
      }

      return compareByName(a.teacher, b.teacher);
    });

    return groups;
  }

  List<AvailabilityGroup> get _filteredGroups
  {
    final query = _searchText.toLowerCase();

    return _dayGroups
        .where((group) =>
            group.teacher.fullName.toLowerCase().contains(query) && _matchesFilters(group))
        .toList();
  }

  List<String> _subjectsOf(String teacherTaxCode)
  {
    for (final teacher in widget.teachers)
    {
      if (teacher.fiscalCode == teacherTaxCode)
      {
        return teacher.taughtSubjects;
      }
    }

    return const [];
  }

  List<String> get _subjectOptions
  {
    final subjects = <String>{};

    for (final group in _dayGroups)
    {
      subjects.addAll(_subjectsOf(group.teacherTaxCode));
    }

    final sorted = subjects.toList()..sort(compareAlphabetically);

    return sorted;
  }

  bool _matchesFilters(AvailabilityGroup group)
  {
    if (_filterSubjects.isNotEmpty &&
        !_subjectsOf(group.teacherTaxCode).any(_filterSubjects.contains))
    {
      return false;
    }

    if (_filterMode == null && _filterBucket == null)
    {
      return true;
    }

    return group.slots.any((slot) =>
        (_filterMode == null || slot.mode == _filterMode) &&
        (_filterBucket == null || bucketFor(slot.startTime) == _filterBucket));
  }

  @override
  void didUpdateWidget(AvailabilityTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_filterSubjects.isNotEmpty)
    {
      final available = _subjectOptions.toSet();

      _filterSubjects = _filterSubjects.where(available.contains).toSet();
    }
  }

  AppEmptyCard get _emptyCard
  {
    if (_hasFilters)
    {
      return AppEmptyCard(icon: Icons.filter_alt_off_rounded, message: tr('Nessuna disponibilità corrisponde ai filtri scelti.', 'No availability matches the chosen filters.'));
    }

    if (_searchText.isNotEmpty)
    {
      return AppEmptyCard(icon: Icons.search_off_rounded, message: tr('Nessun docente trovato in questa giornata.', 'No teachers found on this day.'));
    }

    return AppEmptyCard(icon: Icons.event_note_rounded, message: tr('Nessuna disponibilità in questa giornata.', 'No availability on this day.'));
  }

  Widget _buildFilters()
  {
    final subjects = _subjectOptions;

    return TabFiltersRow(
      filters: [
        AppFilterPill<String>.filter(
          prefix: tr('Modalità', 'Mode'),
          hint: tr('Presenza e online', 'In person and online'),
          icon: Icons.devices_outlined,
          value: _filterMode,
          menuWidth: 190,
          onChanged: (value) => setState(() => _filterMode = value),
          onClear: () => setState(() => _filterMode = null),
          options: [
            for (final mode in const [kPresenceMode, kOnlineMode])
              FilterOption(value: mode, label: modeLabel(mode)),
          ],
        ),
        AppFilterPill<TimeBucket>.filter(
          prefix: tr('Quando', 'When'),
          hint: tr('Tutta la giornata', 'All day'),
          icon: Icons.schedule_rounded,
          value: _filterBucket,
          menuWidth: 190,
          onChanged: (value) => setState(() => _filterBucket = value),
          onClear: () => setState(() => _filterBucket = null),
          options: [
            for (final bucket in TimeBucket.values)
              FilterOption(value: bucket, label: bandLabel(bucket)),
          ],
        ),
        if (subjects.isNotEmpty)
          AppCountFilterPill(
            label: tr('Discipline', 'Disciplines'),
            icon: Icons.auto_stories_outlined,
            count: _filterSubjects.length,
            onOpen: () => _showSubjectFilterDialog(subjects),
            onClear: () => setState(() => _filterSubjects = {}),
          ),
      ],
    );
  }

  void _showSubjectFilterDialog(List<String> subjects)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectFilterDialog',
      builder: (context) => MultiSelectFilterDialog<String>(
        title: tr('Filtra per disciplina interna', 'Filter by internal discipline'),
        hint: tr('Es. Aritmetica', 'E.g. Arithmetic'),
        options: [
          for (final subject in subjects)
            MultiSelectFilterOption(value: subject, label: subject),
        ],
        initialSelected: _filterSubjects,
        onApply: (selected) => setState(() => _filterSubjects = selected),
      ),
    );
  }

  void _showWizard({AvailabilityGroup? group, VoidCallback? onEditSaved})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'AvailabilityWizard',
      builder: (context) => AvailabilityWizardDialog(
        existingGroup: group,
        teachers: widget.teachers,
        availableDays: widget.availableDays,
        defaultDate: widget.selectedDay,
        availabilities: widget.availabilities,
        openingDays: widget.openingDays,
        onEditSaved: onEditSaved,
        onCreate: widget.onCreate,
        onEdit: widget.onEdit,
        onDeleteSlot: widget.onDeleteSlot,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (!isOpenOn(widget.openingDays, widget.selectedDay, kPresenceMode) &&
        !isOpenOn(widget.openingDays, widget.selectedDay, kOnlineMode))
    {
      return LessonsClosedDay(
        leftovers: [
          for (final group in _dayGroups)
            AvailabilityCard(
              group: group,
              onEditRequested: widget.readOnly ? null : (onSaved) => _showWizard(group: group, onEditSaved: onSaved),
              onDelete: widget.readOnly ? null : () => widget.onDeleteGroup(group.slots),
            ),
        ],
      );
    }

    final groups = _filteredGroups;

    return TabContent(
      header: [
        LessonsToolbar(
          view: widget.view,
          onViewSelected: widget.onViewSelected,
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _searchText = value),
          searchHint: tr('Cerca docente...', 'Search teachers...'),
          actionLabel: tr('NUOVA DISPONIBILITÀ', 'NEW AVAILABILITY'),
          onAction: widget.readOnly || !widget.canAdd ? null : _showWizard,
        ),
        const TabHeaderGap(wide: 20, dense: 10),
        _buildFilters(),
        const TabHeaderGap(wide: 28, dense: 12),
      ],
      empty: groups.isEmpty ? _emptyCard : null,
      body: EntityCardGrid(
        denseWidth: kDenseWideCardWidth,
        children: [
          for (final group in groups)
            AvailabilityCard(
              group: group,
              onEditRequested: widget.readOnly ? null : (onSaved) => _showWizard(group: group, onEditSaved: onSaved),
              onDelete: widget.readOnly ? null : () => widget.onDeleteGroup(group.slots),
            ),
        ],
      ),
    );
  }
}
