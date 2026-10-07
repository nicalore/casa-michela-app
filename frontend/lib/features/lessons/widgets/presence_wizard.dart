import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
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
import '../../bookings/utils/booking_replacement.dart' show withLeftOut;
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_item.dart';
import '../models/band_offer.dart';
import '../models/booking_summary_item.dart';
import '../models/presence_item.dart';
import '../models/subject_request.dart';
import '../utils/booking_window.dart';
import '../utils/booking_wizard_strings.dart';
import '../utils/opening_window.dart';
import '../utils/study_program_lookup.dart';
import 'band_schedule.dart';
import 'booking_fields_section.dart' show maxDailyMinutesPerDiscipline;
import 'lesson_day_field.dart';
import 'lessons_form_fields.dart';
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

typedef _Card = ({_Step step, _DayGroup? group, String? mode, TimeBucket? band});

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

  final TimeBucket? band;
  final bool onlyFreeBands;

  final VoidCallback? onEditSaved;
  final Future<bool> Function(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError) onCreateLessonRequest;

  final Future<bool> Function(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError) onReplaceLessonRequest;

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
    this.band,
    this.onlyFreeBands = false,
    this.onEditSaved,
    required this.onCreateLessonRequest,
    required this.onReplaceLessonRequest,
  });

  @override
  State<PresenceWizardDialog> createState() => PresenceWizardDialogState();
}

class PresenceWizardDialogState extends State<PresenceWizardDialog>
{
  String? _selectedStudentTaxCode;

  Set<DateTime> _days = {};

  final Map<String, _Answers> _answersByGroup = {};

  static const List<String> _subjectCategoryLabels = kSubjectCategoryLabels;

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

  // One per subjects card: two cards of a mode can be on screen while the carousel turns.
  final Map<String, ScrollController> _subjectScrollControllers = {};

  // Rows and lessons in closed bands, which the server refuses to change: shown, never edited.
  final Map<String, Map<TimeBucket, List<BandStretch<PresenceItem>>>> _frozen = {
    for (final mode in _modes)
      mode: {for (final bucket in TimeBucket.values) bucket: <BandStretch<PresenceItem>>[]},
  };

  final Map<String, List<SubjectRequestDraft>> _frozenRequests = {
    for (final mode in _modes) mode: <SubjectRequestDraft>[],
  };

  // Read once: the dialog is short-lived, and the server enforces the rule.
  final DateTime _now = romeNow();

  int _cardIndex = 0;
  bool _movingForward = true;

  bool _isSaving = false;

  // Skipped when a failed save is retried.
  final Set<DateTime> _saved = {};

  final Map<SubjectRequestDraft, TextEditingController> _topicControllers = {};
  final Map<SubjectRequestDraft, TextEditingController> _notesControllers = {};

  bool get _isEditing => widget.existingPresence != null;

  // Snapshot at open: the wizard shows and writes against these even if the page reloads.
  late final List<PresenceItem> _seenRows = [...widget.presences];

  // null: every band. Rows outside it go back unchanged so the server keeps them.
  late final Set<TimeBucket>? _scope;
  final List<PresenceItem> _held = [];

  bool _inScope(TimeBucket band) => _scope?.contains(band) ?? true;

  List<TimeBucket> get _scopeBands => [for (final band in TimeBucket.values) if (_inScope(band)) band];

  Set<TimeBucket> _freeBandsOn(DateTime day, String mode)
  {
    return {
      for (final band in TimeBucket.values)
        if (!_isClosed(day, band) &&
            openingWindowFor(widget.openingDays, day, mode, band) != null &&
            !_seenRows.any((presence) =>
                presence.studentTaxCode == _selectedStudentTaxCode &&
                isSameDate(presence.date, day) &&
                bucketFor(presence.startTime) == band))
          band,
    };
  }

  final List<({String student, DateTime day, String mode})> _created = [];

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

  String get _whose
  {
    return switch (_selectedStudent)
    {
      final student? => 'di ${student.firstName}',
      null => 'dello studente',
    };
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

  // Empty when editing a whole day: the other mode's rows are in the answers then.
  Set<TimeBucket> _takenOn(DateTime day, String mode)
  {
    if (_isEditing && widget.onlyMode == null)
    {
      return const {};
    }

    final String other = _otherMode(mode);

    return {
      for (final presence in _seenRows)
        if (presence.mode == other && presence.studentTaxCode == _selectedStudentTaxCode && isSameDate(presence.date, day))
          ?bucketFor(presence.startTime),
    };
  }

  // Grouping key per mode and band: open window, '-' shut or closed, 'x' taken the other way.
  String _signatureOf(DateTime day)
  {
    final parts = <String>[];

    for (final mode in _modes)
    {
      final Set<TimeBucket> taken = _takenOn(day, mode);

      for (final bucket in TimeBucket.values)
      {
        final window = _isClosed(day, bucket) ? null : openingWindowFor(widget.openingDays, day, mode, bucket);

        parts.add(window == null ? '-' : (taken.contains(bucket) ? 'x' : '${window.startMinutes}-${window.endMinutes}'));
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
    if (!_inScope(bucket))
    {
      return null;
    }

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
      for (final presence in _seenRows)
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
      return takenByOtherMode(_otherMode(mode));
    }

    return _sharedWindow(group, mode, bucket) == null ? kAssociationShutBand : kBookingsShutBand;
  }

  List<String> _openModesOn(DateTime day)
  {
    return _modes
        .where((mode) => widget.onlyMode == null || mode == widget.onlyMode)
        .where((mode) => TimeBucket.values.any((bucket) =>
            !_isClosed(day, bucket) &&
            !_takenOn(day, mode).contains(bucket) &&
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

  // Booked days are edited from their row, never created again; null when free.
  String? _bookedRefusal(DateTime day)
  {
    if (_isEditing)
    {
      return null;
    }

    for (final presence in _seenRows)
    {
      if (presence.studentTaxCode == _selectedStudentTaxCode &&
          isSameDate(presence.date, day) &&
          (widget.onlyMode == null || presence.mode == widget.onlyMode))
      {
        return takenByOtherMode(presence.mode);
      }
    }

    for (final made in _created)
    {
      if (made.student == _selectedStudentTaxCode &&
          isSameDate(made.day, day) &&
          (widget.onlyMode == null || made.mode == widget.onlyMode))
      {
        return takenByOtherMode(made.mode);
      }
    }

    return null;
  }

  bool _isDayOffered(DateTime day) => _openModesOn(day).isNotEmpty && _bookedRefusal(day) == null;

  String _dayTooltip(DateTime day)
  {
    final bool open = _modes.any((mode) => isOpenOn(widget.openingDays, day, mode));

    if (_bookedRefusal(day) case final String booked)
    {
      return booked;
    }

    if (widget.onlyMode case final String only when open && !isOpenOn(widget.openingDays, day, only))
    {
      return modeShutAllDay(only);
    }

    for (final mode in _modes)
    {
      final bool takenAway = TimeBucket.values.any((bucket) =>
          !_isClosed(day, bucket) &&
          _takenOn(day, mode).contains(bucket) &&
          openingWindowFor(widget.openingDays, day, mode, bucket) != null);

      if ((widget.onlyMode == null || widget.onlyMode == mode) && takenAway)
      {
        return takenByOtherMode(_otherMode(mode));
      }
    }

    return bookingDayRefusal(day, shut: !open);
  }

  void _keepOfferedDays()
  {
    _days = _days.where(_isDayOffered).toSet();

    if (_days.isEmpty && _isDayOffered(_firstOfferedDay()))
    {
      _days = {_firstOfferedDay()};
    }
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
      _scope = widget.band == null ? null : {widget.band!};
      _selectedStudentTaxCode = _defaultStudentTaxCode;
      _days = {_firstOfferedDay()};

      return;
    }

    _selectedStudentTaxCode = existing.studentTaxCode;
    _days = {existing.date};
    _scope = switch ((widget.band, widget.onlyMode))
    {
      (final TimeBucket band, _) => {band},
      (null, final String mode) when widget.onlyFreeBands => _freeBandsOn(existing.date, mode),
      _ => null,
    };

    final _Answers answers = _answersOf(_editedGroup);

    for (final presence in _seenRows)
    {
      if (presence.studentTaxCode != existing.studentTaxCode ||
          !isSameDate(presence.date, existing.date) ||
          (widget.onlyMode != null && presence.mode != widget.onlyMode))
      {
        continue;
      }

      final bucket = bucketFor(presence.startTime);

      final frozen = bucket != null && _isClosed(existing.date, bucket);

      if (!frozen && bucket != null && !_inScope(bucket))
      {
        _held.add(presence);

        continue;
      }

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
          band: bucket,
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
          return kPickDayToGoOn;
        }

      case _Step.modes:
        if (_effectiveModes(card.group!).isEmpty)
        {
          return 'Scegli almeno una modalità per andare avanti.';
        }

      case _Step.hours:
        final BandSchedule<PresenceItem> hours = _answersOf(card.group!).hours[card.mode]!;

        if (hours.isEmpty)
        {
          return hoursToGoOn(card.mode!);
        }

        if (hours.overlapping case final TimeBucket band)
        {
          return hoursOverlap(card.mode!, band);
        }

      case _Step.subjects:
        if (card.mode == kOnlineMode &&
            !_answersOf(card.group!).requests[kOnlineMode]!.any((request) => request.band == card.band))
        {
          return kPickSubjectToGoOn;
        }
    }

    return null;
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();
  }

  int _minutesAsked(_DayGroup group, String mode, {TimeBucket? band, SubjectRequestDraft? skip})
  {
    var minutes = 0;

    for (final request in _answersOf(group).requests[mode]!)
    {
      if (!identical(request, skip) && (band == null || request.band == band))
      {
        minutes += request.duration ?? 0;
      }
    }

    return minutes;
  }

  List<BandOffer> _bandOffers(_DayGroup group, String mode, {SubjectRequestDraft? skip})
  {
    final BandSchedule<PresenceItem> hours = _answersOf(group).hours[mode]!;

    return [
      for (final band in hours.bands)
          BandOffer(
            band: band,
            hours: [
              for (final stretch in [...hours.of(band)]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)))
                formatTimeRange(stretch.startTime, stretch.endTime),
            ].join(' · '),
            minutes: hours.minutesIn(band),
            takenByOthers: _minutesAsked(group, mode, band: band, skip: skip),
          ),
    ];
  }

  // Per band, as the server caps it; a null [band] sums the whole mode.
  Map<int, int> _minutesByDiscipline(_DayGroup group, String mode, {TimeBucket? band, SubjectRequestDraft? skip})
  {
    final minutes = <int, int>{};

    for (final request in [..._answersOf(group).requests[mode]!, ..._frozenRequests[mode]!])
    {
      if (identical(request, skip) || (band != null && request.band != band))
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
      return kPickADayToSave;
    }

    for (final day in _days)
    {
      if (_bookedRefusal(day) case final String booked)
      {
        return booked;
      }
    }

    final groups = _groups;

    if (groups.every((group) => _modes.every((mode) => _answersOf(group).hours[mode]!.isEmpty)) &&
        !_hasAnyFrozen &&
        !_isClearing)
    {
      return kGiveAnHour;
    }

    if (!_isEditing && groups.any((group) => _modePayloads(group).isEmpty))
    {
      return kGiveAnHour;
    }

    for (final group in groups)
    {
      final _Answers answers = _answersOf(group);
      final String days = _daysLabel(group);

      for (final mode in _effectiveModes(group))
      {
        if (answers.hours[mode]!.overlapping case final TimeBucket band)
        {
          return hoursOverlap(mode, band, days);
        }
      }

      if (_effectiveModes(group).contains(kOnlineMode) &&
          answers.hours[kOnlineMode]!.isNotEmpty &&
          answers.requests[kOnlineMode]!.isEmpty)
      {
        return onlineSubjectMissing(days);
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
          return subjectsWithoutHours(label);
        }

        for (final request in requests)
        {
          if (!request.isComplete)
          {
            return durationMissing(request.displayName, label);
          }

          if (request.asksForTopicAndTag && request.tags.isEmpty)
          {
            return lessonKindMissing(request.displayName, label);
          }
        }

        final BandSchedule<PresenceItem> hours = answers.hours[mode]!;

        for (final band in hours.bands)
        {
          for (final entry in _minutesByDiscipline(group, mode, band: band).entries)
          {
            if (entry.value > maxDailyMinutesPerDiscipline)
            {
              return disciplineOverBand(
                _disciplineName(entry.key),
                entry.value,
                maxDailyMinutesPerDiscipline,
                '${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)}$days',
              );
            }
          }
        }

        for (final band in TimeBucket.values)
        {
          if (_minutesAsked(group, mode, band: band) <= hours.minutesIn(band))
          {
            continue;
          }

          return hours.bands.length > 1
              ? bandStayExceeded(band, days, isSelf: _isSelf, whose: _whose)
              : stayExceeded(days, isSelf: _isSelf, whose: _whose);
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
    if (!_isOwn || !_isEditing || !_hasAnyFrozen)
    {
      return false;
    }

    final _Answers answers = _answersOf(_editedGroup);

    return _modes.every((mode) =>
        answers.hours[mode]!.isEmpty && answers.hours[mode]!.dropped.isEmpty && answers.requests[mode]!.isEmpty);
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

    setState(() => _isSaving = true);

    void showError(String message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    }

    void stop()
    {
      if (mounted)
      {
        setState(() => _isSaving = false);
      }
    }

    for (final group in _groups)
    {
      for (final day in group.days)
      {
        if (_saved.contains(day))
        {
          continue;
        }

        final bool written = _isEditing
            ? await widget.onReplaceLessonRequest(
                studentTaxCode,
                day,
                withLeftOut(
                  _replacementOf(group),
                  _seenRows.where((presence) => presence.studentTaxCode == studentTaxCode && isSameDate(presence.date, day)),
                  closed: (band) => _isClosed(day, band),
                ),
                showError,
              )
            : await widget.onCreateLessonRequest(studentTaxCode, day, _modePayloads(group), showError);

        if (!written)
        {
          stop();

          return;
        }

        if (!_isEditing)
        {
          for (final block in _modePayloads(group))
          {
            _created.add((student: studentTaxCode, day: day, mode: block['mode'] as String));
          }
        }

        _saved.add(day);
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

    CustomSnackBar.show(
      context: context,
      message: presenceSaved(own: _isOwn, editing: _isEditing, cleared: cleared, days: _days.length),
      isError: false,
    );

    if (_isEditing || _isOwn)
    {
      Navigator.of(context).pop();

      if (_isEditing)
      {
        widget.onEditSaved?.call();
      }
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
              for (final stretch in answers.hours[mode]!.fused().all)
                {
                  'start_time': formatTimeOfDay(stretch.startTime),
                  'end_time': formatTimeOfDay(stretch.endTime),
                },
            ],
            'subjects': [
              for (final request in answers.requests[mode]!) request.toRequestJson(),
            ],
          },
    ];
  }

  // An unchosen mode clears; closed-band rows are left out and the server keeps them.
  List<Map<String, dynamic>> _replacementOf(_DayGroup group)
  {
    final _Answers answers = _answersOf(group);
    final Set<String> chosen = _effectiveModes(group);

    return [
      for (final mode in _modes)
        if (widget.onlyMode == null || widget.onlyMode == mode)
          {
            'mode': mode,
            'slots': [
              if (chosen.contains(mode))
                for (final stretch in answers.hours[mode]!.fused().all)
                  {
                    'start_time': formatTimeOfDay(stretch.startTime),
                    'end_time': formatTimeOfDay(stretch.endTime),
                    if (stretch.existing case final PresenceItem stored) ...{
                      'presence_id': stored.id,
                      'expected_updated_at': stored.updatedAt.toIso8601String(),
                    },
                  },
              for (final row in _held)
                if (row.mode == mode)
                  {
                    'start_time': formatTimeOfDay(row.startTime),
                    'end_time': formatTimeOfDay(row.endTime),
                    'presence_id': row.id,
                    'expected_updated_at': row.updatedAt.toIso8601String(),
                  },
            ],
            'subjects': [
              if (chosen.contains(mode))
                for (final request in answers.requests[mode]!) request.toRequestJson(),
              for (final row in _held)
                if (row.mode == mode)
                  for (final booking in row.bookings)
                    SubjectRequestDraft.fromBooking(booking, band: bucketFor(row.startTime)).toRequestJson(),
            ],
          },
    ];
  }

  Widget _buildDayField()
  {
    return LessonDayField(
      days: widget.availableDays,
      values: _days,
      onChanged: _selectDays,
      summary: (count) => bookingDaysSummary(count, split: _groups.length > 1),
      isEnabled: _isDayOffered,
      disabledTooltip: _dayTooltip,
    );
  }

  Widget _buildWho()
  {
    final studentOptions = personPickerOptions(widget.students);

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
          onSelected: (value) => setState(()
          {
            _selectedStudentTaxCode = value;
            _keepOfferedDays();
          }),
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
          _buildHint(modeShutAllDay(mode))
        else ...[
          BandScheduleField<PresenceItem>(
            schedule: _answersOf(group).hours[mode]!,
            bands: _scopeBands,
            windowFor: (bucket) => _windowFor(group, mode, bucket),
            offLabel: kNotPresent,
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

  Widget _buildSubjectsCard(_DayGroup group, String mode, TimeBucket band)
  {
    if (_selectedStudentTaxCode == null)
    {
      return _buildHint('Scegli prima lo studente.');
    }

    final category = _subjectCategory[mode] ?? _ministryCategory;
    final ScrollController scroll = _subjectScrollControllers.putIfAbsent('$mode/${band.name}', ScrollController.new);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_bandOffers(group, mode).where((offer) => offer.band == band).firstOrNull case final BandOffer offer) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${bandLabel(band)} · ${offer.hours} · '),
                TextSpan(
                  text: minutesLeftLabel(offer.left),
                  style: offer.left <= 0 ? const TextStyle(color: AppTheme.trialDanger) : null,
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 14),
        ],
        AppSegmentedTabs(
          labels: _subjectCategoryLabels,
          selectedIndex: category,
          onSelected: (index) => setState(() => _subjectCategory[mode] = index),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _subjectListMaxHeight),
          child: Scrollbar(
            controller: scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.only(right: 12),
              child: switch (category)
              {
                _ministryCategory => _buildMinistryList(group, mode, band),
                _disciplineCategory => _buildDisciplineList(group, mode, band),
                _ => _buildServiceList(group, mode, band),
              },
            ),
          ),
        ),
      ],
    );
  }

  String _summaryOf(SubjectRequestDraft request, {bool withBand = false})
  {
    final parts = <String>[];
    final TimeBucket? band = request.band;

    if (withBand && band != null)
    {
      parts.add(bandLabel(band));
    }

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
    required TimeBucket band,
    required String name,
    required bool Function(SubjectRequestDraft request) matches,
    required SubjectRequestDraft Function() onPick,
    String? description,
  })
  {
    final SubjectRequestDraft? chosen = _chosen(group, mode, band, matches);

    // A subject already chosen opens to be changed or removed, never dropped by a stray click.
    return SubjectPickRow(
      name: name,
      subtitle: _sayBoth(chosen == null ? null : _summaryOf(chosen), description),
      selected: chosen != null,
      hasChoice: false,
      onSelected: (_)
      {
        if (chosen != null)
        {
          _editRequest(group, mode, band, chosen);

          return;
        }

        if (_bandOffers(group, mode).where((offer) => offer.band == band).firstOrNull case final offer?
            when offer.left <= 0)
        {
          CustomSnackBar.show(context: context, message: bandTimeAllTaken(mode, band), isError: true);

          return;
        }

        _openRequestWizard(group, mode, band, onPick());
      },
      onEditDisciplines: () {},
    );
  }

  // The card's band only: the same subject may be booked in another band too.
  SubjectRequestDraft? _chosen(_DayGroup group, String mode, TimeBucket band, bool Function(SubjectRequestDraft request) matches)
  {
    return _answersOf(group).requests[mode]!.where((request) => request.band == band && matches(request)).firstOrNull;
  }

  void _editRequest(_DayGroup group, String mode, TimeBucket band, SubjectRequestDraft request)
  {
    _openRequestWizard(
      group,
      mode,
      band,
      request,
      editing: true,
      onRemove: () => setState(()
      {
        final int at = _answersOf(group).requests[mode]!.indexOf(request);

        if (at >= 0)
        {
          _dropRequest(group, mode, at);
        }
      }),
    );
  }

  // Booked subjects are edited from their own row, so adding to a band lists only new ones.
  bool _listed(_DayGroup group, String mode, TimeBucket band, bool Function(SubjectRequestDraft request) matches)
  {
    return !widget.openOnSubjects || _chosen(group, mode, band, matches)?.existing == null;
  }

  Widget _buildMinistryList(_DayGroup group, String mode, TimeBucket band)
  {
    final all = _filteredMinistrySubjects;

    if (all.isEmpty)
    {
      return _buildEmptyCategory(
        noProgrammeSubjects(isSelf: _isSelf, whose: _whose),
      );
    }

    final subjects = all
        .where((subject) => _matchesQuery(subject.name, mode, _ministryCategory))
        .where((subject) => _listed(group, mode, band, (request) => request.ministrySubjectId == subject.id))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySearch(mode, _ministryCategory, kSubjectSearchHints[_ministryCategory]),
        if (subjects.isEmpty)
          _buildEmptyCategory(kSubjectNoMatch[_ministryCategory]),
        for (final subject in subjects)
          _buildPickRow(
            group: group,
            mode: mode,
            band: band,
            name: subject.name,
            matches: (request) => request.ministrySubjectId == subject.id,
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.ministrySubject,
              ministrySubjectId: subject.id,
              associationSubjectIds: {
                if (subject.associationSubjects.length == 1)
                  subject.associationSubjects.single.id,
              },
            )..ministrySubjectName = subject.name,
          ),
      ],
    );
  }

  Widget _buildDisciplineList(_DayGroup group, String mode, TimeBucket band)
  {
    final all = _standaloneDisciplines;

    if (all.isEmpty)
    {
      return _buildEmptyCategory(
        allDisciplinesCovered(isSelf: _isSelf, whose: _whose),
      );
    }

    final disciplines = all
        .where((discipline) => _matchesQuery(discipline.name, mode, _disciplineCategory))
        .where((discipline) => _listed(group, mode, band, (request) => request.associationSubjectId == discipline.id))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySearch(mode, _disciplineCategory, kSubjectSearchHints[_disciplineCategory]),
        if (disciplines.isEmpty)
          _buildEmptyCategory(kSubjectNoMatch[_disciplineCategory]),
        for (final discipline in disciplines)
          _buildPickRow(
            group: group,
            mode: mode,
            band: band,
            name: discipline.name,
            description: discipline.description,
            matches: (request) => request.associationSubjectId == discipline.id,
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.associationSubject,
              associationSubjectId: discipline.id,
              associationSubjectName: discipline.name,
            ),
          ),
      ],
    );
  }

  Widget _buildServiceList(_DayGroup group, String mode, TimeBucket band)
  {
    if (widget.services.isEmpty)
    {
      return _buildEmptyCategory(kNoServices);
    }

    final services = widget.services
        .where((service) => _matchesQuery(service.name, mode, _serviceCategory))
        .where((service) => _listed(group, mode, band, (request) => request.serviceName == service.name))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySearch(mode, _serviceCategory, kSubjectSearchHints[_serviceCategory]),
        if (services.isEmpty)
          _buildEmptyCategory(kSubjectNoMatch[_serviceCategory]),
        for (final service in services)
          _buildPickRow(
            group: group,
            mode: mode,
            band: band,
            name: service.name,
            description: service.description,
            matches: (request) => request.serviceName == service.name,
            onPick: () => SubjectRequestDraft(
              kind: BookingRequestKind.service,
              serviceName: service.name,
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
    TimeBucket band,
    SubjectRequestDraft draft, {
    bool editing = false,
    VoidCallback? onRemove,
  })
  {
    // The pupils' catalogue comes already vetted by the server, without the memberships to vet it here.
    final teachers = askableTeachers(
      _isOwn ? widget.teachers : activeCollaborators(widget.teachers),
      _avoidedTeachers,
    );
    final offered = {for (final teacher in teachers) teacher.fiscalCode};
    final _Answers answers = _answersOf(group);

    // The picker shows only these, so drop the rest here or they could never be removed.
    draft.preferredTeacherTaxCodes.retainWhere(offered.contains);

    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: mode,
        draft: draft,
        ministrySubjects: widget.ministrySubjects,
        teachers: teachers,
        studentStudyProgramId: switch (_selectedStudent)
        {
          final student? => currentStudyProgramId(student),
          null => null,
        },
        studentName: _selectedStudent?.firstName,
        isSelf: _isSelf,
        studentGender: _selectedStudent?.gender,
        isEditing: editing,
        onRemove: onRemove,
        bands: [
          for (final offer in _bandOffers(group, mode, skip: editing ? draft : null))
            if (offer.band == band) offer,
        ],
        minutesByDisciplineTakenByOthers: _minutesByDiscipline(
          group,
          mode,
          band: band,
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

  void _dropSubjectsWithoutHours()
  {
    for (final group in _groups)
    {
      final _Answers answers = _answersOf(group);

      for (final mode in _modes)
      {
        final List<TimeBucket> bands = answers.hours[mode]!.bands;
        final List<SubjectRequestDraft> requests = answers.requests[mode]!;

        for (var index = requests.length - 1; index >= 0; index--)
        {
          if (!bands.contains(requests[index].band))
          {
            _dropRequest(group, mode, index);
          }
        }
      }
    }
  }

  void _dropRequest(_DayGroup group, String mode, int index)
  {
    final request = _answersOf(group).requests[mode]!.removeAt(index);

    _topicControllers.remove(request)?.dispose();
    _notesControllers.remove(request)?.dispose();
  }

  List<_Card> get _cards
  {
    final List<_Card> asked = [
      for (final group in _groups) ...[
        if (_asksForMode(group)) (step: _Step.modes, group: group, mode: null, band: null),
        for (final mode in _modes)
          if (_effectiveModes(group).contains(mode)) ...[
            if (!widget.openOnSubjects) (step: _Step.hours, group: group, mode: mode, band: null),
            if (!widget.hoursOnly)
              for (final band in _answersOf(group).hours[mode]!.bands)
                (step: _Step.subjects, group: group, mode: mode, band: band),
          ],
      ],
    ];

    return [
      if (!_isEditing || asked.isEmpty) (step: _Step.who, group: null, mode: null, band: null),
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

  WizardGuide _guideOf(_Card card, {required bool named})
  {
    final String? name = _selectedStudent?.firstName;
    final bool female = _selectedStudent?.gender == 'F';

    return switch (card.step)
    {
      _Step.who => _isOwn || _isSelf
          ? kOwnBookingDaysGuide
          : (
              question: 'Per chi e quando?',
              hint: 'Indica lo studente per cui stai effettuando la prenotazione e i giorni '
                  'da prenotare. Puoi indicare anche più giornate.',
            ),
      _Step.modes => presenceModesGuide(isSelf: _isSelf, name: name, named: named),
      _Step.hours => presenceHoursGuide(card.mode!, isSelf: _isSelf, name: name, named: named, female: female),
      _Step.subjects => presenceSubjectsGuide(card.mode!, isSelf: _isSelf, name: name, named: named),
    };
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
      _Step.subjects => _buildSubjectsCard(card.group!, card.mode!, card.band!),
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
          ? (_isEditing ? kEditBookingTitle : kNewBookingTitle)
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
          // Alone while nothing is chosen yet: the cards that follow hang on the answer.
          showArrows: cards.length > 1 || _blockedReason(card) != null,
          forwardBlockedReason: _blockedReason(card),
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(expand: true, child: _buildCard(card)),
        ),
      ],
    );
  }
}
