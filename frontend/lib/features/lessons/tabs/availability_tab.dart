import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../core/utils/time_bucket.dart';
import '../../association/models/opening_day_item.dart';
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

      return a.teacher.fullName.compareTo(b.teacher.fullName);
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

    final sorted = subjects.toList()..sort();

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

  String get _emptyMessage
  {
    if (_hasFilters)
    {
      return 'Nessuna disponibilità corrisponde ai filtri scelti.';
    }

    if (_searchText.isNotEmpty)
    {
      return 'Nessun docente trovato in questa giornata.';
    }

    return 'Nessuna disponibilità in questa giornata.';
  }

  Widget _buildFilters()
  {
    final subjects = _subjectOptions;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppFilterPill<String>.filter(
          prefix: 'Modalità',
          hint: 'Presenza e online',
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
          prefix: 'Quando',
          hint: 'Tutta la giornata',
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
            label: 'Discipline',
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
        title: 'Filtra per disciplina interna',
        hint: 'Es. Aritmetica',
        options: [
          for (final subject in subjects)
            MultiSelectFilterOption(value: subject, label: subject),
        ],
        initialSelected: _filterSubjects,
        onApply: (selected) => setState(() => _filterSubjects = selected),
      ),
    );
  }

  void _showWizard({AvailabilityGroup? group, VoidCallback? onCancelEdit})
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
        onCancelEdit: onCancelEdit,
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
        day: widget.selectedDay,
        message: '',
        leftovers: [
          for (final group in _dayGroups)
            AvailabilityCard(
              group: group,
              onEditRequested: (onCancel) => _showWizard(group: group, onCancelEdit: onCancel),
              onDelete: () => widget.onDeleteGroup(group.slots),
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
          searchHint: 'Cerca docente...',
          actionLabel: 'NUOVA DISPONIBILITÀ',
          onAction: _showWizard,
        ),
        const SizedBox(height: 20),
        _buildFilters(),
        const SizedBox(height: 28),
      ],
      body: groups.isEmpty
          ? PageTransitionItem(
              slot: PageTransitionItem.list,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    _emptyMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.trialMutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          : EntityCardGrid(
              children: [
                for (final group in groups)
                  AvailabilityCard(
                    group: group,
                    onEditRequested: (onCancel) => _showWizard(group: group, onCancelEdit: onCancel),
                    onDelete: () => widget.onDeleteGroup(group.slots),
                  ),
              ],
            ),
    );
  }
}
