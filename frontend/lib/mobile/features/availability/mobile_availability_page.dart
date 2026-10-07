import 'dart:async';

import 'package:flutter/material.dart';
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
import 'mobile_availability_draft.dart';
import 'mobile_availability_week.dart';
import 'widgets/mobile_availability_day_card.dart';
import 'widgets/mobile_availability_day_sheet.dart';
import 'widgets/mobile_availability_wizard.dart';

const String _slug = 'availability';
const String _title = 'Disponibilità';

const List<String> _pages = ['Questa settimana', 'Settimana prossima'];

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 14;
const double _cardGap = 12;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room between the strip's rule and the week's dates.
const double _topRoom = 16;

// Next week is fetched too and shows once it unlocks on Friday at 20:00.
class MobileAvailabilityPage extends StatefulWidget
{
  const MobileAvailabilityPage({super.key});

  @override
  State<MobileAvailabilityPage> createState() => _MobileAvailabilityPageState();
}

class _MobileAvailabilityPageState extends State<MobileAvailabilityPage>
{
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  DateTime _now = romeNow();

  Timer? _clock;

  bool _loading = true;
  bool _failed = false;
  bool _deleting = false;

  bool _introduced = false;

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
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_introduced && !MobileHoldScope.waitingOf(context))
    {
      _introduced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _introduceOnce());
    }
  }

  @override
  void dispose()
  {
    _clock?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  // Wakes on the minute so bands lock at their deadline; Monday means a new week's data.
  void _tick()
  {
    final DateTime now = romeNow();

    _clock = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond), ()
    {
      if (!mounted)
      {
        return;
      }

      final DateTime before = _monday;

      setState(() => _now = romeNow());

      if (!isSameDate(before, _monday))
      {
        _load(quiet: true);
      }

      _tick();
    });
  }

  Future<void> _introduceOnce()
  {
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    if (taxCode == null || !mounted)
    {
      return Future<void>.value();
    }

    return showMobileInfoSheetOnce(
      context: context,
      taxCode: taxCode,
      slug: _slug,
      title: _title,
      paragraphs: const [kAvailabilityDeadlines],
    );
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
          now: romeNow(),
          day: day,
        ));
  }

  Future<void> _edit(DateTime day, {required BuildContext from})
  {
    return _openWizard(from: from, (taxCode) => MobileAvailabilityDraft.edit(
          taxCode: taxCode,
          availabilities: _availabilities,
          openingDays: _openingDays,
          now: romeNow(),
          day: day,
        ));
  }

  Future<void> _openDay(MobileAvailabilityDay day)
  {
    return showMobileAvailabilityDaySheet(
      context: context,
      day: day,
      editable: day.isEditable,
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
        MobileInfoButton(
          onTap: () => showMobileInfoSheet(
            context: context,
            title: _title,
            paragraphs: const [kAvailabilityDeadlines],
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWeekHead(days),
          const SizedBox(height: 18),
          const _LockedWeek(),
        ],
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

    return Column(
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
          ),
        ],
      ],
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
          MobilePageStrip(labels: _pages, controller: _pageController),
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
          child: MobileLoadSwitcher(child: child),
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
