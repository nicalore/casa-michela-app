import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../../association/models/subject_taxonomy.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_item.dart';
import '../models/booking_summary_item.dart';
import '../models/presence_item.dart';
import '../models/subject_request.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';
import '../utils/study_program_lookup.dart';
import 'band_schedule.dart';
import 'booking_fields_section.dart' show maxDailyMinutesPerDiscipline;
import 'lesson_day_field.dart';
import 'lessons_form_fields.dart';
import 'person_avatar.dart';
import 'subject_pick_row.dart';
import 'subject_request_tile.dart' show disciplineNames, ministrySubjectName;
import 'subject_request_wizard.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _subjectListMaxHeight = 380;

const double _wizardMaxWidth = 820;
const double _stackMaxWidth =
    _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

const double _modesCardWidth = 460;
const double _fixedFactsWidth = 560;

const List<String> _modes = [kPresenceMode, kOnlineMode];

// Keyed by opening signature, so answers survive adding or removing days.
class _DayGroup
{
  final String key;
  final List<DateTime> days;

  const _DayGroup({required this.key, required this.days});
}

class _Answers
{
  final Map<String, BandSchedule<PresenceItem>> hours = {
    for (final mode in _modes) mode: BandSchedule<PresenceItem>(),
  };

  final Map<String, List<SubjectRequestDraft>> requests = {
    for (final mode in _modes) mode: <SubjectRequestDraft>[],
  };

  final Set<String> modes = {};
}

enum _Step { who, modes, hours, subjects }

typedef _Card = ({_Step step, _DayGroup? group, String? mode});

class PresenceWizardDialog extends StatefulWidget
{
  final PresenceItem? existingPresence;

  final List<PresenceItem> presences;
  final List<PersonItem> students;

  final bool isOwn;

  // The student is the current user; copy addresses them directly.
  final bool isSelf;

  final String? defaultStudentTaxCode;

  // onlyMode: no mode choice; the other mode's rows are neither shown nor written.
  final String? onlyMode;
  final bool openOnSubjects;
  final bool hoursOnly;

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

  const PresenceWizardDialog({
    super.key,
    this.existingPresence,
    required this.presences,
    required this.students,
    this.isOwn = false,
    this.isSelf = false,
    this.defaultStudentTaxCode,
    this.onlyMode,
    this.openOnSubjects = false,
    this.hoursOnly = false,
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
  State<PresenceWizardDialog> createState() => PresenceWizardDialogState();
}

class PresenceWizardDialogState extends State<PresenceWizardDialog>
{
  String? _selectedStudentTaxCode;

  Set<DateTime> _days = {};

  final Map<String, _Answers> _answersByGroup = {};

  static const List<String> _subjectCategoryLabels = ['Materie', 'Discipline', 'Servizi'];

  static const int _ministryCategory = 0;
  static const int _disciplineCategory = 1;
  static const int _serviceCategory = 2;

  // Per mode, not per group: search state carries over to the next group's card.
  final Map<String, int> _subjectCategory = {
    for (final mode in _modes) mode: _ministryCategory,
  };

  final Map<String, List<TextEditingController>> _subjectSearchControllers = {
    for (final mode in _modes)
      mode: List.generate(_subjectCategoryLabels.length, (_) => TextEditingController()),
  };

  final Map<String, List<String>> _subjectQueries = {
    for (final mode in _modes)
      mode: List.filled(_subjectCategoryLabels.length, ''),
  };

  final Map<String, ScrollController> _subjectScrollControllers = {
    for (final mode in _modes) mode: ScrollController(),
  };

  final List<(String, BookingSummaryItem)> _droppedBookings = [];

  // Rows and lessons in closed bands, which the server refuses to change: shown, never edited.
  final Map<String, Map<TimeBucket, List<BandStretch<PresenceItem>>>> _frozen = {
    for (final mode in _modes)
      mode: {for (final bucket in TimeBucket.values) bucket: <BandStretch<PresenceItem>>[]},
  };

  final Map<String, List<SubjectRequestDraft>> _frozenRequests = {
    for (final mode in _modes) mode: <SubjectRequestDraft>[],
  };

  // Read once: the dialog is short-lived, and the server enforces the rule.
  final DateTime _now = DateTime.now();

  int _cardIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  final Set<Object> _saved = {};

  final Map<Object, int> _createdIds = {};

  final Map<SubjectRequestDraft, TextEditingController> _topicControllers = {};
  final Map<SubjectRequestDraft, TextEditingController> _notesControllers = {};

  bool get _isEditing => widget.existingPresence != null;

  bool get _isOwn => widget.isOwn;

  bool get _isSelf => widget.isSelf;

  String? get _defaultStudentTaxCode
  {
    if (!_isOwn)
    {
      return null;
    }

    return widget.defaultStudentTaxCode ?? widget.students.single.fiscalCode;
  }

  bool _isClosed(DateTime day, TimeBucket bucket)
  {
    return _isOwn && haveBookingsClosed(day, bucket, _now);
  }

  bool _hasFrozen(String mode) => _frozen[mode]!.values.any((held) => held.isNotEmpty);

  bool get _hasAnyFrozen => _modes.any(_hasFrozen);

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

  String get _who => _selectedStudent?.firstName ?? 'lo studente';

  String get _whose
  {
    return switch (_selectedStudent)
    {
      final student? => 'di ${student.firstName}',
      null => 'dello studente',
    };
  }

  String _agreed(String masculine, String feminine)
  {
    return _selectedStudent?.gender == 'F' ? feminine : masculine;
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

  // Grouping key: open window per mode and band, '-' where shut or closed to own.
  String _signatureOf(DateTime day)
  {
    final parts = <String>[];

    for (final mode in _modes)
    {
      for (final bucket in TimeBucket.values)
      {
        final window = _isClosed(day, bucket) ? null : openingWindowFor(widget.openingDays, day, mode, bucket);

        parts.add(window == null ? '-' : '${window.startMinutes}-${window.endMinutes}');
      }
    }

    return parts.join('|');
  }

  List<_DayGroup> get _groups
  {
    final byKey = <String, List<DateTime>>{};

    for (final day in _sortedDays)
    {
      byKey.putIfAbsent(_signatureOf(day), () => []).add(day);
    }

    return [
      for (final entry in byKey.entries) _DayGroup(key: entry.key, days: entry.value),
    ];
  }

  // Editing is one day, so one group.
  _DayGroup get _editedGroup => _groups.single;

  _Answers _answersOf(_DayGroup group) => _answersByGroup.putIfAbsent(group.key, _Answers.new);

  Iterable<_Answers> get _allAnswers => _answersByGroup.values;

  // Alike by construction; the intersection is just the safe way to read it.
  OpeningWindow? _sharedWindow(_DayGroup group, String mode, TimeBucket bucket)
  {
    return sharedOpeningWindow(widget.openingDays, group.days, mode, bucket);
  }

  OpeningWindow? _openWindowFor(_DayGroup group, String mode, TimeBucket bucket)
  {
    if (group.days.any((day) => _isClosed(day, bucket)))
    {
      return null;
    }

    return _sharedWindow(group, mode, bucket);
  }

  OpeningWindow? _windowFor(_DayGroup group, String mode, TimeBucket bucket)
  {
    if (_takenElsewhere(group, mode).contains(bucket))
    {
      return null;
    }

    return _openWindowFor(group, mode, bucket);
  }

  static String _otherMode(String mode) => mode == kPresenceMode ? kOnlineMode : kPresenceMode;

  // Bands booked in the other mode; stored rows count only when not read into the answers.
  Set<TimeBucket> _takenElsewhere(_DayGroup group, String mode)
  {
    final String other = _otherMode(mode);
    final _Answers answers = _answersOf(group);

    final Set<TimeBucket> taken = {
      for (final bucket in TimeBucket.values)
        if (answers.hours[other]!.of(bucket).isNotEmpty || _frozen[other]![bucket]!.isNotEmpty) bucket,
    };

    final bool storedUnread = !_isEditing || widget.onlyMode != null;

    if (storedUnread)
    {
      for (final presence in widget.presences)
      {
        if (presence.mode != other ||
            presence.studentTaxCode != _selectedStudentTaxCode ||
            !group.days.any((day) => isSameDate(day, presence.date)))
        {
          continue;
        }

        final TimeBucket? bucket = bucketFor(presence.startTime);

        if (bucket != null)
        {
          taken.add(bucket);
        }
      }
    }

    return taken;
  }

  String _shutLabelFor(_DayGroup group, String mode, TimeBucket bucket)
  {
    if (_takenElsewhere(group, mode).contains(bucket))
    {
      return 'Già prenotata ${_otherMode(mode) == kOnlineMode ? kOnScreen : kInBuilding}';
    }

    return _sharedWindow(group, mode, bucket) == null ? 'Associazione chiusa' : 'Prenotazioni chiuse';
  }

  List<String> _openModesOn(DateTime day)
  {
    return _modes
        .where((mode) => TimeBucket.values.any((bucket) =>
            !_isClosed(day, bucket) &&
            openingWindowFor(widget.openingDays, day, mode, bucket) != null))
        .toList();
  }

  List<String> _openModesOf(_DayGroup group)
  {
    return _modes
        .where((mode) => TimeBucket.values.any((bucket) => _openWindowFor(group, mode, bucket) != null))
        .toList();
  }

  bool _asksForMode(_DayGroup group) => widget.onlyMode == null && _openModesOf(group).length > 1;

  Set<String> _effectiveModes(_DayGroup group)
  {
    final open = _openModesOf(group);

    if (widget.onlyMode case final String only)
    {
      return open.contains(only) ? {only} : const {};
    }

    if (open.length <= 1)
    {
      return open.toSet();
    }

    return _answersOf(group).modes.where(open.contains).toSet();
  }

  bool _isDayOffered(DateTime day) => _openModesOn(day).isNotEmpty;

  String _dayTooltip(DateTime day)
  {
    final when = formatAvailableDayLabel(day).toLowerCase();

    if (!_modes.any((mode) => isOpenOn(widget.openingDays, day, mode)))
    {
      return "L'Associazione è chiusa $when.";
    }

    return 'Le prenotazioni di $when sono chiuse.';
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
      _selectedStudentTaxCode = _defaultStudentTaxCode;
      _days = {_firstOfferedDay()};

      return;
    }

    _selectedStudentTaxCode = existing.studentTaxCode;
    _days = {existing.date};

    final _Answers answers = _answersOf(_editedGroup);

    for (final presence in widget.presences)
    {
      if (presence.studentTaxCode != existing.studentTaxCode ||
          !isSameDate(presence.date, existing.date) ||
          (widget.onlyMode != null && presence.mode != widget.onlyMode))
      {
        continue;
      }

      final bucket = bucketFor(presence.startTime);

      final frozen = bucket != null && _isClosed(existing.date, bucket);

      if (bucket != null)
      {
        final stretch = BandStretch<PresenceItem>(
          startTime: presence.startTime,
          endTime: presence.endTime,
          existing: presence,
        );

        if (frozen)
        {
          _frozen[presence.mode]![bucket]!.add(stretch);
        }
        else
        {
          answers.hours[presence.mode]!.addStored(bucket, stretch);
        }
      }

      answers.modes.add(presence.mode);

      final requests = frozen ? _frozenRequests[presence.mode]! : answers.requests[presence.mode]!;

      for (final booking in presence.bookings)
      {
        requests.add(SubjectRequestDraft.fromBooking(
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

    if (widget.openOnSubjects)
    {
      _cardIndex = _cards.indexWhere((card) => card.step == _Step.subjects);

      if (_cardIndex < 0)
      {
        _cardIndex = 0;
      }
    }
  }

  void _reconcileHours()
  {
    final groups = _groups;
    final keys = {for (final group in groups) group.key};

    _answersByGroup.removeWhere((key, _) => !keys.contains(key));

    for (final group in groups)
    {
      for (final mode in _modes)
      {
        _answersOf(group).hours[mode]!.reconcile((bucket) => _windowFor(group, mode, bucket));
      }
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

  String? _blockedReason(_Card card)
  {
    switch (card.step)
    {
      case _Step.who:
        if (_selectedStudentTaxCode == null)
        {
          return 'Scegli lo studente per andare avanti.';
        }

        if (_days.isEmpty)
        {
          return 'Scegli almeno un giorno per andare avanti.';
        }

      case _Step.modes:
        if (_effectiveModes(card.group!).isEmpty)
        {
          return 'Scegli almeno una modalità per andare avanti.';
        }

      case _Step.hours:
        if (_answersOf(card.group!).hours[card.mode]!.isEmpty)
        {
          return 'Indica almeno un orario '
              '${modeLabel(card.mode!).toLowerCase()} per andare avanti.';
        }

      case _Step.subjects:
        if (card.mode == kOnlineMode && _answersOf(card.group!).requests[kOnlineMode]!.isEmpty)
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

  int _minutesAsked(_DayGroup group, String mode)
  {
    var minutes = 0;

    for (final request in _answersOf(group).requests[mode]!)
    {
      minutes += request.duration ?? 0;
    }

    return minutes;
  }

  Map<int, int> _minutesByDiscipline(_DayGroup group, String mode, {SubjectRequestDraft? skip})
  {
    final minutes = <int, int>{};

    for (final request in _answersOf(group).requests[mode]!)
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
      _selectedStudentTaxCode = _defaultStudentTaxCode;
      _days = {_firstOfferedDay()};

      _answersByGroup.clear();

      for (final mode in _modes)
      {
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

  String _daysLabel(_DayGroup group)
  {
    if (_groups.length == 1)
    {
      return '';
    }

    return ' (${group.days.map(formatAvailableDayShortLabel).join(', ')})';
  }

  String? get _saveBlockedReason
  {
    if (_selectedStudentTaxCode == null)
    {
      return 'Seleziona uno studente.';
    }

    if (_days.isEmpty)
    {
      return 'Seleziona almeno una giornata.';
    }

    final groups = _groups;

    if (groups.every((group) => _modes.every((mode) => _answersOf(group).hours[mode]!.isEmpty)) &&
        !_hasAnyFrozen &&
        !_isClearing)
    {
      return 'Indica almeno un orario, in presenza od online.';
    }

    for (final group in groups)
    {
      final _Answers answers = _answersOf(group);
      final String days = _daysLabel(group);

      if (_effectiveModes(group).contains(kOnlineMode) &&
          answers.hours[kOnlineMode]!.isNotEmpty &&
          answers.requests[kOnlineMode]!.isEmpty)
      {
        return 'Scegli almeno una materia online$days.';
      }

      for (final mode in _modes)
      {
        final label = '${modeLabel(mode).toLowerCase()}$days';
        final requests = answers.requests[mode]!;

        if (requests.isEmpty)
        {
          continue;
        }

        if (answers.hours[mode]!.isEmpty)
        {
          return 'Hai chiesto delle materie $label senza indicare gli orari.';
        }

        for (final request in requests)
        {
          if (!request.isComplete)
          {
            return 'Indica la durata di ${request.displayName} ($label).';
          }

          if (request.asksForTopicAndTag && request.tags.isEmpty)
          {
            return 'Indica il tipo di lezione di ${request.displayName} ($label).';
          }
        }

        final byDiscipline = _minutesByDiscipline(group, mode);

        for (final entry in byDiscipline.entries)
        {
          if (entry.value > maxDailyMinutesPerDiscipline)
          {
            return '${_disciplineName(entry.key)} ($label): ${formatMinutes(entry.value)} in un '
                'giorno. Non si possono richiedere più di '
                '${formatMinutes(maxDailyMinutesPerDiscipline)} minuti al giorno per una disciplina.';
          }
        }

        final asked = _minutesAsked(group, mode);
        final given = answers.hours[mode]!.totalMinutes;

        if (asked > given)
        {
          return _isSelf
              ? 'Il totale delle ore di lezione richieste$days supera il tuo tempo di '
                  'permanenza in Associazione.'
              : 'Il totale delle ore di lezione richieste$days supera il tempo di permanenza '
                  '$_whose in Associazione.';
        }
      }
    }

    return null;
  }

  bool _validate()
  {
    final String? reason = _saveBlockedReason;

    if (reason != null)
    {
      CustomSnackBar.show(context: context, message: reason, isError: true);

      return false;
    }

    return true;
  }

  // Every open stretch dropped: saving deletes the day.
  bool get _isClearing
  {
    if (!_isEditing)
    {
      return false;
    }

    final _Answers answers = _answersOf(_editedGroup);

    return _modes.every((mode) => answers.hours[mode]!.isEmpty) &&
        _modes.any((mode) => answers.hours[mode]!.dropped.isNotEmpty);
  }

  bool get _isUntouched
  {
    if (!_isOwn || !_isEditing || !_hasAnyFrozen || _droppedBookings.isNotEmpty)
    {
      return false;
    }

    final _Answers answers = _answersOf(_editedGroup);

    return _modes.every((mode) => answers.hours[mode]!.isEmpty && answers.hours[mode]!.dropped.isEmpty);
  }

  Future<void> _save() async
  {
    if (_isSaving)
    {
      return;
    }

    if (_isUntouched)
    {
      _closeDialog();

      return;
    }

    if (!_validate())
    {
      return;
    }

    final studentTaxCode = _selectedStudentTaxCode!;

    setState(()
    {
      _isSaving = true;

      for (final answers in _allAnswers)
      {
        for (final schedule in answers.hours.values)
        {
          schedule.fuse();
        }
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
      for (final group in _groups)
      {
        for (final day in group.days)
        {
          if (_saved.contains(day))
          {
            continue;
          }

          final written = await widget.onCreateLessonRequest(
            studentTaxCode,
            day,
            _modePayloads(group),
            showError,
          );

          if (!written)
          {
            stop();

            return;
          }

          _saved.add(day);
        }
      }

      _finishSave();

      return;
    }

    final _DayGroup group = _editedGroup;
    final _Answers answers = _answersOf(group);

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
      for (final presence in answers.hours[mode]!.dropped)
      {
        if (!await once(presence, () => widget.onDeletePresenceQuietly(presence, showError)))
        {
          stop();

          return;
        }
      }
    }

    for (final day in group.days)
    {
      for (final mode in _modes)
      {
        int? firstPresenceId;

        for (final stretch in answers.hours[mode]!.all)
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

        for (final request in answers.requests[mode]!)
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

    // With one mode alone asked the day keeps the other's rows: modified.
    final bool cleared = _isClearing && widget.onlyMode == null;

    setState(() => _isSaving = false);

    final String what = _isOwn ? 'Prenotazione' : 'Richiesta';

    CustomSnackBar.show(
      context: context,
      message: _isEditing
          ? (cleared ? '$what eliminata con successo!' : '$what modificata con successo!')
          : (_days.length == 1
              ? '$what creata con successo!'
              : '${_days.length} ${_isOwn ? 'prenotazioni' : 'richieste'} create con successo!'),
      isError: false,
    );

    if (_isEditing || _isOwn)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
  }

  List<Map<String, dynamic>> _modePayloads(_DayGroup group)
  {
    final _Answers answers = _answersOf(group);
    final Set<String> chosen = _effectiveModes(group);

    return [
      for (final mode in _modes)
        if (chosen.contains(mode) && answers.hours[mode]!.all.isNotEmpty)
          {
            'mode': mode,
            'slots': [
              for (final stretch in answers.hours[mode]!.all)
                {
                  'start_time': formatTimeOfDay(stretch.startTime),
                  'end_time': formatTimeOfDay(stretch.endTime),
                },
            ],
            'subjects': [
              for (final request in answers.requests[mode]!) request.toJson(),
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

  Widget _buildDayField()
  {
    return LessonDayField(
      days: widget.availableDays,
      values: _days,
      onChanged: _selectDays,
      summary: (count) => _groups.length > 1
          ? 'Le giornate scelte hanno orari di apertura diversi: orari e materie verranno chiesti separatamente.'
          : 'La prenotazione verrà replicata su tutte le $count giornate selezionate.',
      isEnabled: _isDayOffered,
      disabledTooltip: _dayTooltip,
    );
  }

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
        _buildDayField(),
      ],
    );
  }

  Widget _buildOwnWho()
  {
    final PersonItem? student = _selectedStudent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.students.length > 1 && student != null) ...[
          WizardFact(label: 'Studente', value: '${student.firstName} ${student.lastName}'),
          const SizedBox(height: 20),
        ],
        _buildDayField(),
      ],
    );
  }

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

  Widget? _daysHeader(_Card card)
  {
    final _DayGroup? group = card.group;

    if (group == null || _groups.length == 1)
    {
      return null;
    }

    return AppDialogPill(
      expand: true,
      child: WizardFact(
        label: group.days.length == 1 ? 'Giornata' : 'Giornate',
        value: group.days.map(formatAvailableDayLabel).join(', '),
        maxLines: null,
      ),
    );
  }

  Widget _buildHours(_DayGroup group, String mode)
  {
    final open = TimeBucket.values.any((bucket) => _openWindowFor(group, mode, bucket) != null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!open)
          _buildHint("L'Associazione non apre ${modeLabel(mode).toLowerCase()} in questa giornata.")
        else ...[
          BandScheduleField<PresenceItem>(
            schedule: _answersOf(group).hours[mode]!,
            windowFor: (bucket) => _windowFor(group, mode, bucket),
            offLabel: 'Non presente',
            minimumMinutes: kMinimumBandMinutes,
            disabledLabelFor: (bucket) => _shutLabelFor(group, mode, bucket),
            frozen: _isEditing ? _frozen[mode]! : const {},
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

  Widget _buildSubjectsCard(_DayGroup group, String mode)
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
        if (_frozenRequests[mode]!.isNotEmpty) ...[
          _buildFrozenRequests(mode),
          const SizedBox(height: 20),
        ],
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
                _ministryCategory => _buildMinistryList(group, mode),
                _disciplineCategory => _buildDisciplineList(group, mode),
                _ => _buildServiceList(group, mode),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrozenRequests(String mode)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppFieldLabel('Lezioni già prenotate'),
        const SizedBox(height: 4),
        _buildHint('Le prenotazioni della loro fascia sono chiuse: non si possono più modificare.'),
        const SizedBox(height: 10),
        for (final request in _frozenRequests[mode]!)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.trialMutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [request.displayName, if (_summaryOf(request).isNotEmpty) _summaryOf(request)].join(' · '),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.trialInk,
                    ),
                  ),
                ),
              ],
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

    for (final answers in _allAnswers)
    {
      for (final requests in answers.requests.values)
      {
        for (final request in requests)
        {
          if (request.associationSubjectId == id &&
              request.associationSubjectName != null)
          {
            return request.associationSubjectName!;
          }
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

  SubjectRequestDraft? _chosen(_DayGroup group, String mode, bool Function(SubjectRequestDraft) matches)
  {
    for (final request in _answersOf(group).requests[mode]!)
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
    required _DayGroup group,
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
          ? _openRequestWizard(group, mode, onPick())
          : onDrop(),
      onEditDisciplines: () => chosen == null
          ? null
          : _openRequestWizard(group, mode, chosen, editing: true),
    );
  }

  Widget _buildMinistryList(_DayGroup group, String mode)
  {
    final all = _filteredMinistrySubjects;

    if (all.isEmpty)
    {
      return _buildEmptyCategory(
        _isSelf
            ? 'Il tuo percorso di studi non ha materie collegate.'
            : 'Il percorso di studi $_whose non ha materie collegate.',
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
            group: group,
            mode: mode,
            name: subject.name,
            chosen: _requestFor(group, mode, subject.id),
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.ministrySubject,
              ministrySubjectId: subject.id,
              associationSubjectIds: {
                if (subject.associationSubjects.length == 1)
                  subject.associationSubjects.single.id,
              },
            )..ministrySubjectName = subject.name,
            onDrop: () => _dropSubject(group, mode, subject.id),
          ),
      ],
    );
  }

  Widget _buildDisciplineList(_DayGroup group, String mode)
  {
    final all = _standaloneDisciplines;

    if (all.isEmpty)
    {
      return _buildEmptyCategory(
        _isSelf
            ? 'Tutte le discipline sono già sotto le tue materie.'
            : 'Tutte le discipline sono già sotto le materie $_whose.',
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
            group: group,
            mode: mode,
            name: discipline.name,
            description: discipline.description,
            chosen: _chosen(
              group,
              mode,
              (request) => request.associationSubjectId == discipline.id,
            ),
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.associationSubject,
              associationSubjectId: discipline.id,
              associationSubjectName: discipline.name,
            ),
            onDrop: () => _dropWhere(
              group,
              mode,
              (request) => request.associationSubjectId == discipline.id,
            ),
          ),
      ],
    );
  }

  Widget _buildServiceList(_DayGroup group, String mode)
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
            group: group,
            mode: mode,
            name: service.name,
            description: service.description,
            chosen: _chosen(
              group,
              mode,
              (request) => request.serviceName == service.name,
            ),
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.service,
              serviceName: service.name,
            ),
            onDrop: () => _dropWhere(
              group,
              mode,
              (request) => request.serviceName == service.name,
            ),
          ),
      ],
    );
  }

  Set<String> get _avoidedTeachers
  {
    final student = _selectedStudent;

    if (student != null)
    {
      return student.notPreferredTeacherTaxCodes.toSet();
    }

    return widget.existingPresence?.notPreferredTeacherTaxCodes.toSet() ?? const {};
  }

  void _openRequestWizard(
    _DayGroup group,
    String mode,
    SubjectRequestDraft draft, {
    bool editing = false,
  })
  {
    final avoided = _avoidedTeachers;
    final _Answers answers = _answersOf(group);

    // The picker hides avoided teachers, so drop them here or they could never be removed.
    draft.preferredTeacherTaxCodes.removeWhere(avoided.contains);

    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: mode,
        draft: draft,
        ministrySubjects: widget.ministrySubjects,
        teachers: askableTeachers(widget.teachers, avoided),
        studentStudyProgramId: switch (_selectedStudent)
        {
          final student? => currentStudyProgramId(student),
          null => null,
        },
        studentName: _selectedStudent?.firstName,
        isSelf: _isSelf,
        studentGender: _selectedStudent?.gender,
        isEditing: editing,
        gated: _isOwn,
        minutesAvailable: answers.hours[mode]!.totalMinutes,
        minutesTakenByOthers: _minutesAsked(group, mode) -
            (editing ? (draft.duration ?? 0) : 0),
        minutesByDisciplineTakenByOthers: _minutesByDiscipline(
          group,
          mode,
          skip: editing ? draft : null,
        ),
        onSave: (saved) async
        {
          setState(()
          {
            final requests = answers.requests[mode]!;

            if (editing)
            {
              final at = requests.indexOf(draft);

              if (at >= 0)
              {
                requests[at] = saved;

                return;
              }
            }

            requests.add(saved);
          });

          return true;
        },
      ),
    );
  }

  void _dropWhere(_DayGroup group, String mode, bool Function(SubjectRequestDraft) matches)
  {
    final at = _answersOf(group).requests[mode]!.indexWhere(matches);

    if (at >= 0)
    {
      _dropRequest(group, mode, at);
    }
  }

  void _dropSubject(_DayGroup group, String mode, int ministrySubjectId)
  {
    final requests = _answersOf(group).requests[mode]!;

    for (var index = 0; index < requests.length; index++)
    {
      if (requests[index].ministrySubjectId == ministrySubjectId)
      {
        setState(() => _dropRequest(group, mode, index));

        return;
      }
    }
  }

  SubjectRequestDraft? _requestFor(_DayGroup group, String mode, int ministrySubjectId)
  {
    for (final request in _answersOf(group).requests[mode]!)
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
    for (final group in _groups)
    {
      final _Answers answers = _answersOf(group);

      for (final mode in _modes)
      {
        if (answers.hours[mode]!.isNotEmpty)
        {
          continue;
        }

        for (var index = answers.requests[mode]!.length - 1; index >= 0; index--)
        {
          _dropRequest(group, mode, index);
        }
      }
    }
  }

  void _dropRequest(_DayGroup group, String mode, int index)
  {
    final request = _answersOf(group).requests[mode]!.removeAt(index);

    _topicControllers.remove(request)?.dispose();
    _notesControllers.remove(request)?.dispose();

    final existing = request.existing;

    if (existing != null)
    {
      _droppedBookings.add((mode, existing));
    }
  }

  List<_Card> get _cards
  {
    final List<_Card> asked = [
      for (final group in _groups) ...[
        if (_asksForMode(group)) (step: _Step.modes, group: group, mode: null),
        for (final mode in _modes)
          if (_effectiveModes(group).contains(mode)) ...[
            (step: _Step.hours, group: group, mode: mode),
            if (!widget.hoursOnly) (step: _Step.subjects, group: group, mode: mode),
          ],
      ],
    ];

    return [
      if (!_isEditing || asked.isEmpty) (step: _Step.who, group: null, mode: null),
      ...asked,
    ];
  }

  Widget _buildModesCard(_DayGroup group)
  {
    final open = _openModesOf(group);
    final chosen = _effectiveModes(group);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final mode in open)
          AppSelectableChip(
            label: modeLabel(mode),
            selected: chosen.contains(mode),
            onSelected: (selected) => _toggleMode(group, mode, selected),
          ),
      ],
    );
  }

  // Deselecting drops stored rows too, so saving deletes them.
  void _toggleMode(_DayGroup group, String mode, bool selected)
  {
    final _Answers answers = _answersOf(group);

    setState(()
    {
      if (selected)
      {
        answers.modes.add(mode);

        return;
      }

      answers.modes.remove(mode);

      for (final bucket in TimeBucket.values)
      {
        answers.hours[mode]!.toggle(bucket, null, null);
      }

      for (final request in answers.requests[mode]!)
      {
        _topicControllers.remove(request)?.dispose();
        _notesControllers.remove(request)?.dispose();
      }

      answers.requests[mode]!.clear();
    });
  }

  ({String question, String hint}) _guideOf(_Card card, {required bool named})
  {
    final String who = named ? ' $_who' : '';

    if (_isSelf)
    {
      return _selfGuideOf(card);
    }

    switch (card.step)
    {
      case _Step.who:
        return _isOwn
            ? (
                question: 'Quando?',
                hint: 'Indica i giorni da prenotare. Puoi indicare anche più giornate.',
              )
            : (
                question: 'Per chi e quando?',
                hint: 'Indica lo studente per cui stai effettuando la prenotazione e i giorni '
                    'da prenotare. Puoi indicare anche più giornate.',
              );

      case _Step.modes:
        return (
          question: 'Con quale modalità vuole fare lezione$who?',
          hint: 'In presenza, online, o entrambe.',
        );

      case _Step.hours:
        return card.mode == kPresenceMode
            ? (
                question: 'Quando è in Associazione$who?',
                hint: 'Indica gli orari in cui $_who sarà presente in Associazione.',
              )
            : (
                question: 'Quando può essere presente online$who?',
                hint: 'Indica gli orari in cui $_who è disponibile per essere '
                    '${_agreed('seguito', 'seguita')} a distanza.',
              );

      case _Step.subjects:
        return (
          question: card.mode == kPresenceMode
              ? 'Che lezioni vuole fare in Associazione$who?'
              : 'Che lezioni vuole fare online$who?',
          hint: 'Puoi selezionare una materia del suo indirizzo di studi, una qualsiasi '
              'disciplina offerta dall\'Associazione, oppure un servizio.',
        );
    }
  }

  ({String question, String hint}) _selfGuideOf(_Card card)
  {
    switch (card.step)
    {
      case _Step.who:
        return (
          question: 'Quando?',
          hint: 'Indica i giorni da prenotare. Puoi indicare anche più giornate.',
        );

      case _Step.modes:
        return (
          question: 'Con quale modalità vuoi fare lezione?',
          hint: 'In presenza, online, o entrambe.',
        );

      case _Step.hours:
        return card.mode == kPresenceMode
            ? (
                question: 'Quando sei in Associazione?',
                hint: 'Indica gli orari in cui sarai presente in Associazione.',
              )
            : (
                question: 'Quando puoi essere presente online?',
                hint: 'Indica gli orari in cui sei disponibile per essere '
                    '${_agreed('seguito', 'seguita')} a distanza.',
              );

      case _Step.subjects:
        return (
          question: card.mode == kPresenceMode
              ? 'Che lezioni vuoi fare in Associazione?'
              : 'Che lezioni vuoi fare online?',
          hint: 'Puoi selezionare una materia del tuo indirizzo di studi, una qualsiasi '
              'disciplina offerta dall\'Associazione, oppure un servizio.',
        );
    }
  }

  double _widthOf(_Card card)
  {
    return switch (card.step)
    {
      _Step.who => _isEditing ? _fixedFactsWidth : _wizardMaxWidth,
      _Step.modes => _groups.length > 1 ? _wizardMaxWidth : _modesCardWidth,
      _ => _wizardMaxWidth,
    };
  }

  Widget _buildCard(_Card card)
  {
    return switch (card.step)
    {
      _Step.who => _isEditing
          ? _buildFixedFacts()
          : (_isOwn ? _buildOwnWho() : _buildWho()),
      _Step.modes => _buildModesCard(card.group!),
      _Step.hours => _buildHours(card.group!, card.mode!),
      _Step.subjects => _buildSubjectsCard(card.group!, card.mode!),
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

    final _Card card = cards[_cardIndex];
    final guide = _guideOf(card, named: _cardIndex == (cards.first.step == _Step.who ? 1 : 0));

    return AppDialogStack(
      eyebrow: cards.length > 1
          ? 'Passo ${_cardIndex + 1} di ${cards.length}'
          : (_isEditing ? formatAvailableDayLabel(widget.defaultDate) : ''),
      title: _isOwn
          ? (_isEditing ? 'Modifica prenotazione' : 'Nuova prenotazione')
          : (_isEditing ? 'Modifica richiesta' : 'Nuova richiesta'),
      onClose: _closeDialog,
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          disabledReason: _isOwn && _saveBlockedReason != null ? kCompleteFieldsFirst : null,
          onPressed: _save,
        ),
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _wizardMaxWidth),
            child: AppDialogPill(
              expand: true,
              child: PersonEditGuide(question: guide.question, hint: guide.hint),
            ),
          ),
        ),
        AppCarouselFrame(
          index: _cardIndex,
          movingForward: _movingForward,
          header: _daysHeader(card),
          maxContentWidth: _widthOf(card),
          canGoBack: _cardIndex > 0,
          canGoForward: _cardIndex < cards.length - 1,
          showArrows: cards.length > 1,
          forwardBlockedReason: _blockedReason(card),
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(expand: true, child: _buildCard(card)),
        ),
      ],
    );
  }
}
