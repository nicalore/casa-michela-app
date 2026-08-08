import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../core/utils/time_bucket.dart';
import '../../association/models/opening_day_item.dart';
import '../../people/models/person_item.dart';
import '../models/availability_group.dart';
import '../models/availability_item.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';
import '../widgets/availability_card.dart';
import '../widgets/band_schedule.dart';
import '../widgets/lesson_day_field.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/person_avatar.dart';
import '../widgets/lessons_form_fields.dart';
import '../widgets/lessons_toolbar.dart';

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// One column of fields: the width of the settings dialogs, not of the ones
// that hold a list to pick from. The stack around it leaves room for the arrows
// that carry you between the two modes.
const double _wizardMaxWidth = 560;
const double _stackMaxWidth =
    _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

class AvailabilityTab extends StatefulWidget
{
  final List<AvailabilityItem> availabilities;
  final List<PersonItem> teachers;

  // The open days of the booking window, and the one the rail is on. The day is
  // chosen out in the rail now, as a section of the page: the tab is told which
  // one it is showing rather than asking for it itself.
  final List<DateTime> availableDays;
  final DateTime selectedDay;

  // When the association is open, over those same days: a teacher can only be
  // available inside it.
  final List<OpeningDayItem> openingDays;

  // The switch stands in this tab's own toolbar, but what it chooses is which
  // tab you are in — so it is the page that holds the answer, the page that
  // hears the click, and the page that says here which side it landed on. Named
  // by this tab instead, the switch would be a different one on each of the two
  // and its pill would never have anywhere to slide from.
  final LessonsDayView view;
  final ValueChanged<LessonsDayView> onViewSelected;

  final Future<bool> Function(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreate;
  final Future<bool> Function(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEdit;

  // One stretch dropped from a day that keeps the others, and a whole day's
  // availability thrown away. The first is a step inside a save and says
  // nothing; the second is what the card's ELIMINA does.
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

  // What the day is being looked at through. All three narrow the list of
  // cards; none of them narrows a card, because a card is one teacher's day and
  // showing half of it would be a different day from the one they gave.
  String? _filterMode;
  TimeBucket? _filterBucket;

  // Several at a time, and a teacher passes on any of them: a filter set to
  // Matematica and Fisica asks who teaches either, which is the question one
  // has when looking for cover.
  Set<String> _filterSubjects = {};

  bool get _hasFilters => _filterMode != null || _filterBucket != null || _filterSubjects.isNotEmpty;

  // Everything given on the day the rail is on, gathered by teacher: a teacher
  // there in the morning and again after lunch is one availability with two
  // stretches of hours in it.
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

  // The same, through the search field and the three pills.
  List<AvailabilityGroup> get _filteredGroups
  {
    final query = _searchText.toLowerCase();

    return _dayGroups
        .where((group) =>
            group.teacher.fullName.toLowerCase().contains(query) && _matchesFilters(group))
        .toList();
  }

  // The disciplines a teacher is down for, off the anagrafica: an availability
  // carries a name and a tax code and nothing else, which is enough to find
  // them by.
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

  // Only the disciplines of the teachers standing on this day. A menu offering
  // every discipline the association teaches would be mostly answers that empty
  // the page.
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

  // The mode and the band are asked of one stretch: "online di mattina" means
  // one stretch that is both, not one online and another in the morning. The
  // discipline is asked of the teacher, which is where it is kept.
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

    // The rail moves to another day and the disciplines standing on it are not
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
      return 'Nessuna disponibilità corrisponde ai filtri scelti.';
    }

    if (_searchText.isNotEmpty)
    {
      return 'Nessun docente trovato in questa giornata.';
    }

    return 'Nessuna disponibilità in questa giornata.';
  }

  // Three ways of asking for less of the day, in the row of pills every list of
  // the app carries under its head. All three are filters and none is a
  // setting: the day starts whole, and each one is the reason it is not.
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
        // More answers than a menu can hold, and worth giving several of at
        // once, so it asks in a window of its own and comes back with a count —
        // the discipline filter of the study programmes, which is the same
        // question asked of a different list.
        //
        // Nobody on the day teaches anything the anagrafica knows about: a pill
        // that could only open onto an empty window is left out.
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
      builder: (context) => _AvailabilityWizardDialog(
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
    // A day the association does not open in either way: no band could be
    // given, so there is nothing here to search through or add to. What was
    // stored before it closed is shown whole — the field and the pills that
    // could explain a shorter list are not on this screen.
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

class _AvailabilityWizardDialog extends StatefulWidget
{
  // The day's availability being edited, or null when a new one is being made.
  final AvailabilityGroup? existingGroup;

  final List<PersonItem> teachers;
  final List<DateTime> availableDays;
  final DateTime defaultDate;

  // Every availability already stored, all days included: a teacher has one per
  // day and mode, so this is what says which days are still free.
  final List<AvailabilityItem> availabilities;

  // When the association is open. Nothing can be offered outside it.
  final List<OpeningDayItem> openingDays;

  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreate;
  final Future<bool> Function(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEdit;
  final Future<bool> Function(AvailabilityItem item, Function(String) onError) onDeleteSlot;

  const _AvailabilityWizardDialog({
    this.existingGroup,
    required this.teachers,
    required this.availableDays,
    required this.defaultDate,
    required this.availabilities,
    required this.openingDays,
    this.onCancelEdit,
    required this.onCreate,
    required this.onEdit,
    required this.onDeleteSlot,
  });

  @override
  State<_AvailabilityWizardDialog> createState() => _AvailabilityWizardDialogState();
}

class _AvailabilityWizardDialogState extends State<_AvailabilityWizardDialog>
{
  String? _selectedTeacherTaxCode;

  // Several at once, and one availability on each: the same hours on Monday and
  // on Wednesday used to be two trips through this window.
  Set<DateTime> _days = {};

  // Two days' worth of answers: the three bands in the building and the three
  // at a screen. Each band holds as many stretches of hours as the teacher is
  // there for — an afternoon can be two and eleven, or two and eleven and four
  // — and an empty band is one they are not there for at all.
  final Map<String, BandSchedule<AvailabilityItem>> _bands = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: BandSchedule<AvailabilityItem>(),
  };

  bool _isSaving = false;

  // Which card is on screen — who and when, then the building, then the screen
  // — and which way it was reached. Both modes are answered in one pass of this
  // window; only one is looked at, at a time.
  int _cardIndex = 0;
  bool _movingForward = true;

  // What has already been written, so that a save stopped halfway by one
  // refusal does not send it again when it is tried a second time.
  final Set<Object> _saved = {};

  bool get _isEditing => widget.existingGroup != null;

  // Both ways, always: a card is a teacher on a day, and being in the building
  // in the morning and online in the evening is one answer to one question. An
  // edit can therefore add the way that was not given, or take away the one
  // that was.
  static const List<String> _modes = [kPresenceMode, kOnlineMode];

  PersonItem? get _selectedTeacher
  {
    final taxCode = _selectedTeacherTaxCode;

    if (taxCode == null)
    {
      return null;
    }

    for (final teacher in widget.teachers)
    {
      if (teacher.fiscalCode == taxCode)
      {
        return teacher;
      }
    }

    return null;
  }

  // The days in the order the rail shows them.
  List<DateTime> get _sortedDays
  {
    final days = _days.toList()..sort();

    return days;
  }

  // What the association has open in that band, on every one of the chosen
  // days. Null where it is shut on any of them: hours offered on three days can
  // only be hours all three have.
  OpeningWindow? _windowFor(String mode, TimeBucket bucket)
  {
    if (_days.isEmpty)
    {
      return null;
    }

    return sharedOpeningWindow(widget.openingDays, _sortedDays, mode, bucket);
  }

  // The modes the association actually opens in on that day. A mode it never
  // opens in is not a mode a teacher can be available in.
  List<String> _openModesOn(DateTime day)
  {
    return _modes.where((mode) => isOpenOn(widget.openingDays, day, mode)).toList();
  }

  // Whether the teacher already stands on that day in that mode. The day being
  // edited is not counted against itself.
  bool _isTakenBy(String teacherTaxCode, DateTime day, String mode)
  {
    // The day being edited is not held against itself: it is this card.
    if (_isEditing && isSameDate(day, widget.existingGroup!.date))
    {
      return false;
    }

    return hasAvailabilityOn(widget.availabilities, teacherTaxCode, day, mode);
  }

  // What is still worth opening the window for on that day: a mode the
  // association opens in and the teacher has not already answered.
  List<String> _freeModesOn(DateTime day)
  {
    final taxCode = _selectedTeacherTaxCode;
    final open = _openModesOn(day);

    if (taxCode == null)
    {
      return open;
    }

    return open.where((mode) => !_isTakenBy(taxCode, day, mode)).toList();
  }

  bool _isDayOffered(DateTime day) => _freeModesOn(day).isNotEmpty;

  String _dayTooltip(DateTime day)
  {
    if (_openModesOn(day).isEmpty)
    {
      return "L'associazione è chiusa ${formatAvailableDayLabel(day).toLowerCase()}.";
    }

    final teacher = _selectedTeacher;
    final name = teacher == null ? 'Il docente' : '${teacher.firstName} ${teacher.lastName}';

    return '$name ha già una disponibilità ${formatAvailableDayLabel(day).toLowerCase()}: '
        'aprila per cambiarne le fasce.';
  }

  @override
  void initState()
  {
    super.initState();

    final group = widget.existingGroup;

    if (group != null)
    {
      _selectedTeacherTaxCode = group.teacherTaxCode;
      _days = {group.date};

      for (final slot in group.slots)
      {
        final bucket = bucketFor(slot.startTime);

        if (bucket != null)
        {
          _bands[slot.mode]!.addStored(
            bucket,
            BandStretch<AvailabilityItem>(
              startTime: slot.startTime,
              endTime: slot.endTime,
              existing: slot,
            ),
          );
        }
      }

      // Hours given while the association opened at nine, read back on a day it
      // now opens at ten: what is shown, and what a save would write, is what
      // the opening can still hold.
      _reconcileBands();
    }
    else
    {
      _days = {_firstOfferedDay()};
    }
  }

  // The day the page is on, where the association opens on it; otherwise the
  // next one that does, and failing that the first there is. Starting on a day
  // whose every band is shut would open the window on a question that cannot be
  // answered.
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

  void _reconcileBands()
  {
    for (final mode in _modes)
    {
      _bands[mode]!.reconcile((bucket) => _windowFor(mode, bucket));
    }
  }

  void _selectDays(Set<DateTime> days)
  {
    setState(()
    {
      _days = days;
      _reconcileBands();
    });
  }

  void _selectTeacher(String? taxCode)
  {
    setState(()
    {
      _selectedTeacherTaxCode = taxCode;

      // A day this teacher has already answered is no longer a day to answer,
      // so it goes out. What is left may well be nothing, and nothing is left
      // as it is: putting a day back on their behalf would undo, at the moment
      // a name is chosen, the choice of days just made by hand.
      _days = _days.where(_isDayOffered).toSet();

      _reconcileBands();
    });
  }

  void _resetForm()
  {
    setState(()
    {
      _selectedTeacherTaxCode = null;
      _days = {widget.defaultDate};

      for (final schedule in _bands.values)
      {
        schedule.clear();
      }

      _saved.clear();
      _cardIndex = 0;
      _movingForward = false;
    });
  }

  // Why one does not move past the first card, where one does not. The hours
  // that follow are somebody's hours: without knowing whose, they are an answer
  // without a question.
  String? get _blockedReason
  {
    if (_cardIndex == 0 && _selectedTeacherTaxCode == null)
    {
      return 'Scegli il docente per andare avanti.';
    }

    // The days can all be put out — the chips no longer keep one lit on their
    // own — and with none there is no opening to measure the bands against: the
    // cards ahead would offer six bands all shut. So the card holds here, the
    // way the one asking for a pupil's day does.
    if (_cardIndex == 0 && !_isEditing && _days.isEmpty)
    {
      return 'Scegli almeno una giornata per andare avanti.';
    }

    return null;
  }

  void _goToCard(int index)
  {
    // Going back is always allowed: what has already been answered needs no
    // defending.
    if (index > _cardIndex && _blockedReason != null)
    {
      return;
    }

    setState(()
    {
      _movingForward = index > _cardIndex;
      _cardIndex = index;
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

  bool get _hasAnyBand => _modes.any((mode) => _bands[mode]!.isNotEmpty);

  Future<void> _save() async
  {
    if (_isSaving)
    {
      return;
    }

    final teacherTaxCode = _selectedTeacherTaxCode;

    if (teacherTaxCode == null)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona un docente.', isError: true);
      return;
    }

    if (_days.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una giornata.', isError: true);
      return;
    }

    // Also where every band has just been switched off: an availability with no
    // hours on it is not an availability, and emptying one is not how it is
    // thrown away — the card it was opened from has a button that says so.
    if (!_hasAnyBand)
    {
      CustomSnackBar.show(
        context: context,
        message: _isEditing
            ? 'Indica almeno una fascia di disponibilità, oppure elimina la disponibilità dalla sua scheda.'
            : 'Indica almeno una fascia di disponibilità.',
        isError: true,
      );

      return;
    }

    // A teacher answers a day and a mode once. The chips already leave out the
    // days where every mode is spoken for, but one of two can still be, and a
    // second answer to it would be a second availability for the same thing.
    for (final day in _sortedDays)
    {
      for (final mode in _modes)
      {
        final givesBands = _bands[mode]!.isNotEmpty;

        if (givesBands && _isTakenBy(teacherTaxCode, day, mode))
        {
          CustomSnackBar.show(
            context: context,
            message: 'Il docente ha già una disponibilità ${modeLabel(mode).toLowerCase()} '
                '${formatAvailableDayLabel(day).toLowerCase()}: aprila per cambiarne le fasce.',
            isError: true,
          );

          return;
        }
      }
    }

    // Hours that read as one are written as one. Here and not before: while
    // dragging, a row vanishing under the finger the moment it touches its
    // neighbour is a jump, whereas on save it is simply what was asked for.
    setState(()
    {
      _isSaving = true;

      for (final schedule in _bands.values)
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

    // What was taken off the day goes first: the room it leaves is what the
    // bands below may be moving into.
    for (final item in _modes.expand((mode) => _bands[mode]!.dropped))
    {
      if (_saved.contains(item))
      {
        continue;
      }

      if (!await widget.onDeleteSlot(item, showError))
      {
        if (!mounted)
        {
          return;
        }

        setState(() => _isSaving = false);
        return;
      }

      if (!mounted)
      {
        return;
      }

      _saved.add(item);
    }

    for (final day in _sortedDays)
    {
      for (final mode in _modes)
      {
        {
          for (final draft in _bands[mode]!.all)
          {
            // The stretch itself, not where it stands in the band: an afternoon
            // can be two of them, and a save stopped halfway through must know
            // which of the two it had already written — even if the one that
            // failed is taken away before it is tried again.
            final key = (day, mode, draft);

            if (_saved.contains(key))
            {
              continue;
            }

            final existing = draft.existing;
            final isMove = existing != null && isSameDate(day, existing.date);

            final success = isMove
                ? await widget.onEdit(existing, teacherTaxCode, day, mode, draft.startTime, draft.endTime, showError)
                : await widget.onCreate(teacherTaxCode, day, mode, draft.startTime, draft.endTime, showError);

            if (!mounted)
            {
              return;
            }

            if (!success)
            {
              setState(() => _isSaving = false);
              return;
            }

            _saved.add(key);
          }
        }
      }
    }

    setState(() => _isSaving = false);

    // Once, now that it is done: the writing happens a stretch at a time, and
    // saying so at every stretch was the same banner flashing six times.
    CustomSnackBar.show(
      context: context,
      message: _isEditing
          ? 'Disponibilità modificata con successo!'
          : (_days.length == 1
              ? 'Disponibilità creata con successo!'
              : '${_days.length} disponibilità create con successo!'),
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

  // In an edit the teacher and the day are not questions: they are what the
  // availability is, and moving either would make it a different one. They are
  // said here instead, over the bands that can still change — both ways of
  // being there among them.
  Widget _buildFixedFacts()
  {
    final group = widget.existingGroup!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: WizardFact(label: 'Docente', value: group.teacher.fullName)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: WizardFact(label: 'Giornata', value: formatAvailableDayLabel(group.date))),
      ],
    );
  }

  Widget _buildAsked()
  {
    // Only those still collaborating: an availability is a promise for a day
    // still to come, and whoever has stopped will not keep it. The whole list
    // stays good for reading availabilities already given, which still carry
    // their name.
    final teacherOptions = activeCollaborators(widget.teachers)
        .map((teacher) => SelectionOption<String>(
              value: teacher.fiscalCode,
              label: '${teacher.firstName} ${teacher.lastName}',
              leading: PersonAvatar(person: teacher, size: PersonAvatar.pickerSize),
              subtitle: teacher.taughtSubjects.isEmpty ? null : teacher.taughtSubjects.take(3).join(', '),
            ))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutocompleteField<String>(
          label: 'Docente',
          hint: 'Cerca docente...',
          // No magnifier: the label and the placeholder already say a name is
          // being searched for, and the glyph only repeated them.
          icon: null,
          options: teacherOptions,
          value: _selectedTeacherTaxCode,
          onSelected: _selectTeacher,
          onCleared: () => _selectTeacher(null),
        ),
        const SizedBox(height: 20),
        LessonDayField(
          days: widget.availableDays,
          values: _days,
          onChanged: _selectDays,
          summary: (count) => 'Le fasce scelte varranno su tutte e $count le giornate.',
          isEnabled: _isDayOffered,
          disabledTooltip: _dayTooltip,
        ),
      ],
    );
  }

  // One mode, with the three bands of the day under it. A band the association
  // is shut in cannot be answered, and says so where its hours would be.
  Widget _buildMode(String mode)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            modeLabel(mode).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.trialMutedText,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
        ),
        BandScheduleField<AvailabilityItem>(
          schedule: _bands[mode]!,
          windowFor: (bucket) => _windowFor(mode, bucket),
          offLabel: 'Non disponibile',
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Disponibilità',
      title: _isEditing ? 'Modifica disponibilità' : 'Nuova disponibilità',
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
        // Who and when stays put at the top: it is the same question whichever
        // mode you are looking at, and walking between the two cards below must
        // not carry it away. Held to the width of the card so the two line up,
        // with the arrows standing out beside the one that moves.
        // Who and when is the first card rather than a piece standing over all
        // the others: it is answered once and never looked at again, and left
        // up there it took a third of the window for the whole of the way
        // through. Then one card per mode — they were one long piece with six
        // bands on it, which read as one question with six answers rather than
        // as two questions with three.
        AppCarouselFrame(
          index: _cardIndex,
          movingForward: _movingForward,
          maxContentWidth: _wizardMaxWidth,
          canGoBack: _cardIndex > 0,
          canGoForward: _cardIndex < _modes.length,
          forwardBlockedReason: _blockedReason,
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(
            expand: true,
            child: _cardIndex == 0
                ? (_isEditing ? _buildFixedFacts() : _buildAsked())
                : _buildMode(_modes[_cardIndex - 1]),
          ),
        ),
      ],
    );
  }
}
