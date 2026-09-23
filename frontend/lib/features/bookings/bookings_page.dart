import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/carousel_arrow_button.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import '../association/models/association_subject_item.dart';
import '../association/models/ministry_subject_item.dart';
import '../association/models/opening_day_item.dart';
import '../association/models/service_item.dart';
import '../association/models/study_program_item.dart';
import '../lessons/models/booking_summary_item.dart';
import '../lessons/models/presence_group.dart';
import '../lessons/models/presence_item.dart';
import '../lessons/models/subject_request.dart';
import '../lessons/utils/booking_window.dart';
import '../lessons/utils/opening_window.dart';
import '../lessons/utils/study_program_lookup.dart';
import '../lessons/widgets/booking_fields_section.dart' show maxDailyMinutesPerDiscipline;
import '../lessons/widgets/presence_wizard.dart';
import '../lessons/widgets/subject_request_tile.dart';
import '../lessons/widgets/subject_request_wizard.dart';
import '../people/models/person_item.dart';
import 'widgets/booking_day_row.dart';
import 'widgets/move_lesson_dialog.dart';

const double _headerGap = 22;
const double _rowGap = 12;

const double _weekLabelWidth = 250;

const double _confirmWidth = 480;
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const Duration _tick = Duration(minutes: 1);

const String _parentRole = 'PARENT';
const String _studentRoleLabel = 'Studente';

// This week from its Monday; the next week unlocks Friday 20:00.
class BookingsPage extends StatefulWidget
{
  final String role;

  const BookingsPage({super.key, required this.role});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with DestinationRefresh, EntityWrites
{
  final ApiService _apiService = ApiService();

  DateTime _now = DateTime.now();

  Timer? _clock;

  // 0 for the week of today, 1 for the next.
  int _weekIndex = 0;

  bool _isLoading = true;
  bool _failed = false;

  List<PresenceItem> _presences = [];
  List<OpeningDayItem> _openingDays = [];

  List<PersonItem> _teachers = [];
  List<MinistrySubjectItem> _ministrySubjects = [];
  List<AssociationSubjectItem> _associationSubjects = [];
  List<ServiceItem> _services = [];
  List<StudyProgramItem> _studyPrograms = [];

  List<PersonItem> _pupils = [];

  bool get _isParent => widget.role == _parentRole;

  bool get _isReadOnly
  {
    return !_isParent && (_apiService.lastKnownIdentity?.hasParentalResponsibility ?? false);
  }

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  DateTime get _thisMonday => startOfWeek(_today);

  bool get _isNextWeekUnlocked => isNextWeekUnlocked(_now);

  List<DateTime> get _shownDays => daysOfWeek(addDays(_thisMonday, 7 * _weekIndex));

  @override
  void initState()
  {
    super.initState();

    _clock = Timer.periodic(_tick, (_)
    {
      // Offstage the tick is skipped; onDestinationShown realigns the clock.
      if (destinationShown)
      {
        _advanceClock();
      }
    });

    _loadData();
  }

  @override
  void dispose()
  {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void onDestinationShown()
  {
    _advanceClock();
    _loadData(quiet: true);
  }

  // Reloads once Monday midnight shifts the weeks.
  void _advanceClock()
  {
    final DateTime before = _thisMonday;

    setState(()
    {
      _now = DateTime.now();

      if (!_isNextWeekUnlocked)
      {
        _weekIndex = 0;
      }
    });

    if (!isSameDate(before, _thisMonday))
    {
      _loadData(quiet: true);
    }
  }

  // One's own record, or the children's: the register is the administrators' alone.
  Future<List<PersonItem>> _readPupils() async
  {
    final me = _apiService.lastKnownIdentity ?? await _apiService.me();
    final reader = await _apiService.getPerson(me.taxCode);

    if (!_isParent)
    {
      return [reader];
    }

    final List<PersonItem> children = await Future.wait([
      for (final child in reader.children ?? const [])
        _apiService.getPerson(child.fiscalCode),
    ]);

    return children.where((child) => child.roles.contains(_studentRoleLabel)).toList();
  }

  // Both weeks are always fetched so the Friday unlock needs no reload.
  Future<void> _loadData({bool quiet = false}) async
  {
    final DateTime from = _thisMonday;
    final DateTime to = addDays(from, 13);

    try
    {
      final bool catalogued = _teachers.isNotEmpty && _pupils.isNotEmpty;

      final results = await Future.wait([
        _apiService.getPresences(dateFrom: from, dateTo: to),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
        if (!catalogued) ...[
          _apiService.getTeachers(),
          _apiService.getMinistrySubjects(),
          _apiService.getAssociationSubjects(),
          _apiService.getServices(),
          _apiService.getStudyPrograms(),
        ],
      ]);

      List<PersonItem>? pupils;

      if (!catalogued)
      {
        pupils = await _readPupils();
      }

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _presences = results[0] as List<PresenceItem>;
        _openingDays = [
          ...results[1] as List<OpeningDayItem>,
          ...results[2] as List<OpeningDayItem>,
        ];

        if (!catalogued)
        {
          _teachers = results[3] as List<PersonItem>;
          _ministrySubjects = results[4] as List<MinistrySubjectItem>;
          _associationSubjects = results[5] as List<AssociationSubjectItem>;
          _services = results[6] as List<ServiceItem>;
          _studyPrograms = results[7] as List<StudyProgramItem>;
          _pupils = pupils!;
        }

        _isLoading = false;
        _failed = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle prenotazioni');

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _isLoading = false;
        _failed = !quiet || _pupils.isEmpty;
      });
    }
  }

  Future<void> _refreshPresence(int presenceId) async
  {
    try
    {
      final refreshed = await _apiService.getPresence(presenceId);

      if (mounted)
      {
        setState(() => _presences = _presences.map((p) => p.id == presenceId ? refreshed : p).toList());
      }
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'la rilettura di una prenotazione');
    }
  }

  Future<bool> _executeCreateLessonRequest(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError)
  {
    return write(
      call: () => _apiService.createLessonRequest(
        studentTaxCode: studentTaxCode,
        date: date,
        modes: modes,
      ),
      apply: (created) => _presences = [..._presences, ...created],
      onError: onError,
    );
  }

  Future<PresenceItem?> _executeCreatePresence(String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) async
  {
    PresenceItem? created;

    await write(
      call: () => _apiService.createPresence(
        studentTaxCode: studentTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
      ),
      apply: (row)
      {
        created = row;
        _presences = [..._presences, row];
      },
      onError: onError,
    );

    return created;
  }

  Future<bool> _executeEditPresence(PresenceItem existing, String studentTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError)
  {
    return write(
      call: () => _apiService.updatePresence(
        id: existing.id,
        studentTaxCode: studentTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      ),
      apply: (updated) => _presences = _presences.map((p) => p.id == existing.id ? updated : p).toList(),
      onError: onError,
    );
  }

  Future<bool> _executeDeletePresenceQuietly(PresenceItem item, Function(String) onError)
  {
    return erase(
      call: () => _apiService.deletePresence(item.id),
      apply: () => _presences = _presences.where((p) => p.id != item.id).toList(),
      onError: onError,
    );
  }

  Future<bool> _executeCreateBooking(int presenceId, Map<String, dynamic> subject, Function(String) onError) async
  {
    try
    {
      await _apiService.createBooking(presenceId: presenceId, subject: subject);
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }

    await _refreshPresence(presenceId);

    return true;
  }

  Future<bool> _executeEditBooking(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError) async
  {
    try
    {
      await _apiService.updateBooking(
        id: existing.id,
        subject: subject,
        expectedUpdatedAt: existing.updatedAt,
      );
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }

    await _refreshPresence(presenceId);

    return true;
  }

  Future<bool> _executeDeleteBookingQuietly(BookingSummaryItem booking, int presenceId, Function(String) onError) async
  {
    try
    {
      await _apiService.deleteBooking(booking.id);
    }
    catch (e)
    {
      onError(readableApiError(e));

      return false;
    }

    await _refreshPresence(presenceId);

    return true;
  }

  void _showError(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  void _showWizard(DateTime day, BookingLane lane, String mode, {bool openOnSubjects = false, bool hoursOnly = false})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'PresenceWizard',
      builder: (context) => PresenceWizardDialog(
        isOwn: true,
        isSelf: !_isParent,
        existingPresence: lane.group?.first,
        defaultStudentTaxCode: lane.pupil.fiscalCode,
        onlyMode: mode,
        openOnSubjects: openOnSubjects,
        hoursOnly: hoursOnly,
        presences: _presences,
        students: _pupils,
        teachers: _teachers,
        ministrySubjects: _ministrySubjects,
        associationSubjects: _associationSubjects,
        services: _services,
        studyPrograms: _studyPrograms,
        availableDays: computeAvailableDays(DateTime.now()),
        defaultDate: day,
        openingDays: _openingDays,
        onCreateLessonRequest: _executeCreateLessonRequest,
        onCreatePresence: _executeCreatePresence,
        onEditPresence: _executeEditPresence,
        onDeletePresenceQuietly: _executeDeletePresenceQuietly,
        onCreateBooking: _executeCreateBooking,
        onEditBooking: _executeEditBooking,
        onDeleteBooking: _executeDeleteBookingQuietly,
      ),
    );
  }

  // Read from current page state: a stale updated_at would get a 409.
  ({PresenceItem slot, BookingSummaryItem booking})? _whereItHangs(BookingSummaryItem booking)
  {
    for (final slot in _presences)
    {
      for (final row in slot.bookings)
      {
        if (row.id == booking.id)
        {
          return (slot: slot, booking: row);
        }
      }
    }

    return null;
  }

  List<MinistrySubjectItem> _offeredSubjectsFor(PersonItem pupil)
  {
    final allowed = allowedMinistrySubjectIds(pupil, _studyPrograms);

    return _ministrySubjects.where((subject) => allowed.contains(subject.id)).toList();
  }

  SubjectRequestDraft _draftOf(BookingSummaryItem booking)
  {
    return SubjectRequestDraft.fromBooking(
      booking,
      ministrySubjectName: ministrySubjectName(_ministrySubjects, booking.ministrySubjectId, fallback: ''),
    );
  }

  void _editLesson(BookingLane lane, BookingSummaryItem booking)
  {
    final held = _whereItHangs(booking);

    if (held != null)
    {
      _showLessonWizard(lane, held.slot, held.booking);
    }
  }

  void _showLessonWizard(BookingLane lane, PresenceItem slot, BookingSummaryItem existing)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return;
    }

    final avoided = group.notPreferredTeacherTaxCodes.toSet();

    // The picker hides avoided teachers, so drop them from the draft or they could never be removed.
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: slot.mode,
        draft: _draftOf(existing)..preferredTeacherTaxCodes.removeWhere(avoided.contains),
        ministrySubjects: _offeredSubjectsFor(lane.pupil),
        teachers: askableTeachers(_teachers, avoided),
        studentStudyProgramId: currentStudyProgramId(lane.pupil),
        studentName: lane.pupil.firstName,
        isSelf: !_isParent,
        studentGender: lane.pupil.gender,
        isEditing: true,
        gated: true,
        // The wizard counts the edited booking's own duration itself.
        minutesAvailable: group.minutesOfferedIn(slot.mode),
        minutesTakenByOthers: group.minutesAskedFor(slot.mode) - existing.duration,
        minutesByDisciplineTakenByOthers: group.minutesByDiscipline(slot.mode, skip: existing),
        onSave: (draft) => _writeLesson(slot, existing, draft),
      ),
    );
  }

  Future<bool> _writeLesson(PresenceItem slot, BookingSummaryItem existing, SubjectRequestDraft draft) async
  {
    if (!draft.isComplete)
    {
      _showError('Servono la materia, almeno una disciplina e la durata.');

      return false;
    }

    final success = await _executeEditBooking(existing, slot.id, draft.toJson(), _showError);

    if (success && mounted)
    {
      CustomSnackBar.show(context: context, message: 'Materia modificata con successo!', isError: false);
    }

    return success;
  }

  static String _ofBand(TimeBucket band)
  {
    return '${band == TimeBucket.afternoon ? 'del' : 'della'} ${bandLabel(band).toLowerCase()}';
  }

  static String _tooLong(String mode, TimeBucket band, int needed, int free)
  {
    return 'Le lezioni (${formatMinutes(needed)}) supererebbero le ore libere '
        '${modeLabel(mode).toLowerCase()} ${_ofBand(band)} (${formatMinutes(free)}).';
  }

  // [keep] is the row being grown, so its own hours do not obstruct; [gone] rows about to leave the day.
  OpeningWindow? _freeWindow(
    DateTime day,
    PresenceGroup? group,
    String mode,
    TimeBucket band, {
    PresenceItem? keep,
    Set<int> gone = const {},
  })
  {
    final OpeningWindow? window = openingWindowFor(_openingDays, day, mode, band);

    if (window == null)
    {
      return null;
    }

    List<(int, int)> pieces = [(window.startMinutes, window.endMinutes)];

    for (final row in group?.slots ?? const <PresenceItem>[])
    {
      if (row.id == keep?.id || gone.contains(row.id))
      {
        continue;
      }

      final int rowStart = minutesOfTimeOfDay(row.startTime);
      final int rowEnd = minutesOfTimeOfDay(row.endTime);

      pieces = [
        for (final (start, end) in pieces) ...[
          if (start < rowStart) (start, end < rowStart ? end : rowStart),
          if (end > rowEnd) (start > rowEnd ? start : rowEnd, end),
        ],
      ];
    }

    (int, int)? chosen;

    for (final piece in pieces)
    {
      if (piece.$2 <= piece.$1)
      {
        continue;
      }

      final bool holdsKept = keep != null &&
          piece.$1 <= minutesOfTimeOfDay(keep.startTime) &&
          minutesOfTimeOfDay(keep.endTime) <= piece.$2;

      if (holdsKept)
      {
        chosen = piece;

        break;
      }

      if (chosen == null || piece.$2 - piece.$1 > chosen.$2 - chosen.$1)
      {
        chosen = piece;
      }
    }

    if (chosen == null)
    {
      return null;
    }

    return OpeningWindow(startMinutes: chosen.$1, endMinutes: chosen.$2);
  }

  // A lesson alone on its row takes the row; the last lesson of a mode takes all the mode's rows.
  static _Move _oneMove(PresenceGroup group, PresenceItem from, BookingSummaryItem booking)
  {
    return _Move(
      fromMode: from.mode,
      bookings: [booking],
      leaving: group.requestsFor(from.mode).length == 1
          ? group.slotsFor(from.mode)
          : [if (from.bookings.length == 1) from],
    );
  }

  static _Move _allMove(PresenceGroup group, String mode)
  {
    return _Move(fromMode: mode, bookings: group.requestsFor(mode), leaving: group.slotsFor(mode));
  }

  // [group] is null when the pupil has nothing on the day yet.
  List<MoveOption> _moveOptions(DateTime day, PresenceGroup? group, _Move move, {required bool sameDay})
  {
    final List<MoveOption> options = [];
    final Set<int> gone = move.leavingIds;

    for (final mode in const [kPresenceMode, kOnlineMode])
    {
      for (final band in TimeBucket.values)
      {
        if (openingWindowFor(_openingDays, day, mode, band) == null || haveBookingsClosed(day, band, _now))
        {
          continue;
        }

        final List<PresenceItem> inBand = [
          for (final slot in group?.slotsFor(mode) ?? const <PresenceItem>[])
            if (bucketFor(slot.startTime) == band) slot,
        ];

        final List<PresenceItem> rows = [
          for (final slot in inBand)
            if (!move.holdsAll(slot)) slot,
        ];

        if (rows.isEmpty)
        {
          // The band the lessons already sit in.
          if (mode == move.fromMode && inBand.isNotEmpty)
          {
            continue;
          }

          final OpeningWindow? free = _freeWindow(day, group, mode, band, gone: gone);
          final int needed = move.minutes;

          options.add(MoveOption(
            mode: mode,
            band: band,
            slot: null,
            window: free,
            needed: needed,
            refusal: free == null || free.minutes < needed
                ? _tooLong(mode, band, needed, free?.minutes ?? 0)
                : _ceilingRefusal(group, move, mode, sameDay: sameDay),
          ));

          continue;
        }

        for (final row in rows)
        {
          final OpeningWindow? free = _freeWindow(day, group, mode, band, keep: row, gone: gone);
          final int needed = move.minutesStayingOn(row) + move.minutes;

          options.add(MoveOption(
            mode: mode,
            band: band,
            slot: row,
            window: free,
            needed: needed,
            refusal: free == null || free.minutes < needed
                ? _tooLong(mode, band, needed, free?.minutes ?? 0)
                : _ceilingRefusal(group, move, mode, sameDay: sameDay),
          ));
        }
      }
    }

    return options;
  }

  String? _ceilingRefusal(PresenceGroup? group, _Move move, String mode, {required bool sameDay})
  {
    if (sameDay && mode == move.fromMode)
    {
      return null;
    }

    final Map<int, int> taken = {...?group?.minutesByDiscipline(mode)};

    for (final booking in move.bookings)
    {
      for (final discipline in booking.disciplineIds)
      {
        final int total = (taken[discipline] ?? 0) + booking.duration;

        if (total > maxDailyMinutesPerDiscipline)
        {
          return 'Supererebbe le ${formatMinutes(maxDailyMinutesPerDiscipline)} al giorno per disciplina';
        }

        taken[discipline] = total;
      }
    }

    return null;
  }

  String _shutReason(DateTime day, {required bool own})
  {
    if (own)
    {
      return _anyBandShut(day) ? 'Le prenotazioni per le altre fasce orarie sono chiuse' : 'Non ci sono altre fasce orarie';
    }

    return _anyBandShut(day) ? 'Prenotazioni chiuse' : 'Associazione chiusa';
  }

  bool _anyBandShut(DateTime day)
  {
    for (final mode in const [kPresenceMode, kOnlineMode])
    {
      for (final band in TimeBucket.values)
      {
        if (openingWindowFor(_openingDays, day, mode, band) != null && haveBookingsClosed(day, band, _now))
        {
          return true;
        }
      }
    }

    return false;
  }

  MoveDay _moveDay(DateTime from, DateTime day, BookingLane lane, _Move move)
  {
    final bool sameDay = isSameDate(day, from);
    final List<MoveOption> options = _moveOptions(day, _groupOn(day, lane.pupil), move, sameDay: sameDay);

    return MoveDay(
      day: day,
      options: options,
      refusal: options.isEmpty ? _shutReason(day, own: sameDay) : null,
    );
  }

  List<MoveDay> _moveDays(DateTime from, BookingLane lane, _Move move)
  {
    return [
      for (final day in computeAvailableDays(DateTime.now())) _moveDay(from, day, lane, move),
    ];
  }

  bool _canMoveLesson(DateTime day, BookingLane lane, BookingSummaryItem booking)
  {
    final PresenceGroup? group = lane.group;
    final held = _whereItHangs(booking);

    if (group == null || held == null)
    {
      return false;
    }

    return _moveDays(day, lane, _oneMove(group, held.slot, held.booking)).any((day) => day.viable);
  }

  void _showMoveLesson(DateTime day, BookingLane lane, BookingSummaryItem booking)
  {
    final PresenceGroup? group = lane.group;
    final held = _whereItHangs(booking);

    if (group == null || held == null)
    {
      return;
    }

    final _Move move = _oneMove(group, held.slot, held.booking);

    _showMove(
      day,
      lane,
      group,
      move,
      title: bookingTitle(held.booking, _ministrySubjects),
      days: _moveDays(day, lane, move),
    );
  }

  String? _blockMoveRefusal(DateTime day, BookingLane lane, String mode)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return null;
    }

    for (final row in group.slotsFor(mode))
    {
      final TimeBucket? band = bucketFor(row.startTime);

      if (row.bookings.isNotEmpty && band != null && haveBookingsClosed(day, band, _now))
      {
        return 'Prenotazioni chiuse';
      }
    }

    final List<MoveDay> days = _moveDays(day, lane, _allMove(group, mode));

    if (days.any((option) => option.viable))
    {
      return null;
    }

    return days.every((option) => option.options.isEmpty && _anyBandShut(option.day))
        ? 'Le prenotazioni per le altre fasce orarie sono chiuse'
        : "Nessun'altra fascia oraria o giornata può contenere tutte le lezioni inserite";
  }

  void _showMoveBlock(DateTime day, BookingLane lane, String mode)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return;
    }

    final _Move move = _allMove(group, mode);

    _showMove(
      day,
      lane,
      group,
      move,
      title: 'Tutte le lezioni ${mode == kOnlineMode ? kOnScreen : kInBuilding}',
      days: _moveDays(day, lane, move),
    );
  }

  void _showMove(
    DateTime day,
    BookingLane lane,
    PresenceGroup group,
    _Move move, {
    required String title,
    required List<MoveDay> days,
  })
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'MoveLessons',
      builder: (dialogContext) => MoveLessonDialog(
        day: day,
        title: title,
        count: move.bookings.length,
        days: days,
        onMove: (target, option, start, end) async
        {
          Navigator.pop(dialogContext);
          await _moveLessons(target.day, lane, group, move, option, start, end);
        },
      ),
    );
  }

  void _moved(int count)
  {
    if (mounted)
    {
      CustomSnackBar.show(
        context: context,
        message: count == 1 ? 'Materia spostata con successo!' : 'Lezioni spostate con successo!',
        isError: false,
      );
    }
  }

  // [group] belongs to the day the lessons leave, not to [day].
  Future<void> _moveLessons(
    DateTime day,
    BookingLane lane,
    PresenceGroup group,
    _Move move,
    MoveOption option,
    TimeOfDay? start,
    TimeOfDay? end,
  ) async
  {
    final String taxCode = lane.pupil.fiscalCode;

    Future<bool> gather(PresenceItem on) async
    {
      for (final booking in move.bookings)
      {
        if (on.bookings.any((held) => held.id == booking.id))
        {
          continue;
        }

        try
        {
          await _apiService.updateBooking(
            id: booking.id,
            subject: {
              ...SubjectRequestDraft.fromBooking(booking).toJson(),
              'presence_id': on.id,
            },
            expectedUpdatedAt: booking.updatedAt,
          );
        }
        catch (e)
        {
          _showError(readableApiError(e));

          return false;
        }
      }

      return true;
    }

    Future<bool> dropLeaving({required PresenceItem but}) async
    {
      for (final row in move.leaving)
      {
        if (row.id != but.id && !await _executeDeletePresenceQuietly(row, _showError))
        {
          return false;
        }
      }

      return true;
    }

    PresenceItem? to = option.slot;

    if (to == null)
    {
      if (start == null || end == null)
      {
        return;
      }

      final PresenceItem? turned = move.turned;

      if (turned != null)
      {
        if (!await gather(turned) || !await dropLeaving(but: turned))
        {
          return;
        }

        if (await _executeEditPresence(turned, taxCode, day, option.mode, start, end, _showError))
        {
          _moved(move.bookings.length);
        }

        return;
      }

      to = await _executeCreatePresence(taxCode, day, option.mode, start, end, _showError);

      if (to == null)
      {
        return;
      }
    }

    if (!await gather(to) || !await dropLeaving(but: to))
    {
      return;
    }

    for (final row in group.slots)
    {
      if (row.id != to.id && !move.leavingIds.contains(row.id) && row.bookings.any(move.carries))
      {
        await _refreshPresence(row.id);
      }
    }

    if (option.slot != null && start != null && end != null)
    {
      if (!await _executeEditPresence(to, taxCode, day, to.mode, start, end, _showError))
      {
        return;
      }
    }
    else
    {
      await _refreshPresence(to.id);
    }

    _moved(move.bookings.length);
  }

  void _confirm(DateTime day, String warning, {required VoidCallback onConfirmed})
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmBookingDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: formatAvailableDayLabel(day),
        title: 'Confermi?',
        shrinkTitle: true,
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'ELIMINA',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              onConfirmed();
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text(
              warning,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _whose(BookingLane lane, {String what = ''})
  {
    final String part = what.isEmpty ? '' : ' $what';

    return _isParent
        ? 'La prenotazione$part di ${lane.pupil.firstName}'
        : 'La tua prenotazione$part';
  }

  Future<void> _deleteSlots(List<PresenceItem> slots, {required String done})
  {
    final removed = slots.map((slot) => slot.id).toSet();

    return erase(
      call: () async
      {
        for (final slot in slots)
        {
          await _apiService.deletePresence(slot.id);
        }
      },
      apply: () => _presences = _presences.where((p) => !removed.contains(p.id)).toList(),
      done: done,
    );
  }

  Future<void> _deleteLesson(PresenceItem slot, BookingSummaryItem booking) async
  {
    if (await _executeDeleteBookingQuietly(booking, slot.id, _showError) && mounted)
    {
      CustomSnackBar.show(context: context, message: 'Materia eliminata con successo!', isError: false);
    }
  }

  void _confirmDeleteDay(DateTime day, BookingLane lane)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return;
    }

    _confirm(
      day,
      '${_whose(lane)} di ${formatAvailableDayLabel(day).toLowerCase()} verrà eliminata definitivamente.',
      onConfirmed: () => _deleteSlots(group.slots, done: 'Prenotazione eliminata con successo!'),
    );
  }

  void _confirmDeleteMode(DateTime day, BookingLane lane, String mode)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return;
    }

    final String what = mode == kOnlineMode ? kOnScreen : kInBuilding;

    _confirm(
      day,
      '${_whose(lane, what: what)} di ${formatAvailableDayLabel(day).toLowerCase()} verrà eliminata definitivamente.',
      onConfirmed: () => _deleteSlots(group.slotsFor(mode), done: 'Prenotazione eliminata con successo!'),
    );
  }

  void _confirmDeleteLesson(DateTime day, BookingLane lane, BookingSummaryItem booking)
  {
    final PresenceGroup? group = lane.group;
    final held = _whereItHangs(booking);

    if (group == null || held == null)
    {
      return;
    }

    final PresenceItem slot = held.slot;

    // The last lesson of a mode takes the mode's hours with it.
    final bool last = group.requestsFor(slot.mode).length == 1;
    final String where = slot.mode == kOnlineMode ? kOnScreen : kInBuilding;

    final String label = bookingTitle(held.booking, _ministrySubjects);

    final String warning = last
        ? 'La materia $label verrà tolta dalla prenotazione. Era l\'unica lezione $where, '
            'quindi verrà eliminata anche la presenza $where.'
        : 'La materia $label verrà tolta dalla prenotazione.';

    _confirm(
      day,
      warning,
      onConfirmed: () => last
          ? _deleteSlots(group.slotsFor(slot.mode), done: 'Prenotazione $where eliminata con successo!')
          : _deleteLesson(slot, held.booking),
    );
  }

  PresenceGroup? _groupOn(DateTime day, PersonItem pupil)
  {
    final onTheDay = _presences
        .where((presence) => presence.studentTaxCode == pupil.fiscalCode && isSameDate(presence.date, day))
        .toList();

    if (onTheDay.isEmpty)
    {
      return null;
    }

    return groupPresences(onTheDay).single;
  }

  List<BookingLane> _lanesOn(DateTime day)
  {
    return [
      for (final pupil in _pupils) BookingLane(pupil: pupil, group: _groupOn(day, pupil)),
    ];
  }

  int _bookedDays(PersonItem pupil)
  {
    return _shownDays.where((day) => _groupOn(day, pupil) != null).length;
  }

  String get _summary
  {
    final String week = _weekIndex == 0 ? 'questa settimana' : 'la settimana prossima';

    String days(int count) => '$count ${count == 1 ? 'giorno' : 'giorni'}';

    if (_isReadOnly)
    {
      final int booked = _bookedDays(_pupils.single);

      return switch (booked)
      {
        0 => 'Non è stato prenotato nessun giorno $week.',
        1 => 'È stato prenotato 1 giorno $week.',
        _ => 'Sono stati prenotati ${days(booked)} $week.',
      };
    }

    if (!_isParent)
    {
      final int booked = _bookedDays(_pupils.single);

      return booked == 0
          ? 'Non hai ancora prenotato $week.'
          : 'Hai prenotato ${days(booked)} $week.';
    }

    if (_pupils.length == 1)
    {
      final PersonItem pupil = _pupils.single;
      final int booked = _bookedDays(pupil);

      return booked == 0
          ? '${pupil.firstName} non ha ancora prenotazioni $week.'
          : '${pupil.firstName} ha ${days(booked)} ${booked == 1 ? 'prenotato' : 'prenotati'} $week.';
    }

    final String counts = _pupils.map((pupil) => '${pupil.firstName} ${_bookedDays(pupil)}').join(', ');

    return 'Giorni prenotati $week: $counts';
  }

  String get _summaryLine
  {
    return [
      if (!_isLoading && !_failed && _pupils.isNotEmpty) _summary,
      if (!_isNextWeekUnlocked && !_isReadOnly) 'La settimana prossima si sblocca venerdì alle 20:00',
    ].join(' · ');
  }

  Widget _buildHeader(AppWindowSize size)
  {
    final List<DateTime> days = _shownDays;

    final Widget facts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatDateSpan(days.first, days.last),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialOcean,
          ),
        ),
        if (_summaryLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _summaryLine,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
        if (!_isReadOnly) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.trialMutedText),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Per le lezioni del mattino, è possibile prenotare o modificare '
                  'le prenotazioni fino alle 20:00 del giorno precedente; '
                  'per quelle del pomeriggio, fino alle 11:00 dello stesso '
                  'giorno; per quelle della sera, fino alle 18:00 dello stesso giorno.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (!_isNextWeekUnlocked)
    {
      return facts;
    }

    if (size.isCompact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          facts,
          const SizedBox(height: 16),
          _buildWeekNav(compact: true),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: facts),
        const SizedBox(width: 24),
        _buildWeekNav(compact: false),
      ],
    );
  }

  // Fixed label width keeps the arrows still as the text changes.
  Widget _buildWeekNav({required bool compact})
  {
    final Widget label = Text(
      _weekIndex == 0 ? 'Questa settimana' : 'Settimana prossima',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    return Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          isDisabled: _weekIndex == 0,
          onTap: () => setState(() => _weekIndex = 0),
        ),
        const SizedBox(width: 8),
        if (compact) Expanded(child: label) else SizedBox(width: _weekLabelWidth, child: label),
        const SizedBox(width: 8),
        CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          isDisabled: _weekIndex == 1,
          onTap: () => setState(() => _weekIndex = 1),
        ),
      ],
    );
  }

  Widget _buildNotice(String text, {double top = 40})
  {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: AppTheme.trialMutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildRows()
  {
    if (_isLoading)
    {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    if (_failed)
    {
      return _buildNotice('Non è stato possibile caricare le prenotazioni.');
    }

    if (_pupils.isEmpty)
    {
      return _buildNotice('Nessuno studente a tuo carico.');
    }

    final DateTime today = _today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in _shownDays) ...[
          if (!isSameDate(day, _shownDays.first)) const SizedBox(height: _rowGap),
          BookingDayRow(
            day: day,
            isToday: isSameDate(day, today),
            isPast: day.isBefore(today),
            lanes: _lanesOn(day),
            openingDays: _openingDays,
            now: _now,
            ministrySubjects: _ministrySubjects,
            teachers: _teachers,
            readOnly: _isReadOnly,
            onAdd: (lane, mode) => _showWizard(day, lane, mode),
            onEditHours: (lane, mode) => _showWizard(day, lane, mode, hoursOnly: true),
            onAddLesson: (lane, mode) => _showWizard(day, lane, mode, openOnSubjects: true),
            onEditLesson: _editLesson,
            canMoveLesson: (lane, booking) => _canMoveLesson(day, lane, booking),
            onMoveLesson: (lane, booking) => _showMoveLesson(day, lane, booking),
            blockMoveRefusal: (lane, mode) => _blockMoveRefusal(day, lane, mode),
            onMoveBlock: (lane, mode) => _showMoveBlock(day, lane, mode),
            onDeleteLesson: (lane, booking) => _confirmDeleteLesson(day, lane, booking),
            onDeleteMode: (lane, mode) => _confirmDeleteMode(day, lane, mode),
            onDeleteDay: (lane) => _confirmDeleteDay(day, lane),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.fromWidth(width);
          final double margin = AppBreakpoints.pageMargin(size);

          final double contentWidth = width - 2 * margin;

          return Container(
            width: width,
            height: height,
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, AppTopBar.contentTopInsetFor(size), margin, 28),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PageTransitionItem(
                              slot: PageTransitionItem.header,
                              child: _buildHeader(size),
                            ),
                            const SizedBox(height: _headerGap),
                            Expanded(
                              child: PageTransitionScrollView(
                                child: PageTransitionItem(
                                  slot: PageTransitionItem.list,
                                  child: _buildRows(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                AppTopBar(currentRoute: '${homeForRole(widget.role)}/bookings'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Move
{
  final String fromMode;

  final List<BookingSummaryItem> bookings;
  final List<PresenceItem> leaving;

  const _Move({required this.fromMode, required this.bookings, required this.leaving});

  Set<int> get leavingIds => {for (final row in leaving) row.id};

  int get minutes
  {
    var total = 0;

    for (final booking in bookings)
    {
      total += booking.duration;
    }

    return total;
  }

  bool carries(BookingSummaryItem booking) => bookings.any((moving) => moving.id == booking.id);

  bool holdsAll(PresenceItem row) => bookings.every((moving) => row.bookings.any((held) => held.id == moving.id));

  int minutesStayingOn(PresenceItem row)
  {
    var total = 0;

    for (final held in row.bookings)
    {
      if (!carries(held))
      {
        total += held.duration;
      }
    }

    return total;
  }

  // The leaving row reused for the new hours instead of creating one.
  PresenceItem? get turned
  {
    for (final row in leaving)
    {
      if (row.bookings.isNotEmpty)
      {
        return row;
      }
    }

    return null;
  }
}
