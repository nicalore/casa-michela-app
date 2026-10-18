import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/availability/utils/availability_strings.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/utils/booking_window.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/notifications/availability_seen.dart';
import '../../../features/notifications/week_jump.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_confirm_sheet.dart';
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
import 'mobile_availability_draft.dart';
import 'mobile_availability_tour.dart';
import 'mobile_availability_week.dart';
import 'widgets/mobile_availability_day_card.dart';
import 'widgets/mobile_availability_day_sheet.dart';
import 'widgets/mobile_availability_wizard.dart';

const String _title = 'Disponibilità';

const List<String> _pages = ['Questa settimana', 'Settimana prossima'];

const Duration _pageTurn = Duration(milliseconds: 320);

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 14;
const double _cardGap = 12;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room between the strip's rule and the week's dates.
const double _topRoom = 16;

const EdgeInsets _tourInfoInflate = EdgeInsets.all(6);
const double _tourInfoRadius = 30;

// Next week is fetched too and shows once it unlocks on Friday at 20:00.
class MobileAvailabilityPage extends StatefulWidget
{
  // Rome's time now; a test fixes it.
  final DateTime Function() clock;

  const MobileAvailabilityPage({super.key, this.clock = romeNow});

  @override
  State<MobileAvailabilityPage> createState() => _MobileAvailabilityPageState();
}

class _MobileAvailabilityPageState extends State<MobileAvailabilityPage>
{
  final ApiService _apiService = ApiService();
  // Opened from a notification: on the week it is about.
  late final PageController _pageController = PageController(initialPage: _weekOf(WeekJumps.availability.take()));

  late DateTime _now = widget.clock();

  Timer? _clock;

  bool _loading = true;
  bool _failed = false;
  bool _deleting = false;

  // Set once the page is in place; from then on every load and page change looks for a tour.
  bool _toured = false;
  int? _pageSeen;

  String? _taxCode;

  List<AvailabilityItem> _availabilities = const [];
  List<OpeningDayItem> _openingDays = const [];

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  DateTime get _monday => startOfWeek(DateTime(_now.year, _now.month, _now.day));

  @override
  void initState()
  {
    super.initState();
    _load().whenComplete(MobileHoldScope.hold(context));
    _tick();
    _pageController.addListener(_onPage);
    MobileNavSheet.hidden.addListener(_onSheets);
    mobileTourChanges.addListener(_tourLater);
    WeekJumps.availability.asked.addListener(_jump);
  }

  // 1 for a day of next week once it is open, else 0.
  int _weekOf(DateTime? day)
  {
    return day != null && startOfWeek(day).isAfter(_monday) && isNextWeekUnlocked(_now) ? 1 : 0;
  }

  // Already open: the week asked for, read again in full.
  void _jump()
  {
    final DateTime? day = WeekJumps.availability.take();

    if (day == null || !mounted)
    {
      return;
    }

    if (_pageController.hasClients)
    {
      _pageController.animateToPage(_weekOf(day), duration: _pageTurn, curve: Curves.easeInOutCubic);
    }

    setState(()
    {
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
    WeekJumps.availability.asked.removeListener(_jump);
    _pageController.dispose();

    super.dispose();
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
    final double page = _pageController.page ?? 0;

    if ((page - page.round()).abs() < 0.001 && page.round() != _pageSeen)
    {
      _pageSeen = page.round();
      _tourLater();
      _markSeen();
    }
  }

  // The week on screen: what others wrote in it is seen.
  void _markSeen()
  {
    if (_loading || _failed)
    {
      return;
    }

    final int week = _pageController.hasClients ? (_pageController.page ?? 0).round() : _pageController.initialPage;

    unawaited(markAvailabilitySeen(addDays(_monday, 7 * week)));
  }

  // A sheet closing, as the wizard after a save, may leave a new button on the page.
  void _onSheets()
  {
    if (!MobileNavSheet.hidden.value)
    {
      _tourLater();
    }
  }

  // The main tour on the first visit, then a one-step tour for each mark it could not show.
  Future<void> _tourCheck() async
  {
    final String? taxCode = _taxCode;

    if (!mounted ||
        !_toured ||
        taxCode == null ||
        _loading ||
        _failed ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pageController.hasClients)
    {
      return;
    }

    final int page = (_pageController.page ?? 0).round();
    final Set<AvailabilityMark> thisWeek = availabilityMarks(_week(0));
    final Set<AvailabilityMark> nextWeek = isNextWeekUnlocked(_now) ? availabilityMarks(_week(1)) : const {};

    if (!await isMobileTourSeen(taxCode: taxCode, tour: availabilityMainTour(_pageController)))
    {
      if (mounted && page == 0)
      {
        await startMobileTourOnce(
          taxCode: taxCode,
          tour: availabilityTour(pages: _pageController, thisWeek: thisWeek, nextWeek: nextWeek),
        );
      }

      return;
    }

    final Set<AvailabilityMark> here = page == 0 ? thisWeek : nextWeek;

    for (final AvailabilityMark mark in AvailabilityMark.values)
    {
      final MobileTour tour = availabilityMarkTour(mark, page);

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

  Future<void> _load({bool quiet = false}) async
  {
    final int request = ++_request;

    final DateTime from = _monday;
    final DateTime to = addDays(from, 13);

    try
    {
      final String taxCode =
          (_apiService.lastKnownIdentity ?? await _apiService.me()).taxCode;

      final List<dynamic> results = await Future.wait([
        _apiService.getAvailabilities(dateFrom: from, dateTo: to),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
      ]);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _taxCode = taxCode;
        _availabilities = results[0] as List<AvailabilityItem>;
        _openingDays = [
          ...results[1] as List<OpeningDayItem>,
          ...results[2] as List<OpeningDayItem>,
        ];
        _loading = false;
        _failed = false;
      });

      _markSeen();
      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle disponibilità');

      if (!mounted || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _loading = false;
        _failed = !quiet || _taxCode == null;
      });
    }
  }

  List<MobileAvailabilityDay> _week(int index)
  {
    return availabilityWeek(
      monday: addDays(_monday, 7 * index),
      now: _now,
      availabilities: _availabilities,
      openingDays: _openingDays,
      teacherTaxCode: _taxCode,
    );
  }

  // With [from], the wizard turns that sheet, which closes once saved.
  Future<void> _openWizard(MobileAvailabilityDraft Function(String taxCode) draftFor, {BuildContext? from}) async
  {
    final String? taxCode = _taxCode;

    if (taxCode == null)
    {
      return;
    }

    if (await showMobileAvailabilityWizard(context: from ?? context, draft: draftFor(taxCode)))
    {
      if (from != null && from.mounted)
      {
        closeMobileSheet(from);
      }

      await _load(quiet: true);
    }
  }

  Future<void> _addOn(DateTime day)
  {
    return _openWizard((taxCode) => MobileAvailabilityDraft.create(
          taxCode: taxCode,
          availabilities: _availabilities,
          openingDays: _openingDays,
          now: widget.clock(),
          day: day,
        ));
  }

  Future<void> _edit(DateTime day, {required BuildContext from})
  {
    return _openWizard(from: from, (taxCode) => MobileAvailabilityDraft.edit(
          taxCode: taxCode,
          availabilities: _availabilities,
          openingDays: _openingDays,
          now: widget.clock(),
          day: day,
        ));
  }

  Future<void> _openDay(MobileAvailabilityDay day)
  {
    return showMobileAvailabilityDaySheet(
      context: context,
      day: day,
      editable: day.isEditable,
      taxCode: _taxCode,
      onAction: (sheet, action) => switch (action)
      {
        MobileDeleteSlot(:final slot) => _confirmDeletion(sheet, day, [slot]),
        MobileDeleteBand(:final band) => _confirmDeletion(sheet, day, band.slots, band: band.band),
        MobileDeleteDay() => _confirmDeletion(sheet, day, [for (final band in day.bands) ...band.slots], wholeDay: true),
        MobileEditDay() => _edit(day.date, from: sheet),
      },
    );
  }

  Future<void> _confirmDeletion(
    BuildContext sheet,
    MobileAvailabilityDay day,
    List<AvailabilityItem> slots, {
    TimeBucket? band,
    bool wholeDay = false,
  }) async
  {
    final bool confirmed = await showMobileConfirmSheet(
      context: sheet,
      eyebrow: formatAvailableDayLabel(day.date),
      title: 'Confermi?',
      message: TextSpan(text: availabilityDeletionWarning(day.date, slots, band: band, wholeDay: wholeDay)),
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

    await _delete(slots);
  }

  Future<void> _delete(List<AvailabilityItem> slots) async
  {
    if (_deleting)
    {
      return;
    }

    setState(() => _deleting = true);

    final Set<int> removed = {};

    try
    {
      for (final slot in slots)
      {
        await _apiService.deleteAvailability(slot.id);
        removed.add(slot.id);
      }

      if (mounted)
      {
        MobileNotice.show(context, kAvailabilityDeleted);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(()
        {
          _availabilities = _availabilities.where((slot) => !removed.contains(slot.id)).toList();
          _deleting = false;
        });
      }
    }

    // Either way the server has the truth.
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
        const SizedBox(width: 14),
        MobileTourTarget(
          id: kAvailabilityTourInfo,
          inflate: _tourInfoInflate,
          radius: _tourInfoRadius,
          child: MobileInfoButton(
            onTap: () => showMobileInfoSheet(
              context: context,
              title: _title,
              paragraphs: const [kAvailabilityDeadlines],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHead(List<MobileAvailabilityDay> days, {String? summary})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatDateSpan(days.first.date, days.last.date),
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
    final List<MobileAvailabilityDay> days = _week(index);

    if (index == 1 && !isNextWeekUnlocked(_now))
    {
      return _lit(
        index,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWeekHead(days),
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

    if (_failed)
    {
      return const _Status('Non è stato possibile caricare le disponibilità.');
    }

    // A tour lights the first button of each kind, the first lock, and every coloured slot.
    final int firstAdd = days.indexWhere((day) => day.isEditable && !day.hasSlots);
    final int firstEdit = days.indexWhere((day) => day.isEditable && day.hasSlots);
    final int firstLock = days.indexWhere((day) => !day.isClosed && day.bands.any((band) => band.showsLock));

    return _lit(
      index,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWeekHead(
            days,
            summary: availabilitySummary(days.where((day) => day.hasSlots).length, thisWeek: index == 0),
          ),
          const SizedBox(height: 16),
          for (final (i, day) in days.indexed) ...[
            if (i > 0) const SizedBox(height: _cardGap),
            MobileAvailabilityDayCard(
              key: ValueKey(day.date),
              day: day,
              wide: tablet,
              onOpen: () => _openDay(day),
              onAdd: () => _addOn(day.date),
              tourButton: i == firstAdd
                  ? availabilityTourMark(AvailabilityMark.add, index)
                  : (i == firstEdit ? availabilityTourMark(AvailabilityMark.edit, index) : null),
              tourLock: i == firstLock ? availabilityTourMark(AvailabilityMark.lock, index) : null,
              tourSlots: availabilityTourMark(AvailabilityMark.slots, index),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lit(int index, Widget week)
  {
    return MobileTourTarget(
      id: availabilityTourWeek(index),
      inflate: kAvailabilityTourWeekInflate,
      radius: kAvailabilityTourWeekRadius,
      child: week,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final Widget header = Padding(
      padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(tablet: tablet),
          const SizedBox(height: _headerGap),
          MobilePageStrip(
            labels: _pages,
            controller: _pageController,
            tourTargets: [availabilityTourTab(0), availabilityTourTab(1)],
          ),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pageController,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _scrollable(_buildWeek(i, tablet: tablet), side: margin, bottom: bottom),
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
        onRefresh: () => _load(quiet: true),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, _topRoom, side, bottom),
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
