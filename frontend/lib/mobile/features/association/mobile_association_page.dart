import 'package:flutter/material.dart';
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
import '../../../features/association/tabs/pupil_subjects_tab.dart'
    show kSubjectsCatalogueIntro, kSubjectsCatalogueIntroWithReport;
import '../../../features/association/teacher_opinions.dart' show canSpeakFor;
import '../../../features/calendar/utils/day_marks_loader.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_info_sheet.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_month_picker.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import 'mobile_catalogue.dart';
import 'mobile_teachers_directory.dart';
import 'widgets/mobile_association_status.dart';
import 'widgets/mobile_catalogue_tab.dart';
import 'widgets/mobile_hours_day_card.dart';
import 'widgets/mobile_hours_week_tables.dart';
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

enum _Tab
{
  hours(kAssociationHoursLabel, null),
  subjects(kAssociationSubjectsLabel, 'association-subjects'),
  teachers(kAssociationTeachersLabel, 'association-teachers');

  final String label;

  // The intro's "seen" flag; null for a tab without one.
  final String? slug;

  const _Tab(this.label, this.slug);
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
      widget.role == _teacherRole ? const [_Tab.hours] : _Tab.values;

  late final List<String> _comingSoon = [
    if (widget.role == _parentRole) kAssociationMeetingsLabel,
    kAssociationNoticesLabel,
  ];

  late final bool _canReport = widget.role != _teacherRole && canSpeakFor(widget.role);

  MobileCatalogue? _catalogue;
  MobileTeachersDirectory? _directory;

  // Offered on this visit; the stored flag decides whether they rise.
  final Set<_Tab> _introduced = {};

  late DateTime _selected = _today;
  late DateTime _weekStart = startOfWeek(_selected);

  bool _loadingWeek = true;
  bool _weekFailed = false;

  // Rows of both modes for the week shown.
  List<OpeningDayItem> _weekRows = const [];

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
    ]).whenComplete(MobileHoldScope.hold(context));

    _pages.addListener(_introduceOnce);
  }

  @override
  void dispose()
  {
    _pages.dispose();
    _catalogue?.dispose();
    _directory?.dispose();

    super.dispose();
  }

  MobileCatalogue get _catalogueOf => _catalogue ??= MobileCatalogue();

  MobileTeachersDirectory get _directoryOf
  {
    return _directory ??= MobileTeachersDirectory(
      parent: widget.role == _parentRole,
      canReport: _canReport,
    )..addListener(_introduceOnce);
  }

  String _introOf(_Tab tab)
  {
    return switch (tab)
    {
      _Tab.subjects => _canReport ? kSubjectsCatalogueIntroWithReport : kSubjectsCatalogueIntro,
      _Tab.teachers => _directoryOf.intro,
      _Tab.hours => '',
    };
  }

  void _showIntro(_Tab tab)
  {
    showMobileInfoSheet(context: context, title: tab.label, paragraphs: [_introOf(tab)]);
  }

  // Only when resting on a tab; the teachers' intro waits for the directory.
  void _introduceOnce()
  {
    if (!mounted || !_pages.hasClients || !_pages.position.haveDimensions)
    {
      return;
    }

    final double page = _pages.page ?? 0;
    final int index = page.round();

    if ((page - index).abs() > 0.001 || index >= _tabs.length)
    {
      return;
    }

    final _Tab tab = _tabs[index];
    final String? slug = tab.slug;
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    if (slug == null || taxCode == null || _introduced.contains(tab))
    {
      return;
    }

    if (tab == _Tab.teachers && _directoryOf.loading)
    {
      return;
    }

    _introduced.add(tab);

    // Seen flag per role: a parent and a pupil read different words.
    showMobileInfoSheetOnce(
      context: context,
      taxCode: taxCode,
      slug: '$slug-${widget.role.toLowerCase()}',
      title: tab.label,
      paragraphs: [_introOf(tab)],
    );
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

    if (!_tabs.any((tab) => tab.slug != null))
    {
      return title;
    }

    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 14),
        AnimatedBuilder(
          animation: _pages,
          builder: (context, button)
          {
            final double shown = _introShare();

            return IgnorePointer(
              ignoring: shown < 0.5,
              child: Transform.scale(scale: shown, child: button),
            );
          },
          child: MobileInfoButton(onTap: () => _showIntro(_tabs[_page.round()])),
        ),
      ],
    );
  }

  double get _page
  {
    return _pages.hasClients && _pages.position.haveDimensions
        ? _pages.page ?? _pages.initialPage.toDouble()
        : _pages.initialPage.toDouble();
  }

  double _introShare()
  {
    final double page = _page;
    double share = 0;

    for (var i = 0; i < _tabs.length; i++)
    {
      if (_tabs[i].slug != null)
      {
        share += (1 - (page - i).abs()).clamp(0.0, 1.0);
      }
    }

    return share.clamp(0.0, 1.0);
  }

  Widget _buildCapsule({required bool tablet})
  {
    final DateTime today = _today;

    return MobileDateCapsule(
      label: hoursWeekLabel(_weekStart),
      current: isSameDate(_weekStart, startOfWeek(today)),
      tablet: tablet,
      onBack: !isOldestKeptWeek(_weekStart, today) && !_loadingWeek ? () => _stepWeek(-1) : null,
      onForward: !isLastCalendarWeek(_weekStart, today) && !_loadingWeek ? () => _stepWeek(1) : null,
      onPick: _pickDay,
    );
  }

  Widget _buildRibbon(List<CombinedDay> days, {required bool tablet})
  {
    final DateTime today = _today;

    return MobileWeekRibbon(
      days: days,
      selected: _selected,
      today: today,
      first: oldestKeptDay(today),
      last: calendarHorizon(today),
      tablet: tablet,
      onSelect: _showDay,
    );
  }

  Widget _buildDay(List<CombinedDay> days, {required bool tablet})
  {
    if (_loadingWeek)
    {
      return const MobileWaiting();
    }

    if (_weekFailed)
    {
      return const MobileAssociationStatus(kWeekHoursLoadFailed);
    }

    return MobileHoursDayCard(
      day: days.firstWhere((day) => isSameDate(day.date, _selected)),
      today: _today,
      tablet: tablet,
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
      MobileLoadSwitcher(child: _buildDay(days, tablet: tablet)),
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

    return [
      const _Heading(kStandardHoursTitle, tablet: false),
      MobileLoadSwitcher(
        child: _loadingOutlook
            ? const MobileWaiting()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MobileStandardHoursCard(schedule: _schedule, tablet: false),
                  ..._buildVariations(tablet: false, columns: 1),
                ],
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

    return [
      _Heading(kUpcomingVariationsTitle, tablet: tablet),
      if (runs.isEmpty)
        _EmptyCard(kNoUpcomingVariations, tablet: tablet)
      else
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
                    Expanded(child: from + column < runs.length ? card(runs[from + column]) : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
        ],
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
            const Expanded(child: _Heading(kStandardHoursTitle, tablet: true, first: true, bottom: 0)),
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
                canReport: _canReport,
                margin: margin,
                tablet: tablet,
                landscape: landscape,
              ),
            _Tab.teachers => MobileTeachersTab(
                directory: _directoryOf,
                margin: margin,
                tablet: tablet,
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
          child: child,
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
