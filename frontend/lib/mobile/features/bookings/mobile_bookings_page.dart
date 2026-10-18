import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/association_subject_item.dart';
import '../../../features/association/models/ministry_subject_item.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/models/service_item.dart';
import '../../../features/association/models/study_program_item.dart';
import '../../../features/association/teacher_opinions.dart' show canSpeakFor;
import '../../../features/auth/models/me_response.dart';
import '../../../features/availability/utils/availability_strings.dart' show kNextWeekUnlockNotice;
import '../../../features/bookings/utils/booking_moves.dart';
import '../../../features/bookings/utils/booking_replacement.dart';
import '../../../features/bookings/utils/booking_strings.dart';
import '../../../features/lessons/models/band_offer.dart';
import '../../../features/lessons/models/booking_summary_item.dart';
import '../../../features/lessons/models/presence_group.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/models/subject_request.dart';
import '../../../features/lessons/utils/booking_window.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/utils/study_program_lookup.dart';
import '../../../features/lessons/widgets/subject_request_tile.dart' show ministrySubjectName;
import '../../../features/notifications/bookings_seen.dart';
import '../../../features/notifications/week_jump.dart';
import '../../../features/people/models/person_face.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_confirm_sheet.dart';
import '../../shared/widgets/mobile_filter_chip.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_info_sheet.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../children/widgets/mobile_child_tiles.dart';
import 'mobile_booking_day.dart';
import 'mobile_booking_draft.dart';
import 'mobile_bookings_tour.dart';
import 'widgets/mobile_booking_day_card.dart';
import 'widgets/mobile_booking_sheets.dart';
import 'widgets/mobile_booking_wizard.dart';
import 'widgets/mobile_move_sheet.dart';
import 'widgets/mobile_subject_flow.dart';

const String _title = 'Prenotazioni';

const String _parentRole = 'PARENT';

const Duration _pageTurn = Duration(milliseconds: 320);
const String _pupilRole = 'Studente';

const List<String> _weeks = ['Questa settimana', 'Settimana prossima'];

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _tilesGap = 6;
const double _chipsGap = 12;
const double _chipsStripGap = 14;
const double _stripGap = 18;
const double _cardGap = 12;

const double _topRoom = 16;

const EdgeInsets _tourInfoInflate = EdgeInsets.all(6);
const double _tourInfoRadius = 30;
const EdgeInsets _tourChipInflate = EdgeInsets.all(5);
const double _tourChipRadius = 21;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

class MobileBookingsPage extends StatefulWidget
{
  final MeResponse user;
  final String role;

  final DateTime Function() clock;

  const MobileBookingsPage({super.key, required this.user, required this.role, this.clock = romeNow});

  @override
  State<MobileBookingsPage> createState() => _MobileBookingsPageState();
}

class _MobileBookingsPageState extends State<MobileBookingsPage>
{
  final ApiService _apiService = ApiService();
  // Opened from a notification: on the week it is about, and the child it is about.
  DateTime? _askedDay;
  late final PageController _pages = PageController(initialPage: _weekOf(_askedDay));
  final BookingSheetTourLink _sheetLink = BookingSheetTourLink();

  late DateTime _now = widget.clock();

  Timer? _clock;

  bool _loading = true;
  bool _failed = false;

  // Set once the page is in place; from then on every load and page change looks for a tour.
  bool _toured = false;
  int? _pageSeen;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  List<PresenceItem> _presences = const [];
  List<OpeningDayItem> _openingDays = const [];

  List<PersonItem> _teachers = const [];
  List<MinistrySubjectItem> _ministrySubjects = const [];
  List<AssociationSubjectItem> _associationSubjects = const [];
  List<ServiceItem> _services = const [];
  List<StudyProgramItem> _studyPrograms = const [];

  List<PersonItem> _pupils = const [];

  // By tax code, so a refresh that reorders the children keeps the one shown.
  String? _shown;

  bool get _isParent => widget.role == _parentRole;

  // A pupil with parents only looks, unless allowed to book.
  bool get _readOnly => !canSpeakFor(widget.role);

  // Read-only: the next week shows only once unlocked.
  int get _weekCount => _readOnly && !isNextWeekUnlocked(_now) ? 1 : _weeks.length;

  String? _named(PersonItem pupil) => _isParent ? pupil.firstName : null;

  String get _tourFor => widget.user.taxCode;

  DateTime get _monday => startOfWeek(DateTime(_now.year, _now.month, _now.day));

  BookingMovePlanner get _planner => BookingMovePlanner(openingDays: _openingDays, presences: _presences, now: _now);

  MobileBookingCatalogue get _catalogue => MobileBookingCatalogue(
        teachers: _teachers,
        ministrySubjects: _ministrySubjects,
        associationSubjects: _associationSubjects,
        services: _services,
        studyPrograms: _studyPrograms,
      );

  PersonItem? get _pupil
  {
    for (final pupil in _pupils)
    {
      if (pupil.fiscalCode == _shown)
      {
        return pupil;
      }
    }

    return null;
  }

  @override
  void initState()
  {
    super.initState();

    final ({DateTime day, String? pupil})? asked = WeekJumps.bookings.takeFor(role: widget.role);
    _askedDay = asked?.day;
    _shown = asked?.pupil;

    _load().whenComplete(MobileHoldScope.hold(context));
    _tick();
    _pages.addListener(_onPage);
    MobileNavSheet.hidden.addListener(_onSheets);
    mobileTourChanges.addListener(_tourLater);
    WeekJumps.bookings.asked.addListener(_jump);
  }

  // 1 for a day of next week once it is open, else 0.
  int _weekOf(DateTime? day)
  {
    return day != null && startOfWeek(day).isAfter(_monday) && isNextWeekUnlocked(_now) ? 1 : 0;
  }

  // Already open: the week asked for, read again in full.
  void _jump()
  {
    final ({DateTime day, String? pupil})? asked = WeekJumps.bookings.takeFor(role: widget.role);

    if (asked == null || !mounted)
    {
      return;
    }

    if (_pages.hasClients)
    {
      _pages.animateToPage(_weekOf(asked.day), duration: _pageTurn, curve: Curves.easeInOutCubic);
    }

    setState(()
    {
      _shown = asked.pupil ?? _shown;
      _loading = true;
      _failed = false;
    });

    _load();
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_toured && mobileTourSettled(context))
    {
      _toured = true;
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    _clock?.cancel();
    MobileNavSheet.hidden.removeListener(_onSheets);
    mobileTourChanges.removeListener(_tourLater);
    WeekJumps.bookings.asked.removeListener(_jump);
    _pages.dispose();
    _sheetLink.dispose();

    super.dispose();
  }

  // Wakes on the minute so bands lock at their deadline; Monday means a new week's data.
  void _tick()
  {
    final DateTime now = widget.clock();

    _clock = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), ()
    {
      if (!mounted)
      {
        return;
      }

      final DateTime before = _monday;

      setState(() => _now = widget.clock());

      if (!isSameDate(before, _monday))
      {
        _load(quiet: true);
      }

      // A band closing at its deadline may show the first lock.
      _tourLater();

      _tick();
    });
  }

  // Also when a tour ends, so marks appearing together come one after the other.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  void _onPage()
  {
    final double page = _pages.page ?? 0;

    if ((page - page.round()).abs() < 0.001 && page.round() != _pageSeen)
    {
      _pageSeen = page.round();
      _tourLater();
      _markSeen();
    }
  }

  // The child's week on screen: the lessons booked by others in it are seen.
  void _markSeen()
  {
    final PersonItem? pupil = _pupil;

    if (pupil == null || _loading || _failed)
    {
      return;
    }

    final int week = _pages.hasClients ? (_pages.page ?? 0).round() : _pages.initialPage;

    unawaited(markBookingsSeen(pupil.fiscalCode, addDays(_monday, 7 * week)));
  }

  // A sheet closing, as the wizard after a save, may leave a new mark on the page.
  void _onSheets()
  {
    if (!MobileNavSheet.hidden.value)
    {
      _tourLater();
    }
  }

  // The main tour on the first visit, then a one-step tour for each mark it could not show.
  // A student reads their own; one who only looks, a shorter one.
  Future<void> _tourCheck() async
  {
    final PersonItem? pupil = _pupil;

    if (!mounted ||
        !_toured ||
        pupil == null ||
        _loading ||
        _failed ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pages.hasClients)
    {
      return;
    }

    final String taxCode = widget.user.taxCode;
    final int page = (_pages.page ?? 0).round();
    final List<List<MobileBookingDay>> weeks = [_week(0, pupil), if (isNextWeekUnlocked(_now)) _week(1, pupil)];
    final List<BookingTourPicks> picks = [for (final week in weeks) bookingTourPicks(week)];
    final Set<BookingMark> thisWeek = picks.first.marks;
    final Set<BookingMark> nextWeek = picks.length > 1 ? picks[1].marks : const {};

    void openLesson(int page)
    {
      final (int, int, int)? at = page < picks.length ? picks[page].lesson : null;

      if (mounted && at != null)
      {
        final MobileBookingDay day = weeks[page][at.$1];

        _openLesson(day, pupil, day.modes[at.$2].lessons[at.$3]);
      }
    }

    bool lessonEditable(int page) => page < picks.length && picks[page].lessonEditable;

    if (!await isMobileTourSeen(
      taxCode: taxCode,
      tour: bookingsMainTour(_pages, self: !_isParent, readOnly: _readOnly),
    ))
    {
      if (mounted && page == 0)
      {
        await startMobileTourOnce(
          taxCode: taxCode,
          tour: bookingsTour(
            pages: _pages,
            genders: [for (final child in _pupils) child.gender],
            shown: pupil.gender,
            thisWeek: thisWeek,
            nextWeek: nextWeek,
            sheet: _sheetLink,
            openLesson: openLesson,
            lessonEditable: lessonEditable,
            self: !_isParent,
            readOnly: _readOnly,
          ),
        );
      }

      return;
    }

    final Set<BookingMark> here = page == 0 ? thisWeek : nextWeek;

    for (final BookingMark mark in BookingMark.values)
    {
      final MobileTour tour = bookingsMarkTour(
        mark,
        page,
        sheet: _sheetLink,
        openLesson: () => openLesson(page),
        lessonEditable: lessonEditable(page),
      );

      if (here.contains(mark) && !await isMobileTourSeen(taxCode: taxCode, tour: tour))
      {
        if (mounted)
        {
          await startMobileTourOnce(taxCode: taxCode, tour: tour);
        }

        return;
      }
    }
  }

  // Own record or the children's: the full register is admin-only.
  Future<List<PersonItem>> _readPupils() async
  {
    final PersonItem reader = await _apiService.getPerson(widget.user.taxCode);

    if (!_isParent)
    {
      return [reader];
    }

    final List<PersonItem> children = await Future.wait([
      for (final child in reader.children ?? const []) _apiService.getPerson(child.fiscalCode),
    ]);

    return children.where((child) => child.roles.contains(_pupilRole)).toList()..sort(compareByName);
  }

  // Both weeks are always fetched so the Friday unlock needs no reload.
  Future<void> _load({bool quiet = false}) async
  {
    final int request = ++_request;

    final DateTime from = _monday;
    final DateTime to = addDays(from, 13);

    try
    {
      final List<dynamic> results = await Future.wait([
        _apiService.getPresences(dateFrom: from, dateTo: to),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
        _apiService.getTeachers(),
        _apiService.getMinistrySubjects(),
        _apiService.getAssociationSubjects(),
        _apiService.getServices(),
        _apiService.getStudyPrograms(),
        _readPupils(),
      ]);

      if (!mounted || request != _request)
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
        _teachers = results[3] as List<PersonItem>;
        _ministrySubjects = results[4] as List<MinistrySubjectItem>;
        _associationSubjects = results[5] as List<AssociationSubjectItem>;
        _services = results[6] as List<ServiceItem>;
        _studyPrograms = results[7] as List<StudyProgramItem>;
        _pupils = results[8] as List<PersonItem>;
        _loading = false;
        _failed = false;

        if (!_pupils.any((pupil) => pupil.fiscalCode == _shown))
        {
          _shown = _pupils.isEmpty ? null : _pupils.first.fiscalCode;
        }
      });

      _markSeen();
      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle prenotazioni');

      if (!mounted || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _loading = false;
        _failed = !quiet || _pupils.isEmpty;
      });
    }
  }

  List<MobileBookingDay> _week(int index, PersonItem pupil)
  {
    final BookingMovePlanner planner = _planner;
    final bool readOnly = _readOnly;

    return [
      for (final date in daysOfWeek(addDays(_monday, 7 * index)))
        bookingDay(
          date: date,
          now: _now,
          pupilTaxCode: pupil.fiscalCode,
          planner: planner,
          openingDays: _openingDays,
          ministrySubjects: _ministrySubjects,
          teachers: _teachers,
          readOnly: readOnly,
        ),
    ];
  }

  // With [from], the wizard turns that sheet, which closes once saved.
  Future<void> _openWizard(
    MobileBookingDay day,
    PersonItem pupil,
    String mode, {
    BuildContext? from,
    bool openOnSubjects = false,
    bool hoursOnly = false,
    TimeBucket? band,
    bool onlyFreeBands = false,
  }) async
  {
    final MobileBookingDraft draft = MobileBookingDraft(
      pupil: pupil,
      mode: mode,
      presences: _presences,
      openingDays: _openingDays,
      ministrySubjects: _ministrySubjects,
      isSelf: !_isParent,
      now: widget.clock(),
      day: day.date,
      existing: day.group?.first,
      hoursOnly: hoursOnly,
      subjectsOnly: openOnSubjects,
      band: band,
      onlyFreeBands: onlyFreeBands,
    );

    final bool done = await showMobileBookingWizard(
      context: from ?? context,
      draft: draft,
      catalogue: _catalogue,
      tourFor: _tourFor,
    );

    if (done && from != null && from.mounted)
    {
      closeMobileSheet(from);
    }

    if (done || draft.triedToSave)
    {
      await _load(quiet: true);
    }
  }

  Future<void> _openLesson(MobileBookingDay day, PersonItem pupil, MobileBookingLesson lesson)
  {
    final PresenceGroup? group = day.group;

    return showMobileLessonSheet(
      context: context,
      day: day,
      lesson: lesson,
      pupil: pupil,
      named: _isParent,
      movable: _planner.canMoveLesson(day.date, group, lesson.booking),
      tourFor: _tourFor,
      tourLink: _sheetLink,
      onAction: (sheet, action) async
      {
        if (group == null)
        {
          return;
        }

        switch (action)
        {
          case MobileEditLesson():
            await _editLesson(sheet, day, pupil, lesson);

          case MobileMoveLesson():
            await _move(sheet, day, pupil, BookingMove.one(group, lesson.slot, lesson.booking), title: lesson.named);

          case MobileDeleteLesson():
            final String mode = lesson.slot.mode;
            final TimeBucket? band = bucketFor(lesson.slot.startTime);

            // The last lesson of a band takes the band's hours with it.
            final bool last = group.requestsFor(mode, band: band).length == 1;

            final warning = lessonDeletionWarning(lesson.named, mode, last: last, divided: lesson.divided, band: band);

            await _confirmDeletion(
              sheet,
              day,
              warning.text,
              bold: warning.bold,
              delete: () => last
                  ? _clear(group, [mode], band: band, done: modeBookingDeleted(mode, band: band))
                  : _deleteLesson(lesson.booking),
            );

          default:
            break;
        }
      },
    );
  }

  Future<void> _openMode(MobileBookingDay day, PersonItem pupil, MobileBookingMode mode)
  {
    final PresenceGroup? group = day.group;

    return showMobileModeSheet(
      context: context,
      day: day,
      mode: mode,
      pupil: pupil,
      named: _isParent,
      moveAllRefusal: _planner.blockMoveRefusal(day.date, group, mode.mode, mode.band),
      tourFor: _tourFor,
      onAction: (sheet, action) async
      {
        if (group == null)
        {
          return;
        }

        switch (action)
        {
          case MobileEditHours():
            await _openWizard(day, pupil, mode.mode, from: sheet, hoursOnly: true, band: mode.band);

          case MobileMoveAll():
            await _move(
              sheet,
              day,
              pupil,
              BookingMove.all(group, mode.mode, mode.band),
              title: allLessonsTitle(mode.mode, band: mode.band),
            );

          case MobileDeleteMode():
            await _confirmDeletion(
              sheet,
              day,
              bookingDeletionWarning(day.date, pupil: _named(pupil), mode: mode.mode, band: mode.band),
              delete: () => _clear(group, [mode.mode], band: mode.band, done: kBookingDeleted),
            );

          case MobileDeleteDay():
            await _confirmDeletion(
              sheet,
              day,
              bookingDeletionWarning(day.date, pupil: _named(pupil)),
              delete: () => _clear(group, kBookingModes, done: kBookingDeleted),
            );

          default:
            break;
        }
      },
    );
  }

  Future<void> _confirmDeletion(
    BuildContext sheet,
    MobileBookingDay day,
    String warning, {
    String? bold,
    required Future<void> Function() delete,
  }) async
  {
    final bool confirmed = await showMobileConfirmSheet(
      context: sheet,
      eyebrow: formatAvailableDayLabel(day.date),
      title: 'Confermi?',
      message: TextSpan(
        children: [
          if (bold != null) TextSpan(text: bold, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          TextSpan(text: warning),
        ],
      ),
      confirmLabel: 'Elimina',
      confirmIcon: Icons.delete_outline_rounded,
    );

    if (!confirmed || !mounted)
    {
      return;
    }

    if (sheet.mounted)
    {
      closeMobileSheet(sheet);
    }

    await delete();
  }

  Future<void> _write(Future<void> Function() call, {required String done}) async
  {
    try
    {
      await call();

      if (mounted)
      {
        MobileNotice.show(context, done);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }

    await _load(quiet: true);
  }

  // Null [band] clears the modes' rows in every band; one write.
  Future<void> _clear(PresenceGroup group, Iterable<String> modes, {TimeBucket? band, required String done})
  {
    final DateTime now = widget.clock();

    return _write(
      () => _apiService.replaceLessonRequest(
        studentTaxCode: group.studentTaxCode,
        date: group.date,
        modes: [
          for (final mode in modes)
            modeReplacement(
              group,
              mode,
              dropping: band == null ? TimeBucket.values.toSet() : {band},
              closed: (other) => haveBookingsClosed(group.date, other, now),
            ),
        ],
      ),
      done: done,
    );
  }

  Future<void> _deleteLesson(BookingSummaryItem booking)
  {
    return _write(() => _apiService.deleteBooking(booking.id), done: kLessonDeleted);
  }

  Future<void> _editLesson(BuildContext sheet, MobileBookingDay day, PersonItem pupil, MobileBookingLesson lesson) async
  {
    final PresenceGroup? group = day.group;
    final held = _planner.whereItHangs(lesson.booking);

    if (group == null || held == null)
    {
      return;
    }

    final BookingSummaryItem booking = held.booking;
    final String mode = held.slot.mode;
    final TimeBucket? band = bucketFor(held.slot.startTime);
    final DateTime now = widget.clock();

    final MobileSubjectFlow flow = MobileSubjectFlow(
      from: SubjectRequestDraft.fromBooking(
        booking,
        ministrySubjectName: ministrySubjectName(_ministrySubjects, booking.ministrySubjectId, fallback: ''),
        band: band,
      ),
      mode: mode,
      pupil: pupil,
      isSelf: !_isParent,
      isEditing: true,
      ministrySubjects: _ministrySubjects,
      // The teacher catalogue comes already vetted by the server.
      offered: askableTeachers(_teachers, group.notPreferredTeacherTaxCodes),
      studyProgramId: currentStudyProgramId(pupil),
      // A booked lesson stays in its band: another band is reached by moving it.
      bands: [
        for (final offer in groupBandOffers(group, mode, skip: booking, isOpen: (other) => !haveBookingsClosed(day.date, other, now)))
          if (offer.band == band) offer,
      ],
      tourFor: _tourFor,
    );

    final bool saved = await showMobileSubjectSheet(
      context: sheet,
      flow: flow,
      onSave: (draft) async
      {
        if (!draft.isComplete)
        {
          MobileNotice.show(context, kLessonIncomplete, error: true);

          return false;
        }

        try
        {
          final PresenceItem? onto =
              draft.band == band ? null : group.slotsFor(mode, band: draft.band).firstOrNull;

          await _apiService.updateBooking(
            id: booking.id,
            subject: {...draft.toJson(), 'presence_id': ?onto?.id},
            expectedUpdatedAt: booking.updatedAt,
          );
        }
        catch (e)
        {
          if (mounted)
          {
            MobileNotice.show(context, readableApiError(e), error: true);
          }

          return false;
        }

        if (mounted)
        {
          MobileNotice.show(context, kLessonEdited);
        }

        return true;
      },
    );

    if (saved)
    {
      if (sheet.mounted)
      {
        closeMobileSheet(sheet);
      }

      await _load(quiet: true);
    }
  }

  Future<void> _move(
    BuildContext sheet,
    MobileBookingDay day,
    PersonItem pupil,
    BookingMove move, {
    required String title,
  }) async
  {
    final PresenceGroup? group = day.group;

    if (group == null)
    {
      return;
    }

    final MobileMoveChoice? choice = await showMobileMoveSheet(
      context: sheet,
      from: day.date,
      title: title,
      subtitle: _named(pupil),
      count: move.bookings.length,
      days: _planner.moveDays(day.date, pupil.fiscalCode, move),
      tourFor: _tourFor,
    );

    if (!mounted || choice == null)
    {
      return;
    }

    if (sheet.mounted)
    {
      closeMobileSheet(sheet);
    }

    bool moved = false;

    try
    {
      await _apiService.replaceLessonRequestDays(
        studentTaxCode: pupil.fiscalCode,
        days: _planner.moveRequest(
          from: group,
          move: move,
          day: choice.day.day,
          option: choice.option,
          hours: choice.hours,
        ),
      );
      moved = true;
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }

    if (moved && mounted)
    {
      MobileNotice.show(context, lessonsMoved(move.bookings.length));
    }

    await _load(quiet: true);
  }

  Widget _buildTitle({required bool tablet})
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            _title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 36 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.05,
              color: Colors.white,
            ),
          ),
        ),
        if (!_readOnly) ...[
          const SizedBox(width: 14),
          MobileTourTarget(
            id: kBookingsTourInfo,
            inflate: _tourInfoInflate,
            radius: _tourInfoRadius,
            child: MobileInfoButton(
              onTap: () => showMobileInfoSheet(context: context, title: _title, paragraphs: const [kBookingDeadlines]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeekHead(List<DateTime> days, {String? summary})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatDateSpan(days.first, days.last),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            color: Colors.white,
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: 3),
          Text(
            summary,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeek(int index, {required bool tablet})
  {
    final List<DateTime> dates = daysOfWeek(addDays(_monday, 7 * index));

    if (index == 1 && !isNextWeekUnlocked(_now))
    {
      return _lit(
        index,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWeekHead(dates),
            const SizedBox(height: 18),
            const _LockedWeek(),
          ],
        ),
      );
    }

    if (_loading)
    {
      return const MobileWaiting();
    }

    final PersonItem? pupil = _pupil;

    if (_failed || pupil == null)
    {
      return _Status(_failed ? kBookingsLoadFailed : kNoPupils);
    }

    final List<MobileBookingDay> days = _week(index, pupil);
    final int booked = days.where((day) => !day.isEmpty).length;
    final bool thisWeek = index == 0;

    final String summary = _isParent
        ? pupilBookedDays(pupil.firstName, booked, thisWeek: thisWeek)
        : _readOnly
            ? bookedForYouDays(booked, thisWeek: thisWeek)
            : ownBookedDays(booked, thisWeek: thisWeek);

    // A tour lights the first of each mark, and a line of each mode.
    final BookingTourPicks picks = bookingTourPicks(days);

    String? mark(BookingMark mark, (int, int)? pick, int day, int mode) =>
        pick == (day, mode) ? bookingsTourMark(mark, index) : null;

    Map<int, MobileBookingModeTour> modesOf(int day) => {
          for (var j = 0; j < days[day].modes.length; j++)
            j: (
              lock: mark(BookingMark.lock, picks.lock, day, j),
              hours: picks.hours.contains((day, j)) ? bookingsTourMark(BookingMark.hours, index) : null,
              edit: mark(BookingMark.edit, picks.edit, day, j),
              lesson: switch (picks.lesson)
              {
                (final int at, final int mode, final int lesson) when at == day && mode == j =>
                  (lesson, bookingsTourMark(BookingMark.lesson, index)),
                _ => null,
              },
              addLesson: mark(BookingMark.addLesson, picks.addLesson, day, j),
            ),
        };

    return _lit(
      index,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWeekHead(dates, summary: summary),
          const SizedBox(height: 16),
          for (final (i, day) in days.indexed) ...[
            if (i > 0) const SizedBox(height: _cardGap),
            MobileBookingDayCard(
              key: ValueKey(day.date),
              day: day,
              tablet: tablet,
              onOpenLesson: (lesson) => _openLesson(day, pupil, lesson),
              onModeActions: (mode) => _openMode(day, pupil, mode),
              onAdd: (mode) => _openWizard(day, pupil, mode, onlyFreeBands: true),
              onAddLesson: (mode) => _openWizard(day, pupil, mode.mode, openOnSubjects: true, band: mode.band),
              tourAdds: picks.add == i ? bookingsTourMark(BookingMark.add, index) : null,
              tourModes: modesOf(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lit(int index, Widget week)
  {
    return MobileTourTarget(
      id: bookingsTourWeek(index),
      inflate: kBookingsTourWeekInflate,
      radius: kBookingsTourWeekRadius,
      child: week,
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double left, required double right, required double bottom})
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: () => _load(quiet: true),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(left, _topRoom, right, bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileLoadSwitcher(child: child),
              const MobileTourRunway(),
            ],
          ),
        ),
      ),
    );
  }

  // Another child's weeks may show marks never explained.
  void _show(PersonItem pupil)
  {
    setState(() => _shown = pupil.fiscalCode);
    _markSeen();
    _tourLater();
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final Size size = MediaQuery.sizeOf(context);
    final bool lying = tablet && size.width > size.height;

    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final PersonItem? pupil = _failed ? null : _pupil;
    final bool several = pupil != null && _pupils.length > 1;
    final bool rail = lying && several;

    // Phones show the child as a chip; tablets keep the tiles.
    final bool tiles = tablet && several && !rail;
    final bool chip = !tablet && several;

    final int weekCount = _weekCount;
    final Widget? strip = weekCount > 1
        ? MobilePageStrip(
            labels: _weeks,
            controller: _pages,
            tourTargets: [bookingsTourTab(0), bookingsTourTab(1)],
          )
        : null;

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: _buildTitle(tablet: tablet),
        ),
        if (tiles)
          Padding(
            padding: const EdgeInsets.only(top: _tilesGap),
            child: MobileChildTiles(
              children: _pupils,
              shown: pupil,
              onShow: _show,
              margin: margin,
              tourTarget: kBookingsTourChildren,
            ),
          ),
        if (chip)
          Padding(
            padding: const EdgeInsets.only(top: _chipsGap),
            child: MobileFilterChips(
              margin: margin,
              chips: [
                MobileTourTarget(
                  id: kBookingsTourChildren,
                  inflate: _tourChipInflate,
                  radius: _tourChipRadius,
                  child: MobileChildChip(children: _pupils, shown: pupil, onShow: _show, eyebrow: _title),
                ),
              ],
            ),
          ),
        if (!rail && strip != null)
          Padding(
            padding: EdgeInsets.fromLTRB(margin, tiles ? _tilesGap : (chip ? _chipsStripGap : _stripGap), margin, 0),
            child: strip,
          )
        else
          const SizedBox(height: _stripGap),
      ],
    );

    final Widget weeks = PageView(
      controller: _pages,
      children: [
        for (var i = 0; i < weekCount; i++)
          _scrollable(
            _buildWeek(i, tablet: tablet),
            left: margin,
            right: margin,
            bottom: bottom,
          ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        // The column lies over the cards' margin so their shadows are not cut where the pages end.
        body: rail
            ? Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: MobileChildRail.width + MobileChildRail.gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (strip != null) Padding(padding: EdgeInsets.symmetric(horizontal: margin), child: strip),
                        Expanded(child: MobileRailClip(pages: _pages, margin: margin, child: weeks)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: margin,
                    top: 0,
                    bottom: 0,
                    width: MobileChildRail.width,
                    child: MobileChildRail(
                      children: _pupils,
                      shown: pupil,
                      onShow: _show,
                      bottom: bottom,
                      tourTarget: kBookingsTourChildren,
                    ),
                  ),
                ],
              )
            : weeks,
      ),
    );
  }
}

class _LockedWeek extends StatelessWidget
{
  const _LockedWeek();

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.trialGoldSurface,
              border: Border.all(color: AppTheme.trialGold.withValues(alpha: 0.6), width: 1.5),
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 26, color: AppTheme.modifiedAccent),
          ),
          const SizedBox(height: 14),
          Text(
            kNextWeekUnlockNotice,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: AppTheme.trialInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget
{
  final String text;

  const _Status(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
