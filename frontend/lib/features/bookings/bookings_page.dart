import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/rome_clock.dart';
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
import '../lessons/models/band_offer.dart';
import '../lessons/models/booking_summary_item.dart';
import '../lessons/models/presence_group.dart';
import '../lessons/models/presence_item.dart';
import '../lessons/models/subject_request.dart';
import '../lessons/utils/booking_window.dart';
import '../lessons/utils/opening_window.dart';
import '../lessons/utils/study_program_lookup.dart';
import '../lessons/widgets/presence_wizard.dart';
import '../lessons/widgets/subject_request_tile.dart';
import '../lessons/widgets/subject_request_wizard.dart';
import '../people/models/person_item.dart';
import 'utils/booking_moves.dart';
import 'utils/booking_replacement.dart';
import 'utils/booking_strings.dart';
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

  DateTime _now = romeNow();

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

  // A pupil the parents answer for only looks, unless allowed to book too.
  bool get _isReadOnly
  {
    final identity = _apiService.lastKnownIdentity;

    return !_isParent &&
        (identity?.hasParentalResponsibility ?? false) &&
        !identity!.autonomousBookings;
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
      _now = romeNow();

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

  // Own record or the children's: the full register is admin-only.
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

  Future<bool> _executeReplaceLessonRequest(String studentTaxCode, DateTime date, List<Map<String, dynamic>> modes, Function(String) onError)
  {
    return write(
      call: () => _apiService.replaceLessonRequest(
        studentTaxCode: studentTaxCode,
        date: date,
        modes: modes,
      ),
      apply: (day) => _presences = [
        for (final presence in _presences)
          if (presence.studentTaxCode != studentTaxCode || !isSameDate(presence.date, date)) presence,
        ...day,
      ],
      onError: _readAgainAfter(onError),
    );
  }

  // A refused write may mean the day changed elsewhere.
  Function(String) _readAgainAfter(Function(String) onError)
  {
    return (message)
    {
      onError(message);
      _loadData(quiet: true);
    };
  }

  // [onto] is the row the lesson moves to, read again with the one it leaves.
  Future<bool> _executeEditBooking(BookingSummaryItem existing, int presenceId, Map<String, dynamic> subject, Function(String) onError, {int? onto}) async
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

    if (onto != null && onto != presenceId)
    {
      await _refreshPresence(onto);
    }

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

  void _showWizard(
    DateTime day,
    BookingLane lane,
    String mode, {
    bool openOnSubjects = false,
    bool hoursOnly = false,
    TimeBucket? band,
    bool onlyFreeBands = false,
  })
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
        availableDays: computeAvailableDays(romeNow()),
        defaultDate: day,
        openingDays: _openingDays,
        band: band,
        onlyFreeBands: onlyFreeBands,
        onCreateLessonRequest: _executeCreateLessonRequest,
        onReplaceLessonRequest: _executeReplaceLessonRequest,
      ),
    );
  }

  BookingMovePlanner get _planner => BookingMovePlanner(openingDays: _openingDays, presences: _presences, now: _now);

  ({PresenceItem slot, BookingSummaryItem booking})? _whereItHangs(BookingSummaryItem booking)
  {
    return _planner.whereItHangs(booking);
  }

  List<MinistrySubjectItem> _offeredSubjectsFor(PersonItem pupil)
  {
    final allowed = allowedMinistrySubjectIds(pupil, _studyPrograms);

    return _ministrySubjects.where((subject) => allowed.contains(subject.id)).toList();
  }

  SubjectRequestDraft _draftOf(BookingSummaryItem booking, {TimeBucket? band})
  {
    return SubjectRequestDraft.fromBooking(
      booking,
      ministrySubjectName: ministrySubjectName(_ministrySubjects, booking.ministrySubjectId, fallback: ''),
      band: band,
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

    // The catalogue comes already vetted by the server.
    final teachers = askableTeachers(_teachers, group.notPreferredTeacherTaxCodes);
    final offered = {for (final teacher in teachers) teacher.fiscalCode};

    // The picker shows only these, so drop the rest from the draft or they could never be removed.
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectRequestWizard',
      builder: (context) => SubjectRequestWizard(
        mode: slot.mode,
        draft: _draftOf(existing, band: bucketFor(slot.startTime))..preferredTeacherTaxCodes.retainWhere(offered.contains),
        ministrySubjects: _offeredSubjectsFor(lane.pupil),
        teachers: teachers,
        studentStudyProgramId: currentStudyProgramId(lane.pupil),
        studentName: lane.pupil.firstName,
        isSelf: !_isParent,
        studentGender: lane.pupil.gender,
        isEditing: true,
        // The wizard counts [existing] itself; a booked lesson changes band only by moving.
        bands: [
          for (final offer in groupBandOffers(group, slot.mode, skip: existing, isOpen: (band) => !haveBookingsClosed(group.date, band, _now)))
            if (offer.band == bucketFor(slot.startTime)) offer,
        ],
        minutesByDisciplineTakenByOthers: group.minutesByDiscipline(slot.mode, band: bucketFor(slot.startTime), skip: existing),
        onSave: (draft) => _writeLesson(group, slot, existing, draft),
      ),
    );
  }

  Future<bool> _writeLesson(PresenceGroup group, PresenceItem slot, BookingSummaryItem existing, SubjectRequestDraft draft) async
  {
    if (!draft.isComplete)
    {
      _showError(kLessonIncomplete);

      return false;
    }

    final TimeBucket? band = bucketFor(slot.startTime);
    final PresenceItem? onto = draft.band == band ? null : group.slotsFor(slot.mode, band: draft.band).firstOrNull;

    final success = await _executeEditBooking(existing, slot.id, {...draft.toJson(), 'presence_id': ?onto?.id}, _showError, onto: onto?.id);

    if (success && mounted)
    {
      CustomSnackBar.show(context: context, message: kLessonEdited, isError: false);
    }

    return success;
  }

  bool _canMoveLesson(DateTime day, BookingLane lane, BookingSummaryItem booking)
  {
    return _planner.canMoveLesson(day, lane.group, booking);
  }

  void _showMoveLesson(DateTime day, BookingLane lane, BookingSummaryItem booking)
  {
    final PresenceGroup? group = lane.group;
    final held = _whereItHangs(booking);

    if (group == null || held == null)
    {
      return;
    }

    final BookingMove move = BookingMove.one(group, held.slot, held.booking);

    _showMove(
      day,
      lane,
      group,
      move,
      title: bookingTitle(held.booking, _ministrySubjects),
      days: _planner.moveDays(day, lane.pupil.fiscalCode, move),
    );
  }

  String? _blockMoveRefusal(DateTime day, BookingLane lane, String mode, TimeBucket band)
  {
    return _planner.blockMoveRefusal(day, lane.group, mode, band);
  }

  void _showMoveBlock(DateTime day, BookingLane lane, String mode, TimeBucket band)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return;
    }

    final BookingMove move = BookingMove.all(group, mode, band);

    _showMove(
      day,
      lane,
      group,
      move,
      title: allLessonsTitle(mode, band: band),
      days: _planner.moveDays(day, lane.pupil.fiscalCode, move),
    );
  }

  void _showMove(
    DateTime day,
    BookingLane lane,
    PresenceGroup group,
    BookingMove move, {
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
        message: lessonsMoved(count),
        isError: false,
      );
    }
  }

  // [group] belongs to the day the lessons leave, not to [day].
  Future<void> _moveLessons(
    DateTime day,
    BookingLane lane,
    PresenceGroup group,
    BookingMove move,
    MoveOption option,
    TimeOfDay? start,
    TimeOfDay? end,
  ) async
  {
    final bool moved = await write(
      call: () => _apiService.replaceLessonRequestDays(
        studentTaxCode: lane.pupil.fiscalCode,
        days: _planner.moveRequest(from: group, move: move, day: day, option: option, start: start, end: end),
      ),
      apply: (written) => _presences = [
        for (final presence in _presences)
          if (presence.studentTaxCode != lane.pupil.fiscalCode ||
              !(isSameDate(presence.date, day) || isSameDate(presence.date, group.date)))
            presence,
        ...written,
      ],
      onError: _readAgainAfter(_showError),
    );

    if (moved)
    {
      _moved(move.bookings.length);
    }
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

  String? _named(BookingLane lane) => _isParent ? lane.pupil.firstName : null;

  // A null [band] clears every band of [modes]; one write either way.
  Future<void> _clear(PresenceGroup group, Iterable<String> modes, {TimeBucket? band, required String done}) async
  {
    final bool cleared = await _executeReplaceLessonRequest(
      group.studentTaxCode,
      group.date,
      [
        for (final mode in modes)
          modeReplacement(
            group,
            mode,
            dropping: band == null ? TimeBucket.values.toSet() : {band},
            closed: (other) => haveBookingsClosed(group.date, other, _now),
          ),
      ],
      _showError,
    );

    if (cleared && mounted)
    {
      CustomSnackBar.show(context: context, message: done, isError: false);
    }
  }

  Future<void> _deleteLesson(PresenceItem slot, BookingSummaryItem booking) async
  {
    if (await _executeDeleteBookingQuietly(booking, slot.id, _showError) && mounted)
    {
      CustomSnackBar.show(context: context, message: kLessonDeleted, isError: false);
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
      bookingDeletionWarning(day, pupil: _named(lane)),
      onConfirmed: () => _clear(group, const [kPresenceMode, kOnlineMode], done: kBookingDeleted),
    );
  }

  void _confirmDeleteBand(DateTime day, BookingLane lane, String mode, TimeBucket band)
  {
    final PresenceGroup? group = lane.group;

    if (group == null)
    {
      return;
    }

    _confirm(
      day,
      bookingDeletionWarning(day, pupil: _named(lane), mode: mode, band: band),
      onConfirmed: () => _clear(group, [mode], band: band, done: kBookingDeleted),
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
    final TimeBucket? band = bucketFor(slot.startTime);

    // The last lesson of a band takes the band's hours with it.
    final bool last = group.requestsFor(slot.mode, band: band).length == 1;

    _confirm(
      day,
      lessonDeletionWarning(bookingTitle(held.booking, _ministrySubjects), slot.mode, last: last, band: band),
      onConfirmed: () => last
          ? _clear(group, [slot.mode], band: band, done: modeBookingDeleted(slot.mode, band: band))
          : _deleteLesson(slot, held.booking),
    );
  }

  PresenceGroup? _groupOn(DateTime day, PersonItem pupil)
  {
    return _planner.groupOn(day, pupil.fiscalCode);
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
    final bool thisWeek = _weekIndex == 0;

    if (_isReadOnly)
    {
      return bookedForYouDays(_bookedDays(_pupils.single), thisWeek: thisWeek);
    }

    if (!_isParent)
    {
      return ownBookedDays(_bookedDays(_pupils.single), thisWeek: thisWeek);
    }

    if (_pupils.length == 1)
    {
      final PersonItem pupil = _pupils.single;

      return pupilBookedDays(pupil.firstName, _bookedDays(pupil), thisWeek: thisWeek);
    }

    final String week = thisWeek ? 'questa settimana' : 'la settimana prossima';
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
                  kBookingDeadlines,
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
      return _buildNotice(kBookingsLoadFailed);
    }

    if (_pupils.isEmpty)
    {
      return _buildNotice(kNoPupils);
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
            onAdd: (lane, mode) => _showWizard(day, lane, mode, onlyFreeBands: true),
            onEditHours: (lane, mode, band) => _showWizard(day, lane, mode, hoursOnly: true, band: band),
            onAddLesson: (lane, mode, band) => _showWizard(day, lane, mode, openOnSubjects: true, band: band),
            onEditLesson: _editLesson,
            canMoveLesson: (lane, booking) => _canMoveLesson(day, lane, booking),
            onMoveLesson: (lane, booking) => _showMoveLesson(day, lane, booking),
            blockMoveRefusal: (lane, mode, band) => _blockMoveRefusal(day, lane, mode, band),
            onMoveBlock: (lane, mode, band) => _showMoveBlock(day, lane, mode, band),
            onDeleteLesson: (lane, booking) => _confirmDeleteLesson(day, lane, booking),
            onDeleteBand: (lane, mode, band) => _confirmDeleteBand(day, lane, mode, band),
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
