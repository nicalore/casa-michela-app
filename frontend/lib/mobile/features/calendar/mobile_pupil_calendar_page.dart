import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/ministry_subject_item.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/tabs/opening_hours/calendar_bounds.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/calendar/utils/calendar_strings.dart';
import '../../../features/calendar/utils/day_marks_loader.dart';
import '../../../features/calendar/utils/pupil_band_presence.dart';
import '../../../features/calendar/utils/viewable_days.dart';
import '../../../features/lessons/models/calendar_day.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/calendar_jump.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/notifications/calendar_seen.dart';
import '../../../features/people/models/person_face.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_choice_sheet.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_filter_chip.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_month_picker.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../children/widgets/mobile_child_tiles.dart';
import 'mobile_calendar_tour.dart';
import 'mobile_pupil_calendar_day.dart';
import 'widgets/mobile_calendar_notice.dart';
import 'widgets/mobile_calendar_timeline.dart';
import 'widgets/mobile_lesson_card.dart';
import 'widgets/mobile_lesson_list.dart';
import 'widgets/mobile_lesson_sheet.dart';
import 'widgets/mobile_presence_card.dart';

const String _title = 'Calendario';

// Same "seen" flag for every role: the sentence is the same.

const String _parentRole = 'PARENT';
const String _pupilRole = 'Studente';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 12;
const double _tilesGap = 6;
const double _chipsGap = 12;
const double _stripGap = 14;
const double _cardGap = 14;

const double _pupilGap = 26;
const double _columnGap = 22;

// Children in a column each fit up to this many; past it, one at a time.
const int _phoneTogether = 2;
const int _tabletTogether = 3;

const double _laneNameWidth = 120;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

const double _topRoom = 16;

// Fraction down the visible area where the present lands on open.
const double _nowAlignment = 0.4;

const Duration _pageTurn = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

const EdgeInsets _tourBandsInflate = EdgeInsets.fromLTRB(10, 2, 10, 0);
const double _tourBandsRadius = 22;
const EdgeInsets _tourDayInflate = EdgeInsets.all(5);
const double _tourDayRadius = 30;
const EdgeInsets _tourChipInflate = EdgeInsets.all(5);
const double _tourChipRadius = 21;
const EdgeInsets _tourCardInflate = EdgeInsets.all(5);
const double _tourCardRadius = 27;
const double _tourHeadRadius = 23;

// Never past today: only published days are shown.
class MobilePupilCalendarPage extends StatefulWidget
{
  final MeResponse user;
  final String role;

  final DateTime Function() clock;

  const MobilePupilCalendarPage({super.key, required this.user, required this.role, this.clock = romeNow});

  @override
  State<MobilePupilCalendarPage> createState() => _MobilePupilCalendarPageState();
}

class _MobilePupilCalendarPageState extends State<MobilePupilCalendarPage>
{
  final ApiService _apiService = ApiService();

  // Only the timelines listen: the present moves without rebuilding the page.
  late final ValueNotifier<DateTime> _clock = ValueNotifier(widget.clock());

  Timer? _timer;

  // Opened from a notification: its day and band instead of the clock's.
  late final CalendarJump? _openedFor = CalendarJumps.role.take(role: widget.role);

  late final PageController _pageController = PageController(initialPage: (_openedFor?.band ?? _bandNow).index);

  late DateTime _day = _openedFor?.day ?? _today;

  // Today, or tomorrow once one of its bands is published.
  late DateTime _lastDay = _today;

  List<CalendarPublicationItem> _publications = const [];

  CalendarLayout _layout = CalendarLayout.byHour;

  bool _loading = true;
  bool _failed = false;

  MobilePupilCalendarDay? _data;

  List<MinistrySubjectItem> _ministrySubjects = const [];

  List<PersonItem> _pupils = const [];

  // By tax code, so a refresh that reorders the children keeps the one shown.
  String? _shown;

  // A notification's band: once its day is read, the child shown is one with lessons in it.
  late TimeBucket? _askedBand = _openedFor?.band;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  bool _revealed = false;

  // Drops taps while a lesson's teacher is being fetched.
  bool _opening = false;

  // Set once the page is in place; then every load, band change and closed sheet looks for a tour.
  bool _toured = false;
  int? _pageSeen;

  // Not disposed: a sheet closing after the page still tells it.
  final LessonSheetTourLink _sheetLink = LessonSheetTourLink();

  // The child of the lesson whose sheet is up.
  PersonItem? _sheetPupil;

  // The layouts' sheet up and still, and how to close it.
  final ValueNotifier<bool> _layoutsUp = ValueNotifier(false);
  VoidCallback? _closeLayouts;

  final GlobalKey _nowKey = GlobalKey();
  final GlobalKey<NestedScrollViewState> _nestedKey = GlobalKey();

  bool get _isParent => widget.role == _parentRole;

  DateTime get _today
  {
    final DateTime now = _clock.value;

    return DateTime(now.year, now.month, now.day);
  }

  TimeBucket get _bandNow => bucketFor(TimeOfDay.fromDateTime(_clock.value)) ?? TimeBucket.afternoon;

  bool get _isToday => isSameDate(_day, _today);

  bool get _isFirstDay => !_day.isAfter(oldestKeptDay(_today));

  bool _together({required bool tablet}) => _pupils.length <= (tablet ? _tabletTogether : _phoneTogether);

  List<PersonItem> _shownPupils({required bool tablet})
  {
    if (_together(tablet: tablet))
    {
      return _pupils;
    }

    return [_pupils.firstWhere((pupil) => pupil.fiscalCode == _shown, orElse: () => _pupils.first)];
  }

  @override
  void initState()
  {
    super.initState();

    _tick();
    _load().whenComplete(MobileHoldScope.hold(context));

    _pageController.addListener(_onPage);
    MobileNavSheet.hidden.addListener(_onSheets);
    MobileNavSheet.openness.addListener(_onSheets);
    mobileTourChanges.addListener(_tourLater);
    _sheetLink.addListener(_onLessonSheet);
    CalendarJumps.role.asked.addListener(_jump);
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
    _timer?.cancel();
    CalendarJumps.role.asked.removeListener(_jump);
    _sheetLink.removeListener(_onLessonSheet);
    mobileTourChanges.removeListener(_tourLater);
    MobileNavSheet.openness.removeListener(_onSheets);
    MobileNavSheet.hidden.removeListener(_onSheets);
    _clock.dispose();
    _pageController.dispose();
    _layoutsUp.dispose();

    super.dispose();
  }

  // Asks for the frame too: the page may be still.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_)
      {
        _tourCheck();
        _noteSeen();
      })
      ..scheduleFrame();
  }

  // Already open: turned to the day and band a notification asks for.
  void _jump()
  {
    final CalendarJump? jump = CalendarJumps.role.take(role: widget.role);

    if (jump == null || !mounted)
    {
      return;
    }

    if (_pageController.hasClients)
    {
      _pageController.animateToPage(jump.band.index, duration: _pageTurn, curve: Curves.easeInOutCubic);
    }

    _askedBand = jump.band;
    _reload(jump.day);
  }

  // A published band settled on screen, with no menu or sheet over it, takes its notification away.
  void _noteSeen()
  {
    if (!mounted ||
        !_toured ||
        _loading ||
        _failed ||
        MobileNavSheet.hidden.value ||
        MobileNavSheet.openness.value > 0 ||
        !_pageController.hasClients)
    {
      return;
    }

    final double page = _pageController.page ?? _pageController.initialPage.toDouble();
    final TimeBucket band = TimeBucket.values[page.round()];

    if ((page - page.round()).abs() >= _settled ||
        !_publications.any((row) => isSameDate(row.date, _day) && row.band == band))
    {
      return;
    }

    unawaited(markCalendarSeen(_day, band));
  }

  void _onPage()
  {
    final double page = _pageController.page ?? 0;

    if ((page - page.round()).abs() < _settled && page.round() != _pageSeen)
    {
      _pageSeen = page.round();
      _tourLater();
    }
  }

  void _onSheets()
  {
    if (!MobileNavSheet.hidden.value)
    {
      _tourLater();
    }
  }

  // Earliest lesson of the first shown child having one, in a published band; a tour lights it.
  (LessonItem, PersonItem)? _litLessonIn(MobilePupilCalendarDay data, TimeBucket band, List<PersonItem> pupils)
  {
    final MobilePupilBand shown = data.bandOf(band);

    if (data.closed || shown.opening == null || !shown.settled)
    {
      return null;
    }

    for (final PersonItem pupil in pupils)
    {
      final List<LessonItem> lessons = shown.of(pupil.fiscalCode).lessons;

      if (lessons.isNotEmpty)
      {
        return (lessons.reduce((a, b) => b.startMinutes < a.startMinutes ? b : a), pupil);
      }
    }

    return null;
  }

  // The band in sight if it shows a lesson of the children shown, else the first that does.
  TimeBucket? _litBand(MobilePupilCalendarDay data, List<PersonItem> pupils, int page)
  {
    bool lit(TimeBucket band) => _litLessonIn(data, band, pupils) != null;

    final TimeBucket here = TimeBucket.values[page];

    return lit(here) ? here : TimeBucket.values.where(lit).firstOrNull;
  }

  // Bands, child picker and day on the first visit; a published band's parts when one first shows.
  Future<void> _tourCheck() async
  {
    final MobilePupilCalendarDay? data = _data;

    if (!mounted ||
        !_toured ||
        _loading ||
        _failed ||
        data == null ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pageController.hasClients)
    {
      return;
    }

    final double page = _pageController.page ?? _pageController.initialPage.toDouble();

    if ((page - page.round()).abs() >= _settled)
    {
      return;
    }

    final String taxCode = widget.user.taxCode;
    final bool main = !await isPupilCalendarMainTourSeen(taxCode, self: !_isParent);
    final bool published = !await isPupilCalendarBandTourSeen(taxCode, self: !_isParent);

    if (!mounted)
    {
      return;
    }

    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final List<PersonItem> pupils = _shownPupils(tablet: tablet);
    final TimeBucket? band = published ? _litBand(data, pupils, page.round()) : null;

    if (!main && band == null)
    {
      return;
    }

    // Shown where the lesson is.
    if (band != null && band.index != page.round())
    {
      _pageController.animateToPage(band.index, duration: _pageTurn, curve: Curves.easeInOutCubic);

      return;
    }

    final List<PupilBandPresence> presences = [
      if (band != null)
        for (final PersonItem pupil in pupils) data.bandOf(band).of(pupil.fiscalCode),
    ];
    final (LessonItem, PersonItem)? lit = band == null ? null : _litLessonIn(data, band, pupils);
    final Set<PupilLessonSheetMark> sheetMarks = band == null ? const {} : await unseenPupilLessonSheetMarks(taxCode);

    if (!mounted)
    {
      return;
    }

    await startMobileTourOnce(
      taxCode: taxCode,
      tour: pupilCalendarTour(
        main: main,
        genders: _together(tablet: tablet) ? null : [for (final PersonItem pupil in _pupils) pupil.gender],
        band: band,
        shownGenders: [for (final PersonItem pupil in pupils) pupil.gender],
        online: presences.isNotEmpty &&
            presences.every(
              (presence) => presence.isEmpty || presence.byMode.every((span) => span.mode != kPresenceMode),
            ),
        lessonGender: lit?.$2.gender,
        layouts: _layoutsUp,
        openLayouts: _pickLayout,
        closeLayouts: () => _closeLayouts?.call(),
        sheetMarks: sheetMarks,
        sheet: _sheetLink,
        self: !_isParent,
      ),
    );
  }

  // A lesson's sheet up outside a tour: its parts never seen, the first time they show.
  void _onLessonSheet()
  {
    if (!_sheetLink.open)
    {
      return;
    }

    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _sheetTourCheck())
      ..scheduleFrame();
  }

  Future<void> _sheetTourCheck() async
  {
    if (!mounted || isMobileTourShown || !_sheetLink.open)
    {
      return;
    }

    final Set<PupilLessonSheetMark> marks = await unseenPupilLessonSheetMarks(widget.user.taxCode);

    if (!mounted || marks.isEmpty || isMobileTourShown || !_sheetLink.open)
    {
      return;
    }

    final MobileTour tour = pupilCalendarTour(
      main: false,
      genders: null,
      band: null,
      shownGenders: const [],
      online: false,
      lessonGender: _sheetPupil?.gender,
      layouts: _layoutsUp,
      openLayouts: _pickLayout,
      closeLayouts: () => _closeLayouts?.call(),
      sheetMarks: marks,
      sheet: _sheetLink,
      opened: true,
      self: !_isParent,
    );

    if (tour.steps.any((step) => step.isPresent))
    {
      await startMobileTourOnce(taxCode: widget.user.taxCode, tour: tour);
    }
  }

  // Wakes on the minute, not every 60 s from whenever the page opened.
  void _tick()
  {
    final DateTime now = widget.clock();
    final bool newDay = !isSameDate(now, _clock.value);

    _clock.value = now;

    if (newDay && mounted)
    {
      setState(() {});
    }

    _timer?.cancel();
    _timer = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), _tick);
  }

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

  // Shown child if they have lessons in the band, else the first who has, else the first booker.
  String? _childWithLessonsIn(MobilePupilBand band)
  {
    final List<String> codes = [
      ?_shown,
      for (final PersonItem pupil in _pupils) pupil.fiscalCode,
    ];

    return codes.where((code) => band.of(code).lessons.isNotEmpty).firstOrNull ??
        codes.where((code) => !band.of(code).isEmpty).firstOrNull;
  }

  Future<void> _load({bool quiet = false}) async
  {
    final int request = ++_request;
    final DateTime day = _day;
    final bool readPupils = quiet || _pupils.isEmpty;

    try
    {
      final results = await Future.wait([
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: day, dateTo: day, mode: kOnlineMode),
        _apiService.getCalendarPublications(dateFrom: day, dateTo: day),
        _apiService.getLessons(dateFrom: day, dateTo: day),
        _apiService.getPresences(dateFrom: day, dateTo: day),
        readPupils ? _readPupils() : Future.value(_pupils),
        _apiService.getUnbookedBands(dateFrom: day, dateTo: day),
        _apiService.getCalendarPublications(dateFrom: addDays(_today, 1), dateTo: addDays(_today, 1)),
        if (_ministrySubjects.isEmpty) _apiService.getMinistrySubjects(),
      ]);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        if (results.length > 8)
        {
          _ministrySubjects = results[8] as List<MinistrySubjectItem>;
        }

        _publications = results[2] as List<CalendarPublicationItem>;
        _lastDay = lastViewableDay(_today, results[7] as List<CalendarPublicationItem>);

        _pupils = results[5] as List<PersonItem>;

        if (!_pupils.any((pupil) => pupil.fiscalCode == _shown))
        {
          _shown = _pupils.firstOrNull?.fiscalCode;
        }

        _data = pupilCalendarDayFrom(
          day: day,
          openingDays: [
            ...results[0] as List<OpeningDayItem>,
            ...results[1] as List<OpeningDayItem>,
          ],
          publications: results[2] as List<CalendarPublicationItem>,
          lessons: results[3] as List<LessonItem>,
          presences: results[4] as List<PresenceItem>,
          unbooked: results[6] as List<(DateTime, TimeBucket)>,
          pupilTaxCodes: [for (final pupil in _pupils) pupil.fiscalCode],
        );

        final TimeBucket? asked = _askedBand;

        if (asked != null)
        {
          _askedBand = null;
          _shown = _childWithLessonsIn(_data!.bandOf(asked)) ?? _shown;
        }

        _loading = false;
        _failed = false;
      });

      if (!_revealed)
      {
        _revealed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealNow());
      }

      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento del calendario');

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _loading = false;
        _failed = !quiet || _failed;
      });
    }
  }

  // By hand: ensureVisible also scrolls the outer view, whose jump resets the page.
  void _revealNow()
  {
    final BuildContext? target = _nowKey.currentContext;
    final NestedScrollViewState? nested = _nestedKey.currentState;

    if (!mounted || target == null || nested == null)
    {
      return;
    }

    final RenderBox box = target.findRenderObject()! as RenderBox;
    final double top = box.localToGlobal(Offset.zero).dy;

    final double visibleTop = MediaQuery.paddingOf(context).top;
    final double visibleBottom = MediaQuery.sizeOf(context).height - MobileNavSheet.collapsedHeightFor(context);

    if (top + box.size.height <= visibleBottom - _handleClearance)
    {
      return;
    }

    final double wanted = visibleTop + (visibleBottom - visibleTop) * _nowAlignment - box.size.height / 2;

    // Scroll the header away first, then the page.
    final ScrollPosition outer = nested.outerController.position;
    final ScrollPosition inner = Scrollable.of(target).position;
    final double scrolled = outer.pixels + inner.pixels + top - wanted;

    if (scrolled <= outer.maxScrollExtent)
    {
      outer.jumpTo(scrolled);
    }
    else
    {
      inner.jumpTo(math.min(scrolled - outer.maxScrollExtent, inner.maxScrollExtent));
    }
  }

  void _goToDay(DateTime day)
  {
    DateTime target = DateTime(day.year, day.month, day.day);

    if (target.isAfter(_lastDay))
    {
      target = _lastDay;
    }

    if (target.isBefore(oldestKeptDay(_today)))
    {
      target = oldestKeptDay(_today);
    }

    _showDay(target);
  }

  // The same day read again quietly, another one in full.
  void _showDay(DateTime target)
  {
    if (isSameDate(target, _day))
    {
      _load(quiet: true);

      return;
    }

    _reload(target);
  }

  // Also what a notification's tap does: nothing on screen from before its news.
  void _reload(DateTime target)
  {
    setState(()
    {
      _day = target;
      _loading = true;
      _failed = false;
    });

    _load();
  }

  Future<void> _pickLayout() async
  {
    final MobileChoice<CalendarLayout>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: _title,
      title: 'Disposizione',
      choices: [for (final layout in CalendarLayout.values) MobileChoice(value: layout, label: layout.label)],
      value: _layout,
      tourChoices: kPupilCalendarTourLayouts,
      onShown: (close)
      {
        _closeLayouts = close;
        _layoutsUp.value = true;
      },
    );

    _closeLayouts = null;

    if (!mounted)
    {
      return;
    }

    _layoutsUp.value = false;

    if (picked != null)
    {
      setState(() => _layout = picked.value);
    }
  }

  Future<void> _pickDay() async
  {
    final DateTime? picked = await showMobileMonthPicker(
      context: context,
      selected: _day,
      today: _today,
      first: oldestKeptDay(_today),
      last: _lastDay,
      loadMarks: (from, to) => loadDayMarks(from, to, published: true),
      tourDays: kCalendarTourPickerDays,
      onShown: () => startMobileTourOnce(taxCode: widget.user.taxCode, tour: calendarPickerTour()),
    );

    if (picked != null && mounted)
    {
      _goToDay(picked);
    }
  }

  Future<void> _openLesson(LessonItem lesson, PersonItem pupil) async
  {
    if (_opening)
    {
      return;
    }

    _opening = true;

    // Read before the sheet opens, so it rises at its full height.
    PersonItem? teacher;

    try
    {
      teacher = await _apiService.getPerson(lesson.teacherTaxCode);
    }
    catch (_) {}

    _opening = false;

    if (!mounted)
    {
      return;
    }

    _sheetPupil = pupil;

    await showMobilePupilLessonSheet(
      context: context,
      lesson: lesson,
      ministrySubjects: _ministrySubjects,
      teacher: teacher,
      pupilName: _isParent ? pupil.firstName : null,
      tourLink: _sheetLink,
    );
  }

  List<MobileCalendarEntry> _entriesOf(PupilBandPresence presence, PersonItem pupil, _BandTour tour)
  {
    return [
      for (final lesson in presence.lessons)
        MobileCalendarEntry.pupilLesson(
          lesson,
          _ministrySubjects,
          onTap: () => _openLesson(lesson, pupil),
          tourId: identical(lesson, tour.lesson) ? tour.lessonId : null,
        ),
    ];
  }

  MobileCalendarColumn _columnOf(PupilBandPresence presence, PersonItem pupil, _BandTour tour, {Widget? head})
  {
    return MobileCalendarColumn(
      entries: _entriesOf(presence, pupil, tour),
      head: head,
    );
  }

  String _withYear(String label) => _day.year == _today.year ? label : '$label ${_day.year}';

  String get _dayLabel => _withYear(formatWeekdayColumnLabel(_day));

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
      ],
    );
  }

  Widget _buildBand(TimeBucket band, {required bool tablet, required bool lying})
  {
    if (_loading)
    {
      return const MobileWaiting();
    }

    final MobilePupilCalendarDay? data = _data;

    if (_failed || data == null)
    {
      return const _Status(kCalendarLoadFailed);
    }

    if (data.closed)
    {
      return MobileCalendarNotice(
        icon: Icons.event_busy_rounded,
        title: kAssociationClosedTitle,
        message: data.closureNote,
      );
    }

    final MobilePupilBand shownBand = data.bandOf(band);

    if (shownBand.opening == null)
    {
      return const MobileCalendarNotice(icon: Icons.event_busy_rounded, title: kAssociationClosedTitle);
    }

    if (!shownBand.settled)
    {
      return MobileCalendarNotice(
        icon: Icons.pending_actions_rounded,
        title: kCalendarUnpublishedTitle,
        message: unpublishedBandMessage(band),
      );
    }

    final List<PersonItem> pupils = _shownPupils(tablet: tablet);
    final List<PupilBandPresence> presences = [for (final pupil in pupils) shownBand.of(pupil.fiscalCode)];
    final (int, int)? window = shownBand.windowFor(presences);
    final String nothing = pupilNothingTitle(inBuilding: shownBand.inBuilding);

    if (presences.every((presence) => presence.isEmpty) || window == null)
    {
      return MobileCalendarNotice(
        icon: Icons.free_cancellation_rounded,
        title: kCalendarUnavailableTitle,
        message: kNoLessonsRequested,
      );
    }

    final bool pastDay = _day.isBefore(_today);
    final _BandTour tour = (
      cards: pupilCalendarTourCards(band),
      lesson: _litLessonIn(data, band, pupils)?.$1,
      lessonId: calendarTourLesson(band),
    );

    return ValueListenableBuilder<DateTime>(
      valueListenable: _clock,
      builder: (context, now, _)
      {
        final bool today = isSameDate(now, _day);
        final int? nowMinutes = today ? now.hour * 60 + now.minute : null;

        // The GlobalKey may sit on one present only: the running band's.
        final Key? nowKey = today && band == _bandNow ? _nowKey : null;

        final _Present present = (nowMinutes: nowMinutes, pastDay: pastDay, nowKey: nowKey);

        if (pupils.length == 1)
        {
          return _buildOne(pupils.single, presences.single, window, present, tour, tablet: tablet, lying: lying);
        }

        return _buildTogether(pupils, presences, window, nothing, present, tour, tablet: tablet, lying: lying);
      },
    );
  }

  Widget _buildOne(
    PersonItem pupil,
    PupilBandPresence presence,
    (int, int) window,
    _Present present,
    _BandTour tour, {
    required bool tablet,
    required bool lying,
  })
  {
    final Widget lessons;

    if (_layout == CalendarLayout.byLesson)
    {
      lessons = MobileLessonList(
        entries: _entriesOf(presence, pupil, tour),
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        tablet: tablet,
        nowKey: present.nowKey,
      );
    }
    else if (lying)
    {
      lessons = MobileCalendarTrack(
        window: window,
        lanes: [_columnOf(presence, pupil, tour)],
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        nowKey: present.nowKey,
      );
    }
    else
    {
      lessons = MobileCalendarTimeline(
        window: window,
        columns: [_columnOf(presence, pupil, tour)],
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        tablet: tablet,
        nowKey: present.nowKey,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileTourTarget(
          id: tour.cards,
          inflate: _tourCardInflate,
          radius: _tourCardRadius,
          child: MobilePresenceCard(presence: presence, tablet: tablet, stretched: lying),
        ),
        const SizedBox(height: _cardGap),
        lessons,
      ],
    );
  }

  Widget _buildTogether(
    List<PersonItem> pupils,
    List<PupilBandPresence> presences,
    (int, int) window,
    String nothing,
    _Present present,
    _BandTour tour, {
    required bool tablet,
    required bool lying,
  })
  {
    Widget headOf(int i)
    {
      return MobileTourTarget(
        id: tour.cards,
        inflate: _tourCardInflate,
        radius: _tourHeadRadius,
        child: MobilePupilHead(
          name: pupils[i].firstName,
          presence: presences[i],
          nothingTitle: nothing,
          tablet: tablet,
        ),
      );
    }

    Widget heads()
    {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < pupils.length; i++) ...[
              if (i > 0) const SizedBox(width: _columnGap),
              Expanded(child: headOf(i)),
            ],
          ],
        ),
      );
    }

    if (_layout == CalendarLayout.byHour && lying)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heads(),
          const SizedBox(height: _cardGap),
          MobileCalendarTrack(
            window: window,
            lanes: [
              for (final (i, pupil) in pupils.indexed)
                _columnOf(presences[i], pupil, tour, head: MobilePupilLaneName(name: pupil.firstName)),
            ],
            nowMinutes: present.nowMinutes,
            pastDay: present.pastDay,
            nowKey: present.nowKey,
            headWidth: _laneNameWidth,
          ),
        ],
      );
    }

    if (_layout == CalendarLayout.byHour)
    {
      final List<MobileCalendarColumn> columns = [
        for (final (i, pupil) in pupils.indexed) _columnOf(presences[i], pupil, tour, head: headOf(i)),
      ];

      return MobileCalendarTimeline(
        window: window,
        columns: columns,
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        tablet: tablet,
        nowKey: present.nowKey,
      );
    }

    final int keyed = [
      for (final (i, pupil) in pupils.indexed)
        MobileLessonList.showsNow(_entriesOf(presences[i], pupil, tour), present.nowMinutes, pastDay: present.pastDay),
    ].indexOf(true);

    Widget listOf(int i)
    {
      return MobileLessonList(
        entries: _entriesOf(presences[i], pupils[i], tour),
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        tablet: tablet,
        nowKey: i == keyed ? present.nowKey : null,
      );
    }

    if (tablet)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heads(),
          const SizedBox(height: _cardGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, _) in pupils.indexed) ...[
                if (i > 0) const SizedBox(width: _columnGap),
                Expanded(child: presences[i].isEmpty ? const SizedBox.shrink() : listOf(i)),
              ],
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, pupil) in pupils.indexed) ...[
          if (i > 0) const SizedBox(height: _pupilGap),
          MobileTourTarget(
            id: tour.cards,
            inflate: _tourCardInflate,
            radius: _tourHeadRadius,
            child: MobilePupilLine(
              name: pupil.firstName,
              presence: presences[i],
              nothingTitle: nothing,
              tablet: tablet,
            ),
          ),
          if (!presences[i].isEmpty) ...[
            const SizedBox(height: 12),
            listOf(i),
          ],
        ],
      ],
    );
  }

  void _show(PersonItem pupil) => setState(() => _shown = pupil.fiscalCode);

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final bool lying = tablet && MediaQuery.orientationOf(context) == Orientation.landscape;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final bool closed = !_loading && !_failed && (_data?.closed ?? false);

    // Ignores loading so the bands keep their last state while the next day loads.
    final bool folded = !_failed && (_data?.closed ?? false);

    final PersonItem? shown = _together(tablet: tablet) ? null : _shownPupils(tablet: tablet).single;

    final bool rail = lying && shown != null;

    // Phones show the child as a chip beside the layout's; tablets keep the tiles.
    final bool tiles = tablet && shown != null && !rail;

    final Widget controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: MobileTourTarget(
            id: kPupilCalendarTourDay,
            inflate: _tourDayInflate,
            radius: _tourDayRadius,
            child: MobileDateCapsule(
              label: _dayLabel,
              widestLabel: _withYear(kWidestDayLabel),
              current: _isToday,
              tablet: tablet,
              onBack: !_isFirstDay && !_loading ? () => _goToDay(addDays(_day, -1)) : null,
              onForward: _day.isBefore(_lastDay) && !_loading ? () => _goToDay(addDays(_day, 1)) : null,
              onPick: _pickDay,
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: folded ? 0 : 1),
          duration: mobileRiseDurationOf(context),
          curve: Curves.easeOutCubic,
          builder: (context, shown, controls) => ClipRect(
            clipBehavior: shown < 1 ? Clip.hardEdge : Clip.none,
            child: Align(alignment: Alignment.topCenter, heightFactor: shown, child: controls),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: _chipsGap),
              MobileFilterChips(
                margin: margin,
                chips: [
                  if (shown != null && !tablet)
                    MobileTourTarget(
                      id: kPupilCalendarTourChildren,
                      inflate: _tourChipInflate,
                      radius: _tourChipRadius,
                      child: MobileChildChip(children: _pupils, shown: shown, onShow: _show, eyebrow: _title),
                    ),
                  // A way of showing the day, not a filter: the chip never lights up.
                  MobileTourTarget(
                    id: kPupilCalendarTourLayout,
                    inflate: _tourChipInflate,
                    radius: _tourChipRadius,
                    child: MobileFilterChip(
                      icon: Icons.view_agenda_outlined,
                      label: _layout.label,
                      active: false,
                      onTap: _pickLayout,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(margin, _stripGap, margin, 0),
                // Lit with all it shows below, down to the screen's bottom.
                child: MobileTourTarget(
                  id: kPupilCalendarTourBands,
                  inflate: _tourBandsInflate,
                  radius: _tourBandsRadius,
                  toBottom: true,
                  child: MobilePageStrip(
                    labels: [for (final band in TimeBucket.values) bandLabel(band)],
                    controller: _pageController,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

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
              shown: shown,
              onShow: _show,
              margin: margin,
              tourTarget: kPupilCalendarTourChildren,
            ),
          ),
        SizedBox(height: tiles ? _tilesGap : _headerGap),
        if (!rail) controls,
      ],
    );

    final Widget bands = PageView(
      controller: _pageController,
      physics: closed ? const NeverScrollableScrollPhysics() : null,
      children: [
        for (final band in TimeBucket.values)
          _scrollable(_buildBand(band, tablet: tablet, lying: lying), side: margin, bottom: bottom),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        key: _nestedKey,
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
                        controls,
                        Expanded(child: bands),
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
                      shown: shown,
                      onShow: _show,
                      bottom: bottom,
                      tourTarget: kPupilCalendarTourChildren,
                    ),
                  ),
                ],
              )
            : bands,
      ),
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom})
  {
    final bool centred = child is MobileCalendarNotice || child is MobileWaiting;

    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: () => _load(quiet: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            clipBehavior: Clip.none,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(side, _topRoom, side, bottom),
            // No rise when a day comes in: the calendar is simply there.
            child: centred
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - _topRoom - bottom),
                    ),
                    child: Center(
                      child: SizedBox(width: MobileNavSheet.tabletWidth, child: child),
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

typedef _Present = ({int? nowMinutes, bool pastDay, Key? nowKey});

// What a tour lights in a band: the children's summary, and its lesson.
typedef _BandTour = ({String cards, LessonItem? lesson, String lessonId});

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
