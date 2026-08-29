import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_item.dart';
import '../models/booking_summary_item.dart';
import '../models/presence_group.dart';
import '../models/subject_request.dart';
import '../widgets/booking_fields_section.dart' show maxDailyMinutesPerDiscipline;
import '../widgets/subject_pick_row.dart';
import '../widgets/subject_request_tile.dart' show disciplineNames, ministrySubjectName;
import '../models/presence_item.dart';
import '../utils/booking_window.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/week_range.dart';
import '../utils/study_program_lookup.dart';
import '../../association/models/opening_day_item.dart';
import '../utils/opening_window.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/lesson_day_field.dart';
import '../widgets/lessons_form_fields.dart';
import '../widgets/lessons_toolbar.dart';
import '../widgets/band_schedule.dart';
import '../../../core/utils/time_bucket.dart';
import '../widgets/person_avatar.dart';
import '../widgets/presence_card.dart';
import '../widgets/subject_request_wizard.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _subjectListMaxHeight = 380;

const double _wizardMaxWidth = 820;
const double _stackMaxWidth =
    _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

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
      builder: (context) => _PresenceWizardDialog(
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

enum _WizardCard
{
  who(
    'Per chi e quando?',
    'Indica lo studente per cui stai effettuando la prenotazione e i giorni da prenotare. Puoi indicare anche più giornate.',
  ),
  modes(
    'Con quale modalità vuole fare lezione?',
    'In presenza, online, o entrambe.',
    width: 460,
  ),
  presenceHours(
    'Quando è in Associazione?',
    'Indica gli orari in cui lo studente sarà presente in Associazione.',
  ),
  presenceSubjects(
    'Che lezioni vuole fare in Associazione?',
    'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi disciplina offerta dall\'Associazione, oppure un servizio.',
  ),
  onlineHours(
    'Quando può essere presente online?',
    'Indica gli orari in cui lo studente è disponibile per essere seguito a distanza.',
  ),
  onlineSubjects(
    'Che lezioni vuole fare online?',
    'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi disciplina offerta dall\'Associazione, oppure un servizio.',
  );

  final String question;
  final String hint;

  final double width;

  const _WizardCard(this.question, this.hint, {this.width = _wizardMaxWidth});
}

class _PresenceWizardDialog extends StatefulWidget
{
  final PresenceItem? existingPresence;

  final List<PresenceItem> presences;
  final List<PersonItem> students;

  final List<PersonItem> teachers;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<AssociationSubjectItem> associationSubjects;
  final List<ServiceItem> services;
  final List<StudyProgramItem> studyPrograms;
  final List<DateTime> availableDays;
  final DateTime defaultDate;

  final List<OpeningDayItem> openingDays;

  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError) onCreateLessonRequest;
  final Future<PresenceItem?> Function(String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreatePresence;
  final Future<bool> Function(PresenceItem existing, String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEditPresence;
  final Future<bool> Function(PresenceItem presence, Function(String) onError) onDeletePresenceQuietly;
  final Future<bool> Function(int presenceId, Map<String, dynamic> subject, Function(String) onError) onCreateBooking;
  final Future<bool> Function(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) onEditBooking;
  final Future<bool> Function(BookingSummaryItem booking, int presenceId, Function(String) onError) onDeleteBooking;

  const _PresenceWizardDialog({
    this.existingPresence,
    required this.presences,
    required this.students,
    required this.teachers,
    required this.ministrySubjects,
    required this.associationSubjects,
    required this.services,
    required this.studyPrograms,
    required this.availableDays,
    required this.defaultDate,
    required this.openingDays,
    this.onCancelEdit,
    required this.onCreateLessonRequest,
    required this.onCreatePresence,
    required this.onEditPresence,
    required this.onDeletePresenceQuietly,
    required this.onCreateBooking,
    required this.onEditBooking,
    required this.onDeleteBooking,
  });

  @override
  State<_PresenceWizardDialog> createState() => _PresenceWizardDialogState();
}

class _PresenceWizardDialogState extends State<_PresenceWizardDialog>
{
  String? _selectedStudentTaxCode;

  Set<DateTime> _days = {};

  final Map<String, BandSchedule<PresenceItem>> _hours = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: BandSchedule<PresenceItem>(),
  };

  final Map<String, List<SubjectRequestDraft>> _requests = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: <SubjectRequestDraft>[],
  };

  final Set<String> _selectedModes = {};

  static const List<String> _subjectCategoryLabels = ['Materie', 'Discipline', 'Servizi'];

  static const int _ministryCategory = 0;
  static const int _disciplineCategory = 1;
  static const int _serviceCategory = 2;

  final Map<String, int> _subjectCategory = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: _ministryCategory,
  };

  // Each category keeps its own query, so switching tab back restores it.
  final Map<String, List<TextEditingController>> _subjectSearchControllers = {
    for (final mode in const [kPresenceMode, kOnlineMode])
      mode: List.generate(_subjectCategoryLabels.length, (_) => TextEditingController()),
  };

  final Map<String, List<String>> _subjectQueries = {
    for (final mode in const [kPresenceMode, kOnlineMode])
      mode: List.filled(_subjectCategoryLabels.length, ''),
  };

  final Map<String, ScrollController> _subjectScrollControllers = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: ScrollController(),
  };

  final List<(String, BookingSummaryItem)> _droppedBookings = [];

  int _cardIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  final Set<Object> _saved = {};

  static const List<String> _modes = [kPresenceMode, kOnlineMode];

  bool get _isEditing => widget.existingPresence != null;

  PersonItem? get _selectedStudent
  {
    final taxCode = _selectedStudentTaxCode;

    if (taxCode == null)
    {
      return null;
    }

    for (final student in widget.students)
    {
      if (student.fiscalCode == taxCode)
      {
        return student;
      }
    }

    return null;
  }

  List<MinistrySubjectItem> get _filteredMinistrySubjects
  {
    final student = _selectedStudent;

    if (student == null)
    {
      return const [];
    }

    final allowedIds = allowedMinistrySubjectIds(student, widget.studyPrograms);

    return widget.ministrySubjects.where((subject) => allowedIds.contains(subject.id)).toList();
  }

  List<DateTime> get _sortedDays
  {
    final days = _days.toList()..sort();

    return days;
  }

  OpeningWindow? _windowFor(String mode, TimeBucket bucket)
  {
    if (_days.isEmpty)
    {
      return null;
    }

    return sharedOpeningWindow(widget.openingDays, _sortedDays, mode, bucket);
  }

  List<String> _openModesOn(DateTime day)
  {
    return _modes.where((mode) => isOpenOn(widget.openingDays, day, mode)).toList();
  }

  bool _isDayOffered(DateTime day) => _openModesOn(day).isNotEmpty;

  String _dayTooltip(DateTime day)
  {
    return "L'associazione è chiusa ${formatAvailableDayLabel(day).toLowerCase()}.";
  }

  DateTime _firstOfferedDay()
  {
    final offered = widget.availableDays.where(_isDayOffered).toList();

    if (offered.isEmpty)
    {
      return widget.defaultDate;
    }

    return offered.firstWhere(
      (day) => !day.isBefore(widget.defaultDate),
      orElse: () => offered.first,
    );
  }

  @override
  void dispose()
  {
    for (final controller in _subjectScrollControllers.values)
    {
      controller.dispose();
    }

    for (final controllers in _subjectSearchControllers.values)
    {
      for (final controller in controllers)
      {
        controller.dispose();
      }
    }

    super.dispose();
  }

  @override
  void initState()
  {
    super.initState();

    final existing = widget.existingPresence;

    if (existing == null)
    {
      _days = {_firstOfferedDay()};

      return;
    }

    _selectedStudentTaxCode = existing.studentTaxCode;
    _days = {existing.date};

    for (final presence in widget.presences)
    {
      if (presence.studentTaxCode != existing.studentTaxCode ||
          !isSameDate(presence.date, existing.date))
      {
        continue;
      }

      final bucket = bucketFor(presence.startTime);

      if (bucket != null)
      {
        _hours[presence.mode]!.addStored(
          bucket,
          BandStretch<PresenceItem>(
            startTime: presence.startTime,
            endTime: presence.endTime,
            existing: presence,
          ),
        );
      }

      _selectedModes.add(presence.mode);

      for (final booking in presence.bookings)
      {
        _requests[presence.mode]!.add(SubjectRequestDraft.fromBooking(
          booking,
          ministrySubjectName: ministrySubjectName(
            widget.ministrySubjects,
            booking.ministrySubjectId,
            fallback: '',
          ),
        ));
      }
    }

    _reconcileHours();
  }

  void _reconcileHours()
  {
    for (final mode in _modes)
    {
      _hours[mode]!.reconcile((bucket) => _windowFor(mode, bucket));
    }
  }

  void _selectDays(Set<DateTime> days)
  {
    setState(()
    {
      _days = days;
      _reconcileHours();
    });
  }

  void _goToCard(int index)
  {
    if (index > _cardIndex && _blockedReason(_cards[_cardIndex]) != null)
    {
      return;
    }

    setState(()
    {
      _movingForward = index > _cardIndex;
      _cardIndex = index;
    });
  }

  String? _blockedReason(_WizardCard card)
  {
    switch (card)
    {
      case _WizardCard.who:
        if (_selectedStudentTaxCode == null)
        {
          return 'Scegli lo studente per andare avanti.';
        }

        if (_days.isEmpty)
        {
          return 'Scegli almeno un giorno per andare avanti.';
        }

      case _WizardCard.modes:
        if (_effectiveModes.isEmpty)
        {
          return 'Scegli almeno una modalità per andare avanti.';
        }

      case _WizardCard.presenceHours:
      case _WizardCard.onlineHours:
        final mode =
            card == _WizardCard.presenceHours ? kPresenceMode : kOnlineMode;

        if (_hours[mode]!.isEmpty)
        {
          return 'Indica almeno un orario '
              '${modeLabel(mode).toLowerCase()} per andare avanti.';
        }

      case _WizardCard.presenceSubjects:
        break;

      case _WizardCard.onlineSubjects:
        if (_requests[kOnlineMode]!.isEmpty)
        {
          return 'Scegli almeno una materia per andare avanti.';
        }
    }

    return null;
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();

    if (_isEditing)
    {
      widget.onCancelEdit?.call();
    }
  }

  int _minutesAsked(String mode)
  {
    var minutes = 0;

    for (final request in _requests[mode]!)
    {
      minutes += request.duration ?? 0;
    }

    return minutes;
  }

  Map<int, int> _minutesByDiscipline(String mode, {SubjectRequestDraft? skip})
  {
    final minutes = <int, int>{};

    for (final request in _requests[mode]!)
    {
      if (identical(request, skip))
      {
        continue;
      }

      for (final discipline in request.disciplineIds)
      {
        minutes[discipline] = (minutes[discipline] ?? 0) + (request.duration ?? 0);
      }
    }

    return minutes;
  }

  void _resetForm()
  {
    setState(()
    {
      _selectedStudentTaxCode = null;
      _days = {_firstOfferedDay()};
      _selectedModes.clear();

      for (final mode in _modes)
      {
        _hours[mode]!.clear();
        _requests[mode]!.clear();

        _subjectCategory[mode] = _ministryCategory;

        for (final controller in _subjectSearchControllers[mode]!)
        {
          controller.clear();
        }

        _subjectQueries[mode]!.fillRange(0, _subjectQueries[mode]!.length, '');
      }

      _droppedBookings.clear();
      _saved.clear();
      _cardIndex = 0;
      _movingForward = false;
    });
  }

  bool _validate()
  {
    void refuse(String message)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }

    if (_selectedStudentTaxCode == null)
    {
      refuse('Seleziona uno studente.');

      return false;
    }

    if (_days.isEmpty)
    {
      refuse('Seleziona almeno una giornata.');

      return false;
    }

    if (_effectiveModes.contains(kOnlineMode) &&
        _hours[kOnlineMode]!.isNotEmpty &&
        _requests[kOnlineMode]!.isEmpty)
    {
      refuse('Scegli almeno una materia online.');

      return false;
    }

    if (_modes.every((mode) => _hours[mode]!.isEmpty))
    {
      refuse('Indica almeno un orario, in presenza od online.');

      return false;
    }

    for (final mode in _modes)
    {
      final label = modeLabel(mode).toLowerCase();
      final requests = _requests[mode]!;

      if (requests.isEmpty)
      {
        continue;
      }

      if (_hours[mode]!.isEmpty)
      {
        refuse('Hai chiesto delle materie $label senza indicare gli orari.');

        return false;
      }

      for (final request in requests)
      {
        if (!request.isComplete)
        {
          refuse('Indica la durata di ${request.displayName} ($label).');

          return false;
        }

        if (request.asksForTopicAndTag && request.tags.isEmpty)
        {
          refuse('Indica il tipo di lezione di ${request.displayName} ($label).');

          return false;
        }
      }

      final byDiscipline = _minutesByDiscipline(mode);

      for (final entry in byDiscipline.entries)
      {
        if (entry.value > maxDailyMinutesPerDiscipline)
        {
          refuse('${_disciplineName(entry.key)} ($label): ${formatMinutes(entry.value)} in un '
              'giorno. Non si possono richiedere più di '
              '${formatMinutes(maxDailyMinutesPerDiscipline)} minuti al giorno per una disciplina.');

          return false;
        }
      }

      final asked = _minutesAsked(mode);
      final given = _hours[mode]!.totalMinutes;

      if (asked > given)
      {
        refuse('Il totale delle ore di lezione richieste supera il tempo di permanenza dello '
            'studente in Associazione.');

        return false;
      }
    }

    return true;
  }

  Future<void> _save() async
  {
    if (_isSaving || !_validate())
    {
      return;
    }

    final studentTaxCode = _selectedStudentTaxCode!;

    setState(()
    {
      _isSaving = true;

      for (final schedule in _hours.values)
      {
        schedule.fuse();
      }
    });

    void showError(String message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    }

    Future<bool> once(Object key, Future<bool> Function() write) async
    {
      if (_saved.contains(key))
      {
        return true;
      }

      final success = await write();

      if (success)
      {
        _saved.add(key);
      }

      return success;
    }

    void stop()
    {
      if (mounted)
      {
        setState(() => _isSaving = false);
      }
    }

    if (!_isEditing)
    {
      for (final day in _sortedDays)
      {
        if (_saved.contains(day))
        {
          continue;
        }

        final written = await widget.onCreateLessonRequest(
          studentTaxCode,
          day,
          _modePayloads(),
          showError,
        );

        if (!written)
        {
          stop();

          return;
        }

        _saved.add(day);
      }

      _finishSave();

      return;
    }

    for (final (mode, booking) in _droppedBookings)
    {
      final presence = _presenceOf(booking, mode);

      if (presence == null)
      {
        continue;
      }

      if (!await once(booking, () => widget.onDeleteBooking(booking, presence.id, showError)))
      {
        stop();

        return;
      }
    }

    for (final mode in _modes)
    {
      for (final presence in _hours[mode]!.dropped)
      {
        if (!await once(presence, () => widget.onDeletePresenceQuietly(presence, showError)))
        {
          stop();

          return;
        }
      }
    }

    for (final day in _sortedDays)
    {
      for (final mode in _modes)
      {
        int? firstPresenceId;

        for (final stretch in _hours[mode]!.all)
        {
          final existing = stretch.existing;
          final isMove = existing != null && isSameDate(day, existing.date);
          final key = (day, mode, stretch);

          if (isMove)
          {
            firstPresenceId ??= existing.id;

            if (!await once(key, () => widget.onEditPresence(existing, studentTaxCode, day, mode, stretch.startTime, stretch.endTime, showError)))
            {
              stop();

              return;
            }

            continue;
          }

          if (_saved.contains(key))
          {
            firstPresenceId ??= _createdIds[key];

            continue;
          }

          final created = await widget.onCreatePresence(
            studentTaxCode,
            day,
            mode,
            stretch.startTime,
            stretch.endTime,
            showError,
          );

          if (created == null)
          {
            stop();

            return;
          }

          _saved.add(key);
          _createdIds[key] = created.id;
          firstPresenceId ??= created.id;
        }

        if (firstPresenceId == null)
        {
          continue;
        }

        for (final request in _requests[mode]!)
        {
          final existing = request.existing;
          final key = (day, mode, request);

          if (existing != null && isSameDate(day, widget.existingPresence!.date))
          {
            if (!await once(key, () => widget.onEditBooking(existing, firstPresenceId!, request.toJson(), showError)))
            {
              stop();

              return;
            }

            continue;
          }

          if (!await once(key, () => widget.onCreateBooking(firstPresenceId!, request.toJson(), showError)))
          {
            stop();

            return;
          }
        }
      }
    }

    _finishSave();
  }

  void _finishSave()
  {
    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    CustomSnackBar.show(
      context: context,
      message: _isEditing
          ? 'Richiesta modificata con successo!'
          : (_days.length == 1
              ? 'Richiesta creata con successo!'
              : '${_days.length} richieste create con successo!'),
      isError: false,
    );

    if (_isEditing)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
  }

  List<Map<String, dynamic>> _modePayloads()
  {
    return [
      for (final mode in _modes)
        if (_effectiveModes.contains(mode) && _hours[mode]!.all.isNotEmpty)
          {
            'mode': mode,
            'slots': [
              for (final stretch in _hours[mode]!.all)
                {
                  'start_time': formatTimeOfDay(stretch.startTime),
                  'end_time': formatTimeOfDay(stretch.endTime),
                },
            ],
            'subjects': [
              for (final request in _requests[mode]!) request.toJson(),
            ],
          },
    ];
  }

  PresenceItem? _presenceOf(BookingSummaryItem booking, String mode)
  {
    for (final presence in widget.presences)
    {
      if (presence.bookings.any((row) => row.id == booking.id))
      {
        return presence;
      }
    }

    return null;
  }

  final Map<Object, int> _createdIds = {};

  Widget _buildWho()
  {
    final studentOptions = activeCollaborators(widget.students)
        .map((student) => SelectionOption<String>(
              value: student.fiscalCode,
              label: '${student.firstName} ${student.lastName}',
              leading: PersonAvatar(person: student, size: PersonAvatar.pickerSize),
              subtitle: currentSchoolAndProgramLabel(student),
            ))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutocompleteField<String>(
          label: 'Studente',
          hint: 'Cerca studente per nome...',
          icon: null,
          options: studentOptions,
          value: _selectedStudentTaxCode,
          onSelected: (value) => setState(() => _selectedStudentTaxCode = value),
          onCleared: () => setState(() => _selectedStudentTaxCode = null),
        ),
        const SizedBox(height: 20),
        LessonDayField(
          days: widget.availableDays,
          values: _days,
          onChanged: _selectDays,
          summary: (count) => 'La prenotazione verrà replicata su tutte le $count giornate selezionate.',
          isEnabled: _isDayOffered,
          disabledTooltip: _dayTooltip,
        ),
      ],
    );
  }

  static const double _fixedFactsWidth = 560;

  Widget _buildFixedFacts()
  {
    final presence = widget.existingPresence!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: WizardFact(label: 'Studente', value: presence.student.fullName)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: WizardFact(label: 'Giornata', value: formatAvailableDayLabel(presence.date))),
      ],
    );
  }

  Widget _buildHours(String mode)
  {
    final open = TimeBucket.values.any((bucket) => _windowFor(mode, bucket) != null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!open)
          Text(
            "L'associazione non apre ${modeLabel(mode).toLowerCase()} in questa giornata.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...[
          BandScheduleField<PresenceItem>(
            schedule: _hours[mode]!,
            windowFor: (bucket) => _windowFor(mode, bucket),
            offLabel: 'Non presente',
            minimumMinutes: kMinimumBandMinutes,
            onChanged: () => setState(_dropSubjectsWithoutHours),
          ),
        ],
      ],
    );
  }

  Widget _buildHint(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  List<AssociationSubjectItem> get _standaloneDisciplines
  {
    final covered = <int>{
      for (final subject in _filteredMinistrySubjects)
        for (final discipline in subject.associationSubjects) discipline.id,
    };

    return widget.associationSubjects
        .where((discipline) => !covered.contains(discipline.id))
        .toList();
  }

  Widget _buildSubjectsCard(String mode)
  {
    if (_selectedStudentTaxCode == null)
    {
      return _buildHint('Scegli prima lo studente.');
    }

    final category = _subjectCategory[mode] ?? _ministryCategory;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedTabs(
          labels: _subjectCategoryLabels,
          selectedIndex: category,
          onSelected: (index) => setState(() => _subjectCategory[mode] = index),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _subjectListMaxHeight),
          child: Scrollbar(
            controller: _subjectScrollControllers[mode],
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _subjectScrollControllers[mode],
              padding: const EdgeInsets.only(right: 12),
              child: switch (category)
              {
                _ministryCategory => _buildMinistryList(mode),
                _disciplineCategory => _buildDisciplineList(mode),
                _ => _buildServiceList(mode),
              },
            ),
          ),
        ),
      ],
    );
  }

  String _summaryOf(SubjectRequestDraft request)
  {
    final parts = <String>[];

    if (request.asksForDisciplines && _hasSeveralDisciplines(request))
    {
      parts.add(disciplineNames(widget.ministrySubjects, request).join(', '));
    }

    if (request.duration != null)
    {
      parts.add(formatMinutes(request.duration!));
    }

    return parts.join(' · ');
  }

  String _sayBoth(String? asked, String? description)
  {
    return [
      if (asked != null && asked.isNotEmpty) asked,
      ?descriptionOrNull(description),
    ].join(' · ');
  }

  String _disciplineName(int id)
  {
    for (final subject in widget.ministrySubjects)
    {
      for (final discipline in subject.associationSubjects)
      {
        if (discipline.id == id)
        {
          return discipline.name;
        }
      }
    }

    for (final mode in _modes)
    {
      for (final request in _requests[mode]!)
      {
        if (request.associationSubjectId == id &&
            request.associationSubjectName != null)
        {
          return request.associationSubjectName!;
        }
      }
    }

    return 'Una disciplina';
  }

  bool _hasSeveralDisciplines(SubjectRequestDraft request)
  {
    for (final subject in widget.ministrySubjects)
    {
      if (subject.id == request.ministrySubjectId)
      {
        return subject.associationSubjects.length > 1;
      }
    }

    return false;
  }

  SubjectRequestDraft? _chosen(String mode, bool Function(SubjectRequestDraft) matches)
  {
    for (final request in _requests[mode]!)
    {
      if (matches(request))
      {
        return request;
      }
    }

    return null;
  }

  Widget _buildEmptyCategory(String message) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _buildHint(message),
      );

  Widget _buildCategorySearch(String mode, int category, String hint)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSearchField(
        controller: _subjectSearchControllers[mode]![category],
        hintText: hint,
        onChanged: (value) => setState(() => _subjectQueries[mode]![category] = value),
      ),
    );
  }

  bool _matchesQuery(String name, String mode, int category)
  {
    return name.toLowerCase().contains(_subjectQueries[mode]![category].toLowerCase());
  }

  Widget _buildPickRow({
    required String mode,
    required String name,
    required SubjectRequestDraft? chosen,
    required SubjectRequestDraft Function() onPick,
    required VoidCallback onDrop,
    String? description,
  })
  {
    return SubjectPickRow(
      name: name,
      subtitle: _sayBoth(chosen == null ? null : _summaryOf(chosen), description),
      selected: chosen != null,
      hasChoice: chosen != null,
      onSelected: (selected) => selected
          ? _openRequestWizard(mode, onPick())
          : onDrop(),
      onEditDisciplines: () => chosen == null
          ? null
          : _openRequestWizard(mode, chosen, editing: true),
    );
  }

  Widget _buildMinistryList(String mode)
  {
    final all = _filteredMinistrySubjects;

    if (all.isEmpty)
    {
      return _buildEmptyCategory(
        'Il percorso di studi dello studente non ha materie collegate.',
      );
    }

    final subjects = all
        .where((subject) => _matchesQuery(subject.name, mode, _ministryCategory))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySearch(mode, _ministryCategory, 'Cerca materia...'),
        if (subjects.isEmpty)
          _buildEmptyCategory('Nessuna materia trovata per questa ricerca.'),
        for (final subject in subjects)
          _buildPickRow(
            mode: mode,
            name: subject.name,
            chosen: _requestFor(mode, subject.id),
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.ministrySubject,
              ministrySubjectId: subject.id,
              associationSubjectIds: {
                if (subject.associationSubjects.length == 1)
                  subject.associationSubjects.single.id,
              },
            )..ministrySubjectName = subject.name,
            onDrop: () => _dropSubject(mode, subject.id),
          ),
      ],
    );
  }

  Widget _buildDisciplineList(String mode)
  {
    final all = _standaloneDisciplines;

    if (all.isEmpty)
    {
      return _buildEmptyCategory(
        'Tutte le discipline sono già sotto le materie dello studente.',
      );
    }

    final disciplines = all
        .where((discipline) => _matchesQuery(discipline.name, mode, _disciplineCategory))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySearch(mode, _disciplineCategory, 'Cerca disciplina...'),
        if (disciplines.isEmpty)
          _buildEmptyCategory('Nessuna disciplina trovata per questa ricerca.'),
        for (final discipline in disciplines)
          _buildPickRow(
            mode: mode,
            name: discipline.name,
            description: discipline.description,
            chosen: _chosen(
              mode,
              (request) => request.associationSubjectId == discipline.id,
            ),
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.associationSubject,
              associationSubjectId: discipline.id,
              associationSubjectName: discipline.name,
            ),
            onDrop: () => _dropWhere(
              mode,
              (request) => request.associationSubjectId == discipline.id,
            ),
          ),
      ],
    );
  }

  Widget _buildServiceList(String mode)
  {
    if (widget.services.isEmpty)
    {
      return _buildEmptyCategory('Nessun servizio disponibile.');
    }

    final services = widget.services
        .where((service) => _matchesQuery(service.name, mode, _serviceCategory))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySearch(mode, _serviceCategory, 'Cerca servizio...'),
        if (services.isEmpty)
          _buildEmptyCategory('Nessun servizio trovato per questa ricerca.'),
        for (final service in services)
          _buildPickRow(
            mode: mode,
            name: service.name,
            description: service.description,
            chosen: _chosen(
              mode,
              (request) => request.serviceName == service.name,
            ),
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.service,
              serviceName: service.name,
            ),
            onDrop: () => _dropWhere(
              mode,
              (request) => request.serviceName == service.name,
            ),
          ),
      ],
    );
  }

  void _openRequestWizard(
    String mode,
    SubjectRequestDraft draft, {
    bool editing = false,
  })
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: mode,
        draft: draft,
        ministrySubjects: widget.ministrySubjects,
        teachers: activeCollaborators(widget.teachers),
        isEditing: editing,
        minutesAvailable: _hours[mode]!.totalMinutes,
        minutesTakenByOthers: _minutesAsked(mode) -
            (editing ? (draft.duration ?? 0) : 0),
        minutesByDisciplineTakenByOthers: _minutesByDiscipline(
          mode,
          skip: editing ? draft : null,
        ),
        onSave: (saved) async
        {
          setState(()
          {
            if (editing)
            {
              final at = _requests[mode]!.indexOf(draft);

              if (at >= 0)
              {
                _requests[mode]![at] = saved;

                return;
              }
            }

            _requests[mode]!.add(saved);
          });

          return true;
        },
      ),
    );
  }

  void _dropWhere(String mode, bool Function(SubjectRequestDraft) matches)
  {
    final at = _requests[mode]!.indexWhere(matches);

    if (at >= 0)
    {
      _dropRequest(mode, at);
    }
  }

  void _dropSubject(String mode, int ministrySubjectId)
  {
    final requests = _requests[mode]!;

    for (var index = 0; index < requests.length; index++)
    {
      if (requests[index].ministrySubjectId == ministrySubjectId)
      {
        setState(() => _dropRequest(mode, index));

        return;
      }
    }
  }

  SubjectRequestDraft? _requestFor(String mode, int ministrySubjectId)
  {
    for (final request in _requests[mode]!)
    {
      if (request.ministrySubjectId == ministrySubjectId)
      {
        return request;
      }
    }

    return null;
  }

  void _dropSubjectsWithoutHours()
  {
    for (final mode in _modes)
    {
      if (_hours[mode]!.isNotEmpty)
      {
        continue;
      }

      for (var index = _requests[mode]!.length - 1; index >= 0; index--)
      {
        _dropRequest(mode, index);
      }
    }
  }

  final Map<SubjectRequestDraft, TextEditingController> _topicControllers = {};
  final Map<SubjectRequestDraft, TextEditingController> _notesControllers = {};

  void _dropRequest(String mode, int index)
  {
    final request = _requests[mode]!.removeAt(index);

    _topicControllers.remove(request)?.dispose();
    _notesControllers.remove(request)?.dispose();

    final existing = request.existing;

    if (existing != null)
    {
      _droppedBookings.add((mode, existing));
    }
  }

  List<String> get _openModesOnSelected
  {
    if (_days.isEmpty)
    {
      return const [];
    }

    return _modes
        .where((mode) => _sortedDays.every(
              (day) => isOpenOn(widget.openingDays, day, mode),
            ))
        .toList();
  }

  Set<String> get _effectiveModes
  {
    final open = _openModesOnSelected;

    if (open.length <= 1)
    {
      return open.toSet();
    }

    return _selectedModes.where(open.contains).toSet();
  }

  bool get _asksForMode => _openModesOnSelected.length > 1;

  List<_WizardCard> get _cards
  {
    final chosen = _effectiveModes;

    return [
      _WizardCard.who,
      if (_asksForMode) _WizardCard.modes,
      if (chosen.contains(kPresenceMode)) ...[
        _WizardCard.presenceHours,
        _WizardCard.presenceSubjects,
      ],
      if (chosen.contains(kOnlineMode)) ...[
        _WizardCard.onlineHours,
        _WizardCard.onlineSubjects,
      ],
    ];
  }

  Widget _buildModesCard()
  {
    final open = _openModesOnSelected;
    final chosen = _effectiveModes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final mode in open)
              AppSelectableChip(
                label: modeLabel(mode),
                selected: chosen.contains(mode),
                onSelected: (selected) => _toggleMode(mode, selected),
              ),
          ],
        ),
      ],
    );
  }

  void _toggleMode(String mode, bool selected)
  {
    setState(()
    {
      if (selected)
      {
        _selectedModes.add(mode);

        return;
      }

      _selectedModes.remove(mode);
      _hours[mode]!.clear();
      _requests[mode]!.clear();
    });
  }

  double _widthOf(_WizardCard card)
  {
    if (card == _WizardCard.who && _isEditing)
    {
      return _fixedFactsWidth;
    }

    return card.width;
  }

  Widget _buildCard(_WizardCard card)
  {
    return switch (card)
    {
      _WizardCard.who => _isEditing ? _buildFixedFacts() : _buildWho(),
      _WizardCard.modes => _buildModesCard(),
      _WizardCard.presenceHours => _buildHours(kPresenceMode),
      _WizardCard.presenceSubjects => _buildSubjectsCard(kPresenceMode),
      _WizardCard.onlineHours => _buildHours(kOnlineMode),
      _WizardCard.onlineSubjects => _buildSubjectsCard(kOnlineMode),
    };
  }

  @override
  Widget build(BuildContext context)
  {
    final cards = _cards;

    if (_cardIndex >= cards.length)
    {
      _cardIndex = cards.length - 1;
    }

    return AppDialogStack(
      eyebrow: 'Passo ${_cardIndex + 1} di ${cards.length}',
      title: _isEditing ? 'Modifica richiesta' : 'Nuova richiesta',
      onClose: _closeDialog,
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _wizardMaxWidth),
            child: AppDialogPill(
              expand: true,
              child: PersonEditGuide(
                question: cards[_cardIndex].question,
                hint: cards[_cardIndex].hint,
              ),
            ),
          ),
        ),
        AppCarouselFrame(
          index: _cardIndex,
          movingForward: _movingForward,
          maxContentWidth: _widthOf(cards[_cardIndex]),
          canGoBack: _cardIndex > 0,
          canGoForward: _cardIndex < cards.length - 1,
          forwardBlockedReason: _blockedReason(cards[_cardIndex]),
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(expand: true, child: _buildCard(cards[_cardIndex])),
        ),
      ],
    );
  }
}
