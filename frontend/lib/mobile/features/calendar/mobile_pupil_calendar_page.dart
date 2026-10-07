import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../../../features/lessons/models/calendar_day.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/people/models/person_face.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_choice_chips.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_info_sheet.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_month_picker.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../children/widgets/mobile_child_tiles.dart';
import 'mobile_pupil_calendar_day.dart';
import 'widgets/mobile_calendar_notice.dart';
import 'widgets/mobile_calendar_timeline.dart';
import 'widgets/mobile_lesson_card.dart';
import 'widgets/mobile_lesson_list.dart';
import 'widgets/mobile_lesson_sheet.dart';
import 'widgets/mobile_presence_card.dart';

const String _title = 'Calendario';

// Same "seen" flag for every role: the sentence is the same.
const String _slug = 'calendar';

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

  late final PageController _pageController = PageController(initialPage: _bandNow.index);

  late DateTime _day = _today;

  CalendarLayout _layout = CalendarLayout.byHour;

  bool _loading = true;
  bool _failed = false;

  MobilePupilCalendarDay? _data;

  List<MinistrySubjectItem> _ministrySubjects = const [];

  List<PersonItem> _pupils = const [];

  // By tax code, so a refresh that reorders the children keeps the one shown.
  String? _shown;

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  bool _revealed = false;

  bool _introduced = false;

  // Drops taps while a lesson's teacher is being fetched.
  bool _opening = false;

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
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _introduce();
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    _clock.dispose();
    _pageController.dispose();

    super.dispose();
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
        if (_ministrySubjects.isEmpty) _apiService.getMinistrySubjects(),
      ]);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        if (results.length > 7)
        {
          _ministrySubjects = results[7] as List<MinistrySubjectItem>;
        }

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

        _loading = false;
        _failed = false;
      });

      if (!_revealed)
      {
        _revealed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealNow());
      }
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

    if (target.isAfter(_today))
    {
      target = _today;
    }

    if (target.isBefore(oldestKeptDay(_today)))
    {
      target = oldestKeptDay(_today);
    }

    if (isSameDate(target, _day))
    {
      return;
    }

    setState(()
    {
      _day = target;
      _loading = true;
      _failed = false;
    });

    _load();
  }

  Future<void> _pickDay() async
  {
    final DateTime? picked = await showMobileMonthPicker(
      context: context,
      selected: _day,
      today: _today,
      first: oldestKeptDay(_today),
      last: _today,
      loadMarks: (from, to) => loadDayMarks(from, to, published: true),
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

    await showMobilePupilLessonSheet(
      context: context,
      lesson: lesson,
      ministrySubjects: _ministrySubjects,
      teacher: teacher,
      pupilName: _isParent ? pupil.firstName : null,
    );
  }

  List<MobileCalendarEntry> _entriesOf(PupilBandPresence presence, PersonItem pupil)
  {
    return [
      for (final lesson in presence.lessons)
        MobileCalendarEntry.pupilLesson(lesson, _ministrySubjects, onTap: () => _openLesson(lesson, pupil)),
    ];
  }

  MobileCalendarColumn _columnOf(PupilBandPresence presence, PersonItem pupil, {Widget? head})
  {
    return MobileCalendarColumn(
      entries: _entriesOf(presence, pupil),
      stretches: [
        for (final row in presence.presences) (mode: row.mode, startMinutes: row.startMinutes, endMinutes: row.endMinutes),
      ],
      head: head,
    );
  }

  String get _dayLabel
  {
    final String label = formatWeekdayColumnLabel(_day);

    return _day.year == _today.year ? label : '$label ${_day.year}';
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
        const SizedBox(width: 14),
        MobileInfoButton(
          onTap: () => showMobileInfoSheet(context: context, title: _title, paragraphs: [_hint]),
        ),
      ],
    );
  }

  String get _hint => lessonDetailsHint(verb: 'tocca');

  void _introduce()
  {
    if (_introduced || MobileHoldScope.waitingOf(context))
    {
      return;
    }

    _introduced = true;

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        showMobileInfoSheetOnce(
          context: context,
          taxCode: widget.user.taxCode,
          slug: _slug,
          title: _title,
          paragraphs: [_hint],
        );
      }
    });
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
          return _buildOne(pupils.single, presences.single, window, present, tablet: tablet, lying: lying);
        }

        return _buildTogether(pupils, presences, window, nothing, present, tablet: tablet, lying: lying);
      },
    );
  }

  Widget _buildOne(
    PersonItem pupil,
    PupilBandPresence presence,
    (int, int) window,
    _Present present, {
    required bool tablet,
    required bool lying,
  })
  {
    final Widget lessons;

    if (_layout == CalendarLayout.byLesson)
    {
      lessons = MobileLessonList(
        entries: _entriesOf(presence, pupil),
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
        lanes: [_columnOf(presence, pupil)],
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        nowKey: present.nowKey,
      );
    }
    else
    {
      lessons = MobileCalendarTimeline(
        window: window,
        columns: [_columnOf(presence, pupil)],
        nowMinutes: present.nowMinutes,
        pastDay: present.pastDay,
        tablet: tablet,
        nowKey: present.nowKey,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobilePresenceCard(presence: presence, tablet: tablet, stretched: lying),
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
    _Present present, {
    required bool tablet,
    required bool lying,
  })
  {
    MobilePupilHead headOf(int i)
    {
      return MobilePupilHead(name: pupils[i].firstName, presence: presences[i], nothingTitle: nothing, tablet: tablet);
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
                _columnOf(presences[i], pupil, head: MobilePupilLaneName(name: pupil.firstName)),
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
        for (final (i, pupil) in pupils.indexed) _columnOf(presences[i], pupil, head: headOf(i)),
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
        MobileLessonList.showsNow(_entriesOf(presences[i], pupil), present.nowMinutes, pastDay: present.pastDay),
    ].indexOf(true);

    Widget listOf(int i)
    {
      return MobileLessonList(
        entries: _entriesOf(presences[i], pupils[i]),
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
          MobilePupilLine(name: pupil.firstName, presence: presences[i], nothingTitle: nothing, tablet: tablet),
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

    final Widget controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: MobileDateCapsule(
            label: _dayLabel,
            current: _isToday,
            tablet: tablet,
            onBack: !_isFirstDay && !_loading ? () => _goToDay(addDays(_day, -1)) : null,
            onForward: !_isToday && !_loading ? () => _goToDay(addDays(_day, 1)) : null,
            onPick: _pickDay,
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
              MobileChoiceChips(
                choices: [
                  for (final layout in CalendarLayout.values) MobileChoice(value: layout.name, label: layout.label),
                ],
                value: _layout.name,
                onChanged: (value) => setState(() => _layout = CalendarLayout.values.byName(value!)),
                margin: margin,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(margin, _stripGap, margin, 0),
                child: MobilePageStrip(
                  labels: [for (final band in TimeBucket.values) bandLabel(band)],
                  controller: _pageController,
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
        if (shown != null && !rail)
          Padding(
            padding: const EdgeInsets.only(top: _tilesGap),
            child: MobileChildTiles(children: _pupils, shown: shown, onShow: _show, tablet: tablet, margin: margin),
          ),
        SizedBox(height: shown != null && !rail ? _tilesGap : _headerGap),
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
                    child: MobileChildRail(children: _pupils, shown: shown, onShow: _show, bottom: bottom),
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
