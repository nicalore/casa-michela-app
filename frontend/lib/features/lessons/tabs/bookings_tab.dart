import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../../people/models/person_item.dart';
import '../models/booking_summary_item.dart';
import '../models/presence_group.dart';
import '../models/presence_item.dart';
import '../utils/opening_window.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/lessons_toolbar.dart';
import '../widgets/presence_card.dart';
import '../widgets/presence_wizard.dart';

class BookingsTab extends StatefulWidget
{
  final List<PresenceItem> presences;
  final List<PersonItem> students;

  final List<PersonItem> teachers;

  final List<MinistrySubjectItem> ministrySubjects;

  final List<AssociationSubjectItem> associationSubjects;
  final List<ServiceItem> services;

  final List<StudyProgramItem> studyPrograms;

  final List<DateTime> availableDays;
  final DateTime selectedDay;

  final List<OpeningDayItem> openingDays;

  final LessonsDayView view;
  final ValueChanged<LessonsDayView> onViewSelected;

  final Future<bool> Function(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError) onCreateLessonRequest;
  final Future<PresenceItem?> Function(String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreatePresence;
  final Future<bool> Function(PresenceItem existing, String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEditPresence;
  final Future<bool> Function(PresenceItem presence, Function(String) onError) onDeletePresenceQuietly;
  final Future<bool> Function(BookingSummaryItem booking, int presenceId, Function(String) onError) onDeleteBookingQuietly;
  final void Function(List<PresenceItem> slots) onDeleteGroup;
  final Future<bool> Function(int presenceId, Map<String, dynamic> subject, Function(String) onError) onCreateBooking;
  final Future<bool> Function(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) onEditBooking;

  const BookingsTab({
    super.key,
    required this.presences,
    required this.students,
    required this.teachers,
    required this.ministrySubjects,
    required this.associationSubjects,
    required this.services,
    required this.studyPrograms,
    required this.availableDays,
    required this.selectedDay,
    required this.openingDays,
    required this.view,
    required this.onViewSelected,
    required this.onCreateLessonRequest,
    required this.onCreatePresence,
    required this.onEditPresence,
    required this.onDeletePresenceQuietly,
    required this.onDeleteBookingQuietly,
    required this.onDeleteGroup,
    required this.onCreateBooking,
    required this.onEditBooking,
  });

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  String? _filterMode;
  TimeBucket? _filterBucket;

  Set<String> _filterSubjects = {};

  bool get _hasFilters => _filterMode != null || _filterBucket != null || _filterSubjects.isNotEmpty;

  List<PresenceGroup> get _dayGroups
  {
    final selectedDay = widget.selectedDay;

    final onTheDay = widget.presences
        .where((presence) => isSameDate(presence.date, selectedDay))
        .toList();

    final groups = groupPresences(onTheDay);

    groups.sort((a, b)
    {
      final startComparison = a.startMinutes.compareTo(b.startMinutes);

      if (startComparison != 0)
      {
        return startComparison;
      }

      return a.student.fullName.compareTo(b.student.fullName);
    });

    return groups;
  }

  List<PresenceGroup> get _filteredGroups
  {
    final query = _searchText.toLowerCase();

    return _dayGroups.where((group)
    {
      final matchesQuery = group.student.fullName.toLowerCase().contains(query) ||
          group.booker.fullName.toLowerCase().contains(query);

      return matchesQuery && _matchesFilters(group);
    }).toList();
  }

  Set<String> _disciplinesOf(PresenceGroup group)
  {
    final names = <String>{};

    for (final slot in group.slots)
    {
      for (final booking in slot.bookings)
      {
        names.addAll(booking.associationSubjects.map((subject) => subject.name));

        final single = booking.associationSubject;

        if (single != null)
        {
          names.add(single.name);
        }
      }
    }

    return names;
  }

  List<String> get _subjectOptions
  {
    final subjects = <String>{};

    for (final group in _dayGroups)
    {
      subjects.addAll(_disciplinesOf(group));
    }

    final sorted = subjects.toList()..sort();

    return sorted;
  }

  bool _matchesFilters(PresenceGroup group)
  {
    if (_filterSubjects.isNotEmpty &&
        !_disciplinesOf(group).any(_filterSubjects.contains))
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
  void didUpdateWidget(BookingsTab oldWidget)
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
      return 'Nessuna richiesta corrisponde ai filtri scelti.';
    }

    if (_searchText.isNotEmpty)
    {
      return 'Nessuno studente trovato in questa giornata.';
    }

    return 'Nessuna richiesta in questa giornata.';
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

  void _showPresenceWizard({PresenceItem? presence, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RequestWizard',
      builder: (context) => PresenceWizardDialog(
        existingPresence: presence,
        presences: widget.presences,
        openingDays: widget.openingDays,
        students: widget.students,
        teachers: widget.teachers,
        ministrySubjects: widget.ministrySubjects,
        associationSubjects: widget.associationSubjects,
        services: widget.services,
        studyPrograms: widget.studyPrograms,
        availableDays: widget.availableDays,
        defaultDate: widget.selectedDay,
        onCancelEdit: onCancelEdit,
        onCreateLessonRequest: widget.onCreateLessonRequest,
        onCreatePresence: widget.onCreatePresence,
        onEditPresence: widget.onEditPresence,
        onDeletePresenceQuietly: widget.onDeletePresenceQuietly,
        onCreateBooking: widget.onCreateBooking,
        onEditBooking: widget.onEditBooking,
        onDeleteBooking: widget.onDeleteBookingQuietly,
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
        leftovers: [for (final group in _dayGroups) _buildRequestCard(group)],
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
          searchHint: 'Cerca studente o prenotante...',
          actionLabel: 'NUOVA RICHIESTA',
          onAction: _showPresenceWizard,
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
              children: [for (final group in groups) _buildRequestCard(group)],
            ),
    );
  }

  Widget _buildRequestCard(PresenceGroup group)
  {
    return PresenceCard(
      group: group,
      ministrySubjects: widget.ministrySubjects,
      students: widget.students,
      studyPrograms: widget.studyPrograms,
      teachers: widget.teachers,
      onEditRequested: (onCancel) => _showPresenceWizard(presence: group.first, onCancelEdit: onCancel),
      onDelete: () => widget.onDeleteGroup(group.slots),
      onEditSubject: widget.onEditBooking,
      onDeleteSubject: widget.onDeleteBookingQuietly,
    );
  }
}
