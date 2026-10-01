import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/association_strings.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/tabs/opening_hours/calendar_bounds.dart';
import '../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../features/association/tabs/opening_hours/hours_strings.dart';
import '../../../features/association/tabs/opening_hours/hours_week_nav.dart';
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
import 'widgets/mobile_hours_day_card.dart';
import 'widgets/mobile_standard_hours_card.dart';
import 'widgets/mobile_variation_card.dart';
import 'widgets/mobile_week_ribbon.dart';

const String _title = 'Associazione';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _stripGap = 14;
const double _ribbonGap = 14;
const double _cardGap = 12;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room between the strip's rule and the first card.
const double _topRoom = 16;

class MobileAssociationPage extends StatefulWidget
{
  // The time now; a probe fixes it.
  final DateTime Function() clock;

  const MobileAssociationPage({super.key, this.clock = DateTime.now});

  @override
  State<MobileAssociationPage> createState() => _MobileAssociationPageState();
}

class _MobileAssociationPageState extends State<MobileAssociationPage>
{
  final ApiService _apiService = ApiService();

  final PageController _pages = PageController();

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

    Future.wait([_loadWeek(), _loadOutlook()]).whenComplete(MobileHoldScope.hold(context));
  }

  @override
  void dispose()
  {
    _pages.dispose();

    super.dispose();
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
    return Text(
      _title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );
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

  Widget _buildDay(List<CombinedDay> days, {required bool tablet, bool sideBySide = false})
  {
    if (_loadingWeek)
    {
      return const MobileWaiting();
    }

    if (_weekFailed)
    {
      return const _Status(kWeekHoursLoadFailed);
    }

    return MobileHoursDayCard(
      day: days.firstWhere((day) => isSameDate(day.date, _selected)),
      today: _today,
      tablet: tablet,
      sideBySide: sideBySide,
    );
  }

  List<Widget> _buildWeek({required bool tablet, bool sideBySide = false})
  {
    final List<CombinedDay> days = _days;

    return [
      _buildCapsule(tablet: tablet),
      const SizedBox(height: _ribbonGap),
      _buildRibbon(days, tablet: tablet),
      const SizedBox(height: _ribbonGap),
      MobileLoadSwitcher(child: _buildDay(days, tablet: tablet, sideBySide: sideBySide)),
    ];
  }

  List<Widget> _buildOutlook({required bool tablet, required bool first})
  {
    if (!_loadingOutlook && _outlookFailed)
    {
      return [
        if (!first) SizedBox(height: tablet ? 34 : 30),
        const _Status(kVariationsLoadFailed),
      ];
    }

    return [
      _Heading(kStandardHoursTitle, tablet: tablet, first: first),
      MobileLoadSwitcher(
        child: _loadingOutlook ? const MobileWaiting() : _buildOutlookCards(tablet: tablet),
      ),
    ];
  }

  Widget _buildOutlookCards({required bool tablet})
  {
    final List<CombinedVariation> runs = CombinedVariation.from(_variations, startsOnOrBefore: _windowEnd);
    final double labelWidth = MobileVariationCard.labelWidthOf(context, tablet: tablet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileStandardHoursCard(schedule: _schedule, tablet: tablet),
        _Heading(kUpcomingVariationsTitle, tablet: tablet),
        if (runs.isEmpty)
          _EmptyCard(kNoUpcomingVariations, tablet: tablet)
        else
          for (final (i, run) in runs.indexed) ...[
            if (i > 0) const SizedBox(height: _cardGap),
            MobileVariationCard(run: run, labelWidth: labelWidth, tablet: tablet),
          ],
      ],
    );
  }

  Widget _buildHours({required bool tablet, required bool landscape})
  {
    if (!tablet)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._buildWeek(tablet: false),
          ..._buildOutlook(tablet: false, first: false),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: landscape ? 6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Heading(kWeeklyHoursTitle, tablet: true, first: true),
              ..._buildWeek(tablet: true, sideBySide: landscape),
            ],
          ),
        ),
        SizedBox(width: landscape ? 28 : 24),
        Expanded(
          flex: landscape ? 5 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildOutlook(tablet: true, first: true),
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

    final Widget header = Padding(
      padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(tablet: tablet),
          const SizedBox(height: _stripGap),
          MobilePageStrip(
            labels: const [kAssociationHoursLabel],
            comingSoon: const [kAssociationNoticesLabel],
            controller: _pages,
          ),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pages,
          // A single page until «Comunicazioni e avvisi» is built.
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _scrollable(_buildHours(tablet: tablet, landscape: landscape), side: margin, bottom: bottom),
          ],
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

  const _Heading(this.text, {required this.tablet, this.first = false});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, first ? 0 : (tablet ? 34 : 30), 2, tablet ? 14 : 12),
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
