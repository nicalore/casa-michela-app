import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/association_strings.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/tabs/opening_hours/calendar_bounds.dart';
import '../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../features/association/tabs/opening_hours/hours_strings.dart';
import '../../../features/association/tabs/opening_hours/hours_week_nav.dart';
import '../../../features/association/teacher_opinions.dart' show canSpeakFor;
import '../../../features/calendar/utils/day_marks_loader.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_month_picker.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_association_tour.dart';
import 'mobile_catalogue.dart';
import 'mobile_notices_board.dart';
import 'mobile_teachers_directory.dart';
import 'widgets/mobile_association_status.dart';
import 'widgets/mobile_catalogue_tab.dart';
import 'widgets/mobile_hours_day_card.dart';
import 'widgets/mobile_hours_week_tables.dart';
import 'widgets/mobile_notices_tab.dart';
import 'widgets/mobile_standard_hours_card.dart';
import 'widgets/mobile_teachers_tab.dart';
import 'widgets/mobile_variation_card.dart';
import 'widgets/mobile_week_ribbon.dart';

const String _title = 'Associazione';

const String _teacherRole = 'TEACHER';
const String _parentRole = 'PARENT';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _stripGap = 14;
const double _ribbonGap = 14;
const double _cardGap = 12;

const double _tabletGap = 20;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room between the strip's rule and the first card.
const double _topRoom = 16;

// Cards are lit a little larger than themselves; the capsule and the ribbon too.
const EdgeInsets _tourCardInflate = EdgeInsets.all(5);
const double _tourCardRadius = 27;
const EdgeInsets _tourWeekInflate = EdgeInsets.all(5);
const double _tourWeekRadius = 30;
const EdgeInsets _tourDaysInflate = EdgeInsets.all(6);
const double _tourDaysRadius = 24;
// Joined with the table's hole, which is grown by 5: no wider than it.
const EdgeInsets _tourHeadingInflate = EdgeInsets.fromLTRB(0, 10, 0, 6);
const double _tourHeadingRadius = 16;

// Above a heading that does not open the page, as _Heading leaves it.
const double _headingTop = 30;
const double _tabletHeadingTop = 34;

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

enum _Tab
{
  hours(kAssociationHoursLabel),
  subjects(kAssociationSubjectsLabel),
  teachers(kAssociationTeachersLabel),
  notices(kAssociationNoticesLabel);

  final String label;

  const _Tab(this.label);
}

class MobileAssociationPage extends StatefulWidget
{
  final String role;

  // The time now; a probe fixes it.
  final DateTime Function() clock;

  const MobileAssociationPage({super.key, required this.role, this.clock = romeNow});

  @override
  State<MobileAssociationPage> createState() => _MobileAssociationPageState();
}

class _MobileAssociationPageState extends State<MobileAssociationPage>
{
  final ApiService _apiService = ApiService();

  final PageController _pages = PageController();

  late final List<_Tab> _tabs =
      widget.role == _teacherRole ? const [_Tab.hours, _Tab.notices] : _Tab.values;

  late final List<String> _comingSoon = [
    if (widget.role == _parentRole) kAssociationMeetingsLabel,
  ];

  late final bool _canReport = widget.role != _teacherRole && canSpeakFor(widget.role);

  late final bool _isParent = widget.role == _parentRole;


  // Set once the shell has stopped moving the page in.
  bool _settledIn = false;

  MobileCatalogue? _catalogue;
  MobileTeachersDirectory? _directory;
  MobileNoticesBoard? _board;

  late DateTime _selected = _today;
  late DateTime _weekStart = startOfWeek(_selected);

  bool _loadingWeek = true;
  bool _weekFailed = false;

  // Rows of both modes for the week shown.
  List<OpeningDayItem> _weekRows = const [];

  // The card shown while the next week loads, so it never leaves.
  CombinedDay? _keptDay;

  bool _loadingOutlook = true;
  bool _outlookFailed = false;

  List<OpeningDayItem> _variations = const [];
  StandardSchedule _schedule = const {};

  // Kept beside the rows, so the list is cut on the window they were read for.
  late DateTime _windowEnd = addDays(_today, kVariationsWindowDays);

  // Bumped on every fetch so a stale response is dropped.
  int _weekRequest = 0;
  int _outlookRequest = 0;

  DateTime get _today
  {
    final DateTime now = widget.clock();

    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState()
  {
    super.initState();

    Future.wait([
      _loadWeek(),
      _loadOutlook(),
      if (_tabs.contains(_Tab.subjects)) _catalogueOf.ensureLoaded(),
      if (_tabs.contains(_Tab.teachers)) _directoryOf.ensureLoaded(),
      _boardOf.ensureLoaded(),
    ]).whenComplete(MobileHoldScope.hold(context));

    _pages.addListener(_onPage);
    _boardOf.addListener(_tourLater);
    mobileTourChanges.addListener(_tourLater);
    MobileNavSheet.hidden.addListener(_tourLater);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_settledIn && mobileTourSettled(context))
    {
      _settledIn = true;
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    _board?.removeListener(_tourLater);
    mobileTourChanges.removeListener(_tourLater);
    MobileNavSheet.hidden.removeListener(_tourLater);

    _pages.dispose();
    _catalogue?.dispose();
    _directory?.dispose();
    _board?.dispose();

    super.dispose();
  }

  MobileCatalogue get _catalogueOf => _catalogue ??= MobileCatalogue();

  MobileNoticesBoard get _boardOf => _board ??= MobileNoticesBoard(role: widget.role);

  MobileTeachersDirectory get _directoryOf
  {
    // The tour waits for those it names.
    return _directory ??= MobileTeachersDirectory(
      parent: _isParent,
      canReport: _canReport,
    )..addListener(_tourLater);
  }

  // Asks for the frame too: the page may be still.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  int? _restingPage;

  void _onPage()
  {
    final double page = _page;

    if ((page - page.round()).abs() < _settled && page.round() != _restingPage)
    {
      _restingPage = page.round();
      _tourLater();
    }
  }

  // A parent or a student, with the subjects and the teachers; a teacher has neither.
  AssociationReader? get _reader => _tabs.contains(_Tab.teachers) ? _directoryOf.reader : null;

  bool get _hasVariations => CombinedVariation.from(_variations, startsOnOrBefore: _windowEnd).isNotEmpty;

  // The main tour on the first visit to the hours; later a one-step tour for a mark it could not show.
  Future<void> _tourCheck() async
  {
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    if (!mounted ||
        !_settledIn ||
        taxCode == null ||
        _loadingWeek ||
        _loadingOutlook ||
        (_tabs.contains(_Tab.teachers) && _directoryOf.loading) ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pages.hasClients ||
        (_page - _page.round()).abs() >= _settled)
    {
      return;
    }

    final int page = _page.round();
    final bool tablet = MobileBreakpoints.of(context).isTablet;

    if (!await isMobileTourSeen(taxCode: taxCode, tour: associationMainTour(_pages, reader: _reader)))
    {
      if (mounted && page == 0)
      {
        await startMobileTourOnce(
          taxCode: taxCode,
          tour: associationTour(
            pages: _pages,
            tablet: tablet,
            variations: !_outlookFailed && _hasVariations,
            pinned: () => _boardOf.shown.any((notice) => notice.pinned),
            reader: _reader,
          ),
        );
      }

      return;
    }

    final AssociationMark? mark = switch (_tabs[page])
    {
      _Tab.hours => AssociationMark.variation,
      _Tab.notices => AssociationMark.pinned,
      _Tab.subjects || _Tab.teachers => null,
    };

    if (mark == null)
    {
      return;
    }

    final MobileTour tour = associationMarkTour(mark);

    if (isMobileTourTargetShown(associationTourMark(mark)) && !await isMobileTourSeen(taxCode: taxCode, tour: tour))
    {
      if (mounted)
      {
        await startMobileTourOnce(taxCode: taxCode, tour: tour);
      }
    }
  }

  // Once the notices' day picker has risen, the first time.
  void _pickerShown()
  {
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    if (taxCode != null)
    {
      startMobileTourOnce(taxCode: taxCode, tour: associationPickerTour());
    }
  }

  Future<void> _loadWeek({bool quiet = false}) async
  {
    final int request = ++_weekRequest;
    final DateTime weekStart = _weekStart;

    try
    {
      final List<OpeningDayItem> rows = await _apiService.getOpeningDays(
        dateFrom: weekStart,
        dateTo: addDays(weekStart, 6),
      );

      if (!mounted || request != _weekRequest)
      {
        return;
      }

      setState(()
      {
        _weekRows = rows;
        _loadingWeek = false;
        _weekFailed = false;
      });

      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento degli orari della settimana');

      if (!mounted || request != _weekRequest)
      {
        return;
      }

      setState(()
      {
        _loadingWeek = false;
        _weekFailed = !quiet || _weekFailed;
      });
    }
  }

  Future<void> _loadOutlook({bool quiet = false}) async
  {
    final int request = ++_outlookRequest;
    final DateTime today = _today;

    try
    {
      final List<OpeningDayItem> days = await _apiService.getOpeningDays(
        dateFrom: addDays(today, -kScheduleLookbackDays),
        dateTo: addDays(today, kVariationsFetchDays),
      );

      if (!mounted || request != _outlookRequest)
      {
        return;
      }

      setState(()
      {
        _variations = upcomingVariationsOf(days, today);
        _schedule = standardScheduleOf(days, today);
        _windowEnd = addDays(today, kVariationsWindowDays);
        _loadingOutlook = false;
        _outlookFailed = false;
      });

      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle variazioni programmate');

      if (!mounted || request != _outlookRequest)
      {
        return;
      }

      setState(()
      {
        _loadingOutlook = false;
        _outlookFailed = !quiet || _outlookFailed;
      });
    }
  }

  Future<void> _refresh() async
  {
    await Future.wait([_loadWeek(quiet: true), _loadOutlook(quiet: true)]);
  }

  void _showDay(DateTime day)
  {
    final DateTime today = _today;
    DateTime target = DateTime(day.year, day.month, day.day);

    if (target.isBefore(oldestKeptDay(today)))
    {
      target = oldestKeptDay(today);
    }

    if (target.isAfter(calendarHorizon(today)))
    {
      target = calendarHorizon(today);
    }

    final DateTime weekStart = startOfWeek(target);
    final bool newWeek = !isSameDate(weekStart, _weekStart);

    setState(()
    {
      if (newWeek && !_loadingWeek)
      {
        _keptDay = _weekFailed ? null : CombinedDay.read(_weekRows, _selected, isLoading: false);
      }

      _selected = target;

      if (newWeek)
      {
        _weekStart = weekStart;
        _loadingWeek = true;
        _weekFailed = false;
      }
    });

    if (newWeek)
    {
      _loadWeek();
    }

    // Another day may show a variation's mark.
    _tourLater();
  }

  void _stepWeek(int by) => _showDay(addDays(_selected, 7 * by));

  Future<void> _pickDay() async
  {
    final DateTime today = _today;

    final DateTime? picked = await showMobileMonthPicker(
      context: context,
      selected: _selected,
      today: today,
      first: oldestKeptDay(today),
      last: calendarHorizon(today),
      loadMarks: (from, to) => loadDayMarks(from, to),
    );

    if (picked != null && mounted)
    {
      _showDay(picked);
    }
  }

  // Unread days say nothing either way, rather than reading as closed.
  List<CombinedDay> get _days
  {
    return [
      for (final day in daysOfWeek(_weekStart))
        CombinedDay.read(_weekRows, day, isLoading: _loadingWeek || _weekFailed),
    ];
  }

  Widget _buildTitle({required bool tablet})
  {
    final Widget title = Text(
      _title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );

    return title;
  }

  double get _page
  {
    return _pages.hasClients && _pages.position.haveDimensions
        ? _pages.page ?? _pages.initialPage.toDouble()
        : _pages.initialPage.toDouble();
  }

  Widget _buildCapsule({required bool tablet})
  {
    final DateTime today = _today;

    return MobileTourTarget(
      id: kAssociationTourWeek,
      inflate: _tourWeekInflate,
      radius: _tourWeekRadius,
      child: MobileDateCapsule(
        label: hoursWeekLabel(_weekStart),
        current: isSameDate(_weekStart, startOfWeek(today)),
        tablet: tablet,
        onBack: !isOldestKeptWeek(_weekStart, today) && !_loadingWeek ? () => _stepWeek(-1) : null,
        onForward: !isLastCalendarWeek(_weekStart, today) && !_loadingWeek ? () => _stepWeek(1) : null,
        onPick: _pickDay,
      ),
    );
  }

  Widget _buildRibbon(List<CombinedDay> days, {required bool tablet})
  {
    final DateTime today = _today;

    return MobileTourTarget(
      id: kAssociationTourDays,
      inflate: _tourDaysInflate,
      radius: _tourDaysRadius,
      child: MobileWeekRibbon(
        days: days,
        selected: _selected,
        today: today,
        first: oldestKeptDay(today),
        last: calendarHorizon(today),
        tablet: tablet,
        onSelect: _showDay,
      ),
    );
  }

  Widget _buildDay(List<CombinedDay> days, {required bool tablet})
  {
    if (_weekFailed)
    {
      return const MobileAssociationStatus(kWeekHoursLoadFailed);
    }

    final CombinedDay? day = _loadingWeek ? _keptDay : days.firstWhere((day) => isSameDate(day.date, _selected));

    if (day == null)
    {
      return const MobileWaiting();
    }

    return MobileTourTarget(
      id: kAssociationTourDay,
      inflate: _tourCardInflate,
      radius: _tourCardRadius,
      child: MobileHoursDayCard(
        day: day,
        today: _today,
        tablet: tablet,
        tourMark: associationTourMark(AssociationMark.variation),
      ),
    );
  }

  List<Widget> _buildWeek({required bool tablet})
  {
    final List<CombinedDay> days = _days;

    return [
      _buildCapsule(tablet: tablet),
      const SizedBox(height: _ribbonGap),
      _buildRibbon(days, tablet: tablet),
      const SizedBox(height: _ribbonGap),
      _buildDay(days, tablet: tablet),
    ];
  }

  List<Widget> _buildOutlook()
  {
    if (!_loadingOutlook && _outlookFailed)
    {
      return const [
        SizedBox(height: 30),
        MobileAssociationStatus(kVariationsLoadFailed),
      ];
    }

    // A tour lights the heading with its card.
    return [
      const SizedBox(height: _headingTop),
      MobileTourTarget(
        id: kAssociationTourStandard,
        inflate: _tourCardInflate,
        radius: _tourCardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Heading(kStandardHoursTitle, tablet: false, first: true),
            MobileLoadSwitcher(
              child: _loadingOutlook
                  ? const MobileWaiting()
                  : MobileStandardHoursCard(schedule: _schedule, tablet: false),
            ),
          ],
        ),
      ),
      MobileLoadSwitcher(
        child: _loadingOutlook
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildVariations(tablet: false, columns: 1),
              ),
      ),
    ];
  }

  List<Widget> _buildVariations({required bool tablet, required int columns})
  {
    final List<CombinedVariation> runs = CombinedVariation.from(_variations, startsOnOrBefore: _windowEnd);
    final double labelWidth = MobileVariationCard.labelWidthOf(context, tablet: tablet);
    final double gap = tablet ? _tabletGap : _cardGap;

    Widget card(CombinedVariation run) => MobileVariationCard(run: run, labelWidth: labelWidth, tablet: tablet);

    if (runs.isEmpty)
    {
      return [
        _Heading(kUpcomingVariationsTitle, tablet: tablet),
        _EmptyCard(kNoUpcomingVariations, tablet: tablet),
      ];
    }

    // A tour lights the heading with its cards.
    return [
      SizedBox(height: tablet ? _tabletHeadingTop : _headingTop),
      MobileTourTarget(
        id: kAssociationTourVariations,
        inflate: _tourCardInflate,
        radius: _tourCardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(kUpcomingVariationsTitle, tablet: tablet, first: true),
            for (var from = 0; from < runs.length; from += columns) ...[
              if (from > 0) SizedBox(height: gap),
              if (columns == 1)
                card(runs[from])
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) SizedBox(width: gap),
                        Expanded(
                          child: from + column < runs.length ? card(runs[from + column]) : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildHours({required bool tablet, required bool landscape})
  {
    if (!tablet)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._buildWeek(tablet: false),
          ..._buildOutlook(),
        ],
      );
    }

    final DateTime today = _today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _buildCapsule(tablet: true)),
            const SizedBox(width: _tabletGap),
            // Lit with the standard's table below it, as one.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                child: MobileTourTarget(
                  id: kAssociationTourStandard,
                  inflate: _tourHeadingInflate,
                  radius: _tourHeadingRadius,
                  child: const _Heading(kStandardHoursTitle, tablet: true, first: true, bottom: 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _ribbonGap),
        MobileHoursWeekTables(
          days: _days,
          weekReady: !_loadingWeek && !_weekFailed,
          weekFailure: _weekFailed ? kWeekHoursLoadFailed : null,
          today: today,
          first: oldestKeptDay(today),
          last: calendarHorizon(today),
          schedule: _schedule,
          scheduleReady: !_loadingOutlook,
          scheduleFailure: !_loadingOutlook && _outlookFailed ? kVariationsLoadFailed : null,
          gap: _tabletGap,
          tourWeek: kAssociationTourDay,
          tourStandard: kAssociationTourStandard,
          tourMark: associationTourMark(AssociationMark.variation),
        ),
        MobileLoadSwitcher(
          child: _loadingOutlook || _outlookFailed
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildVariations(tablet: true, columns: landscape ? 3 : 2),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final bool landscape = tablet && MediaQuery.orientationOf(context) == Orientation.landscape;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: _buildTitle(tablet: tablet),
        ),
        const SizedBox(height: _stripGap),
        // Edge to edge: the row scrolls past the margin.
        MobilePageStrip(
          labels: [for (final tab in _tabs) tab.label],
          comingSoon: _comingSoon,
          controller: _pages,
          scrollMargin: margin,
          tourTargets: [for (var i = 0; i < _tabs.length; i++) associationTourTab(i)],
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        // Never kept alive, which stalls the header; each tab fetches when first shown.
        body: PageView.builder(
          controller: _pages,
          physics: _tabs.length == 1 ? const NeverScrollableScrollPhysics() : null,
          itemCount: _tabs.length,
          itemBuilder: (context, index) => switch (_tabs[index])
          {
            _Tab.hours => _scrollable(
                _buildHours(tablet: tablet, landscape: landscape),
                side: margin,
                bottom: bottom,
              ),
            _Tab.subjects => MobileCatalogueTab(
                catalogue: _catalogueOf,
                tourReport: kAssociationTourReport,
                margin: margin,
                tablet: tablet,
                landscape: landscape,
              ),
            _Tab.teachers => MobileTeachersTab(
                directory: _directoryOf,
                margin: margin,
                tablet: tablet,
                tourTop: kAssociationTourTeachersTop,
              ),
            _Tab.notices => MobileNoticesTab(
                board: _boardOf,
                margin: margin,
                tablet: tablet,
                clock: widget.clock,
                onPickerShown: _pickerShown,
              ),
          },
        ),
      ),
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom})
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, _topRoom, side, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const MobileTourRunway(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget
{
  final String text;
  final bool tablet;

  final bool first;

  final double? bottom;

  const _Heading(this.text, {required this.tablet, this.first = false, this.bottom});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, first ? 0 : (tablet ? 34 : 30), 2, bottom ?? (tablet ? 14 : 12)),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: tablet ? 20 : 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget
{
  final String text;
  final bool tablet;

  const _EmptyCard(this.text, {required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: EdgeInsets.all(tablet ? 20 : 18),
      borderRadius: BorderRadius.circular(22),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: tablet ? 15 : 14,
          fontWeight: FontWeight.w500,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }
}
