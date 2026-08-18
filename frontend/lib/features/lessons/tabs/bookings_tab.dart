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

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// How tall the entry list may get before it starts scrolling on its own. Below
// this it sits comfortably; above it, the card would become a page to walk
// through to reach the arrows.
const double _subjectListMaxHeight = 380;

// The dialog's size is taken from the "who and when" card, the one that needs
// it most, and kept by everything else. Only the two-modes card sits narrower.
const double _wizardMaxWidth = 820;
const double _stackMaxWidth =
    _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

class BookingsTab extends StatefulWidget
{
  final List<PresenceItem> presences;
  final List<PersonItem> students;

  // Who could teach what is asked for, offered as a preference on each subject.
  final List<PersonItem> teachers;

  final List<MinistrySubjectItem> ministrySubjects;

  // Le altre due categorie fra cui si puo' chiedere un'ora: le discipline a
  // catalogo e i servizi.
  final List<AssociationSubjectItem> associationSubjects;
  final List<ServiceItem> services;

  final List<StudyProgramItem> studyPrograms;

  // The open days of the booking window, and the one the rail is on. The day is
  // chosen out in the rail now, as a section of the page: the tab is told which
  // one it is showing rather than asking for it itself.
  final List<DateTime> availableDays;
  final DateTime selectedDay;

  // When the association is open, over those same days: a day it does not open
  // on is a day nobody can be present.
  final List<OpeningDayItem> openingDays;

  // The switch stands in this toolbar but chooses which tab you are in, so the
  // page holds the answer: named by the tab, it would be a different switch on
  // each of the two and its pill would have nowhere to slide from.
  final LessonsDayView view;
  final ValueChanged<LessonsDayView> onViewSelected;

  // Creating a whole day in a single transaction: the bands and the lessons of
  // every requested mode. Editing goes through the per-row endpoints instead,
  // which touch one row at a time.
  final Future<bool> Function(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError) onCreateLessonRequest;
  final Future<PresenceItem?> Function(String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreatePresence;
  final Future<bool> Function(PresenceItem existing, String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEditPresence;
  final Future<bool> Function(PresenceItem presence, Function(String) onError) onDeletePresenceQuietly;
  final Future<bool> Function(BookingSummaryItem booking, int presenceId, Function(String) onError) onDeleteBookingQuietly;
  // A whole day's request thrown away, both ways of being there and everything
  // asked for inside them: it is what the card's ELIMINA does.
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

  // What the day is being looked at through, the same three the availabilities
  // are looked at through: a day is read on either side of the same question —
  // who is offering, who is asking — and it is read the same way.
  String? _filterMode;
  TimeBucket? _filterBucket;

  // Several at a time, and a request passes on any of them: a filter set to
  // Matematica and Fisica asks who wants either, which is the question one has
  // when looking for who to put on a teacher.
  Set<String> _filterSubjects = {};

  bool get _hasFilters => _filterMode != null || _filterBucket != null || _filterSubjects.isNotEmpty;

  // Scoped to the day selected in the rail, so the admin works one day at a
  // time, and gathered by pupil: a pupil here in the afternoon and online in
  // the evening is one request with two stretches of hours in it.
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

  // The same, through the search field and the three pills.
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

  // The disciplines a request asks for, by name. A ministry subject lists them
  // underneath it and a discipline asked on its own is one; a service is
  // neither, and brings none — which is why a day of nothing but services has
  // no discipline pill to open.
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

  // Only the disciplines actually asked for on this day. A menu offering every
  // discipline the association teaches would be mostly answers that empty the
  // page.
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

  // The mode and the band are asked of one stretch: "online di mattina" means
  // one stretch that is both, not one online and another in the morning. The
  // discipline is asked of the whole request, which is where it hangs.
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

    // The rail moves to another day and the disciplines asked for on it are not
    // the same ones. One kept from the day before would go on shortening the
    // list without being anywhere in the window that is supposed to hold it.
    if (_filterSubjects.isNotEmpty)
    {
      final available = _subjectOptions.toSet();

      _filterSubjects = _filterSubjects.where(available.contains).toSet();
    }
  }

  // Said in the words of whatever emptied the page: a day with nothing on it
  // and a day whose every card is behind a filter are not the same thing.
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

  // Three ways of asking for less of the day, in the row of pills every list of
  // the app carries under its head — the same three the availabilities carry.
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
          prefix: 'Fascia',
          hint: 'Tutte le fasce',
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
        // Nobody on the day asked for anything the anagrafica knows about: a
        // pill that could only open onto an empty window is left out.
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
    // A day the association does not open in either way: nobody can be there,
    // so there is nothing here to search through or add to. What was stored
    // before it closed is shown whole — the field and the pills that could
    // explain a shorter list are not on this screen.
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
      // The count that used to sit under the search is gone: the day's header
      // above already counts the day's presences, and a search finding nothing
      // says so on its own further down.
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
          ? Center(
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

// The questions in the order they are asked: who and when, then which way of
// being there, then one mode at a time to the end — its hours and what to do
// inside them. One mode at a time keeps together the questions speaking of the
// same thing.
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
    'Gli orari in cui lo studente sarà presente in Associazione.',
  ),
  presenceSubjects(
    'Che lezioni vuole fare in Associazione?',
    'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi disciplina offerta dall\'Associazione, oppure un servizio.',
  ),
  onlineHours(
    'Quando può essere presente online?',
    'Gli orari in cui lo studente è disponibile per essere seguito a distanza.',
  ),
  onlineSubjects(
    'Che lezioni vuole fare online?',
    'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi disciplina offerta dall\'Associazione, oppure un servizio.',
  );

  final String question;
  final String hint;

  // How wide this question's card is comfortable. Two chips do not need a
  // thousand pixels, and neither does a name: one width for every card left half
  // the dialog empty on the short questions.
  final double width;

  const _WizardCard(this.question, this.hint, {this.width = _wizardMaxWidth});
}

class _PresenceWizardDialog extends StatefulWidget
{
  // The pupil's day being edited, or null when a new one is being made. Every
  // presence of that pupil on that day is opened with it, both ways of being
  // there: they are one answer to one day.
  final PresenceItem? existingPresence;

  final List<PresenceItem> presences;
  final List<PersonItem> students;

  // Who could teach what is asked for: a pupil may name up to three of them per
  // subject, as a preference.
  final List<PersonItem> teachers;

  final List<MinistrySubjectItem> ministrySubjects;
  final List<AssociationSubjectItem> associationSubjects;
  final List<ServiceItem> services;
  final List<StudyProgramItem> studyPrograms;
  final List<DateTime> availableDays;
  final DateTime defaultDate;

  // When the association is open. Nobody can be here, or be taught at a screen,
  // outside it.
  final List<OpeningDayItem> openingDays;

  final VoidCallback? onCancelEdit;
  // Creating a whole day in a single transaction: the bands and the lessons of
  // every requested mode. Editing goes through the per-row endpoints instead,
  // which touch one row at a time.
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

  // Several at once: the same day given twice a week used to be two trips
  // through this window.
  Set<DateTime> _days = {};

  // The hours, one schedule per way of being there. In the building they are
  // when the pupil is here; online they are when the pupil can be taught.
  final Map<String, BandSchedule<PresenceItem>> _hours = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: BandSchedule<PresenceItem>(),
  };

  // And what is asked for in each of them. A booking belongs to a way of being
  // there, not to one stretch of it: an hour of Latin is an hour of the
  // afternoon the pupil spends here, wherever in it the timetable puts it.
  final Map<String, List<SubjectRequestDraft>> _requests = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: <SubjectRequestDraft>[],
  };

  // One of the two, or both. Asked first because it decides what comes after,
  // and skipped where the association opens in one mode only.
  final Set<String> _selectedModes = {};

  // Which of the three categories is being looked at, per mode: whoever is
  // picking the online hours must not land where the other mode was left.
  final Map<String, int> _subjectCategory = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: 0,
  };

  // The discipline catalogue is as long as everything the association teaches:
  // without a field to search them one scrolls until they turn up. The
  // programme's subjects are few and the services fewer, and need none; the
  // parts of a single subject, two or three of them, need none either.
  final Map<String, TextEditingController> _disciplineSearchControllers = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: TextEditingController(),
  };

  final Map<String, String> _disciplineQuery = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: '',
  };

  // One per mode, so the bar knows where to resume from on returning to the
  // card, and the two do not swap positions.
  final Map<String, ScrollController> _subjectScrollControllers = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: ScrollController(),
  };

  final List<(String, BookingSummaryItem)> _droppedBookings = [];

  // Which card is on screen. What the cards are depends on what has been
  // answered so far, so it is worked out rather than fixed.
  int _cardIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  // What has already been written, so that a save stopped halfway by one
  // refusal does not send it again when it is tried a second time.
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

  // Only what the pupil's own study programme teaches: a booking for a subject
  // nobody teaches them is a booking nobody can honour.
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

  // What the association has open in that band, on every one of the chosen
  // days. Null where it is shut on any of them: hours given over three days can
  // only be hours all three have.
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

  // The day the page is on, where the association opens on it; otherwise the
  // next one that does. Starting on a day whose every band is shut would open
  // the window on a question that cannot be answered.
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

    for (final controller in _disciplineSearchControllers.values)
    {
      controller.dispose();
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

    // The whole of that pupil's day, both ways of being there: the card this
    // was opened from is one stretch of it, and editing one stretch while the
    // others stay hidden is how a day ends up contradicting itself.
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

      // The modes already used are the ones the day has: opened for editing,
      // the "how do they want to attend" question answers itself with what was
      // already chosen, instead of starting empty.
      _selectedModes.add(presence.mode);

      // The whole row and not the four fields this window shows: a save here
      // rewrites every booking of the day, and one read back half would return
      // with its kind, tags, topic and named teachers emptied.
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
    // Going back is always allowed: what has already been answered needs no
    // defending.
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

  // Why this card does not let one move on, where it does not. It returns the
  // reason instead of shouting it: the arrow goes dark and says so on hover, so
  // whoever is answering knows before pressing and not after.
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
          return 'Indica almeno una fascia oraria '
              '${modeLabel(mode).toLowerCase()} per andare avanti.';
        }

      // In the building the subjects are optional: one can book simply to be
      // there, among the others. Online they are not — a call with nothing to do
      // inside it is not a request.
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

  // An hour covering three disciplines is an hour of each and not twenty
  // minutes apiece. [skip] leaves out the request being rewritten, which counts
  // its own duration itself.
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

      for (final mode in _modes)
      {
        _hours[mode]!.clear();
        _requests[mode]!.clear();
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

    // Online with nothing to do is not a request: a call is booked for a
    // lesson, not to be present.
    if (_effectiveModes.contains(kOnlineMode) &&
        _hours[kOnlineMode]!.isNotEmpty &&
        _requests[kOnlineMode]!.isEmpty)
    {
      refuse('Scegli almeno una materia online.');

      return false;
    }

    if (_modes.every((mode) => _hours[mode]!.isEmpty))
    {
      refuse('Indica almeno una fascia oraria, in presenza od online.');

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
        refuse('Hai chiesto delle materie $label senza indicare le fasce orarie.');

        return false;
      }

      for (final request in requests)
      {
        if (!request.isComplete)
        {
          refuse('Indica la durata di ${request.displayName} ($label).');

          return false;
        }

        // A service is not a lesson about anything and carries no kind; every
        // other hour says what it is for, because that is what the teacher
        // prepares against.
        if (request.asksForTopicAndTag && request.tags.isEmpty)
        {
          refuse('Indica il tipo di lezione di ${request.displayName} ($label).');

          return false;
        }
      }

      // Two hours a day on one discipline is the whole of it. Counted per mode,
      // like the pupil's time: the same discipline asked online is asked of a
      // different day.
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

    // Hours that read as one are written as one, on both paths out of here. On
    // save and not while dragging: a row vanishing under the finger the moment
    // it touches its neighbour is a jump, whereas here it is what was asked
    // for.
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

    // A new day is written in one go, for each requested date: bands and
    // lessons of every mode inside one transaction, so a refusal leaves no
    // half-written day. Editing is different: there, rows that already exist are
    // touched one at a time.
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

    // What was taken off the day goes first: bookings before the hours they
    // hang from, so nothing is left pointing at a stretch that has gone.
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
        // The hours first: a booking needs a presence to hang from, and on a
        // new day there is not one yet.
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

        // Every subject asked for in this mode hangs from the first stretch of
        // it. What the day is made of belongs to the mode as a whole — that is
        // what the pupil was asked — and the timetable decides later which of
        // the stretches each hour lands in.
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

  // What happens on success, on both paths.
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

  // The blocks the backend expects: one mode per block, with its bands and its
  // lessons. Modes without bands stay out — there is nothing to book in a time
  // nobody gave.
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

  // Where a stored booking hangs from, so it can be taken away: the stretch it
  // was read off.
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
    // Only those still collaborating: a day still to come is being booked, and
    // whoever has stopped will not spend it here. The whole list stays good for
    // reading bookings already written, which still carry their name.
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
          // No magnifier: the label and the placeholder already say a name is
          // being searched for, and the glyph only repeated them.
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

  // How wide the first card sits when it no longer asks anything. When editing
  // it carries two short facts instead of the pupil to search for and the days
  // to tick, and at the width those two are asked at they would sit in the
  // middle of half an empty dialog.
  static const double _fixedFactsWidth = 560;

  // In an edit the pupil and the day are not questions: they are what the day
  // is, and moving either would make it a different one.
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

  // The hours of one way of being there. What they are spent on is asked
  // further along: the subjects of a day are one question, not two, and asking
  // them here would mean asking it twice.
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
            // Half an hour is the shortest stretch that can be given, as it is
            // server-side: below that, it is a pupil arriving and leaving.
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



  // The catalogue of the pupil's own programme, ticked one subject at a time.
  // Which parts is asked the moment the subject is ticked, in a window of its
  // own: asked on a later card it made you walk the list again without the
  // thought that had picked them.
  //
  // The disciplines offered on their own leave out what the pupil already finds
  // under their ministry subjects, or the same one could be asked for twice by
  // two routes.
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

    final category = _subjectCategory[mode] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The three categories one at a time: strung together they would be a
        // page-long list, and what one is looking for almost always sits in a
        // single one.
        AppSegmentedTabs(
          labels: const ['Materie', 'Discipline', 'Servizi'],
          selectedIndex: category,
          onSelected: (index) => setState(() => _subjectCategory[mode] = index),
        ),
        // The list scrolls inside the card instead of stretching it: a
        // catalogue of fifty entries made a page-tall card, and reaching the
        // forward arrow meant walking through all of it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _subjectListMaxHeight),
          child: Scrollbar(
            controller: _subjectScrollControllers[mode],
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _subjectScrollControllers[mode],
              // The scrollbar runs outside the rows, not over the last word.
              padding: const EdgeInsets.only(right: 12),
              child: switch (category)
              {
                0 => _buildMinistryList(mode),
                1 => _buildDisciplineList(mode),
                _ => _buildServiceList(mode),
              },
            ),
          ),
        ),
      ],
    );
  }

  // Under an entry already chosen: the disciplines where there were some to
  // choose from, and the duration. Measured on how many the subject has and not
  // on how many were taken — one out of three is still an answer.
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

  // The line under a discipline's or a service's name: what has been asked of
  // it where something has, and what the entry is. Separated the way the rest of
  // the app separates two things on one line.
  String _sayBoth(String? asked, String? description)
  {
    return [
      if (asked != null && asked.isNotEmpty) asked,
      ?descriptionOrNull(description),
    ].join(' · ');
  }

  // A discipline by name, wherever this window can find it: in the catalogue
  // under the ministry subjects, or on a request that asked for it on its own
  // and carries its name with it.
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

  // Whether this request's subject holds more than one discipline.
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

  // The request already made for this entry, where there is one.
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

  Widget _buildMinistryList(String mode)
  {
    if (_filteredMinistrySubjects.isEmpty)
    {
      return _buildEmptyCategory(
        'Il percorso di studi dello studente non ha materie collegate.',
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final subject in _filteredMinistrySubjects)
          () {
            final chosen = _requestFor(mode, subject.id);

            return SubjectPickRow(
            name: subject.name,
            subtitle: chosen == null ? '' : _summaryOf(chosen),
            selected: chosen != null,
            // The icon shows on what has already been chosen, and is the way
            // back in to change it.
            hasChoice: chosen != null,
            onSelected: (selected) => selected
                ? _openRequestWizard(
                    mode,
                    SubjectRequestDraft(
                      kind: BookingRequestKind.ministrySubject,
                      ministrySubjectId: subject.id,
                      // A single discipline is not a choice: it is taken as
                      // made, and the carousel does not ask for it.
                      associationSubjectIds: {
                        if (subject.associationSubjects.length == 1)
                          subject.associationSubjects.single.id,
                      },
                    )..ministrySubjectName = subject.name,
                  )
                : _dropSubject(mode, subject.id),
            onEditDisciplines: () => chosen == null
                ? null
                : _openRequestWizard(mode, chosen, editing: true),
          );
          }(),
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

    final query = _disciplineQuery[mode]!.toLowerCase();
    final disciplines = all
        .where((discipline) => discipline.name.toLowerCase().contains(query))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppSearchField(
            controller: _disciplineSearchControllers[mode]!,
            hintText: 'Cerca disciplina...',
            onChanged: (value) => setState(() => _disciplineQuery[mode] = value),
          ),
        ),
        if (disciplines.isEmpty)
          _buildEmptyCategory('Nessuna disciplina trovata per questa ricerca.'),
        for (final discipline in disciplines)
          () {
            final chosen = _chosen(
              mode,
              (request) => request.associationSubjectId == discipline.id,
            );

            return SubjectPickRow(
            name: discipline.name,
            // What the discipline is, with what has already been asked of it in
            // front: once picked, the answer takes pride of place, but what the
            // discipline is stays readable — it is the reason it was being
            // picked.
            subtitle: _sayBoth(
              chosen == null ? null : _summaryOf(chosen),
              discipline.description,
            ),
            selected: chosen != null,
            hasChoice: chosen != null,
            onSelected: (selected) => selected
                ? _openRequestWizard(
                    mode,
                    SubjectRequestDraft(
                      kind: BookingRequestKind.associationSubject,
                      associationSubjectId: discipline.id,
                      associationSubjectName: discipline.name,
                    ),
                  )
                : _dropWhere(
                    mode,
                    (request) => request.associationSubjectId == discipline.id,
                  ),
            onEditDisciplines: () => chosen == null
                ? null
                : _openRequestWizard(mode, chosen, editing: true),
          );
          }(),
      ],
    );
  }

  Widget _buildServiceList(String mode)
  {
    if (widget.services.isEmpty)
    {
      return _buildEmptyCategory('Nessun servizio disponibile.');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final service in widget.services)
          () {
            final chosen =
                _chosen(mode, (request) => request.serviceName == service.name);

            return SubjectPickRow(
            name: service.name,
            subtitle: _sayBoth(
              chosen == null ? null : _summaryOf(chosen),
              service.description,
            ),
            selected: chosen != null,
            hasChoice: chosen != null,
            onSelected: (selected) => selected
                ? _openRequestWizard(
                    mode,
                    SubjectRequestDraft(
                      kind: BookingRequestKind.service,
                      serviceName: service.name,
                    ),
                  )
                : _dropWhere(mode, (request) => request.serviceName == service.name),
            onEditDisciplines: () => chosen == null
                ? null
                : _openRequestWizard(mode, chosen, editing: true),
          );
          }(),
      ],
    );
  }


  // The remaining questions are all asked in here, and only those that make
  // sense for the chosen kind.
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
        // What the others have already taken: the one being written counts its
        // own duration itself, and counting it twice would call it over budget
        // as soon as it was picked.
        minutesTakenByOthers: _minutesAsked(mode) -
            (editing ? (draft.duration ?? 0) : 0),
        // And the same reckoning per discipline, for the ceiling each of them
        // has on its own.
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

  // A way of being there whose hours have gone has nothing left to spend, so
  // what was asked for out of them goes too.
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

  // One controller per subject, kept for as long as the window is open: built
  // in the builder they would be new on every keystroke, and the cursor would
  // jump back to the start of the line.
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

  // The modes the association opens in on every chosen day. The intersection
  // across days: a mode present on only one cannot be promised for the day
  // being booked.
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

  // Which modes are in play: the chosen ones, or the only possible one. Where
  // the association opens in one mode only nothing is asked and that one is
  // used: a question with a single answer is not a question.
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
      // Each mode brings its own two questions along, and brings nothing when
      // it was not chosen.
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

  // Two chips, and both can be pressed: someone who comes in the afternoon and
  // connects again in the evening is asking for one day, not two.
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

  // Removing a mode takes away what was said inside it: the hours and subjects
  // of a mode no longer wanted are answers to a question no longer asked.
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

  // The width belongs to the question, except where the question is gone: the
  // first card when editing is not the one seen when creating.
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

    // A card can go out from under you — the last subject dropped takes the
    // three that ask about it — and the carousel must not be left standing
    // where there is nothing.
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
        // Who and when is the first card and not a piece standing over the
        // others: it is answered once and never looked at again, and left up
        // there it took a third of the window all the way through.
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
