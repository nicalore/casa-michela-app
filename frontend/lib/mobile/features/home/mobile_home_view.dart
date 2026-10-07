import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/dashboard/widgets/dashboard_greeting.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import 'mobile_home_day.dart';
import 'widgets/mobile_day_timeline.dart';
import 'widgets/mobile_notices_list.dart';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 14;
const double _stripGap = 14;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

const double _shadowRoom = 20;

const double _phoneBandHeight = 182;
const double _wideBandHeight = 196;

class MobileHomeFrame extends StatelessWidget
{
  static const List<String> pageNames = ['Oggi', 'Questo mese', 'Notifiche e avvisi'];

  static const double columnGap = 24;
  static const double sectionGap = 26;
  static const double labelGap = _stripGap;

  final String firstName;
  final DateTime? birthDate;

  final Future<void> Function() onRefresh;
  final PageController pageController;

  // Phones: one per page name.
  final List<Widget> Function() pages;

  final Widget Function(bool wide) tabletBody;

  const MobileHomeFrame({
    super.key,
    required this.firstName,
    required this.birthDate,
    required this.onRefresh,
    required this.pageController,
    required this.pages,
    required this.tabletBody,
  });

  Widget _buildHeader({required bool tablet})
  {
    final DateTime now = romeNow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatWeekdayColumnLabel(now).toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 12.5 : 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          greetingLineFor(firstName: firstName, birthDate: birthDate, now: now),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 36 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.05,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom, Widget? head})
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, head == null ? _shadowRoom : 0, side, bottom),
          child: head == null
              ? child
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    head,
                    const SizedBox(height: _shadowRoom),
                    child,
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MobileFormFactor factor = MobileBreakpoints.of(context);
    final bool tablet = factor.isTablet;
    final bool wide = tablet && MediaQuery.orientationOf(context) == Orientation.landscape;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    if (tablet)
    {
      return SafeArea(
        bottom: false,
        child: _scrollable(
          tabletBody(wide),
          side: margin,
          bottom: bottom,
          head: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildHeader(tablet: true),
          ),
        ),
      );
    }

    final Widget head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(tablet: false),
        const SizedBox(height: _headerGap),
        MobilePageStrip(labels: pageNames, controller: pageController),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, 4, margin, _stripGap),
              child: head,
            ),
          ),
        ],
        body: PageView(
          controller: pageController,
          children: [
            for (final page in pages()) _scrollable(page, side: margin, bottom: bottom),
          ],
        ),
      ),
    );
  }
}

class MobileHomeSection extends StatelessWidget
{
  final String title;
  final Widget child;

  final bool fill;

  const MobileHomeSection({super.key, required this.title, required this.child, this.fill = false});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobilePageLabel(text: title),
        const SizedBox(height: _stripGap),
        if (fill) Expanded(child: child) else child,
      ],
    );
  }
}

class MobileHomeView extends StatelessWidget
{
  final String firstName;
  final DateTime? birthDate;

  final bool loadingDay;
  final MobileHomeDay? day;

  // Null when the month could not be read.
  final bool loadingMonth;
  final Widget? month;

  final Future<void> Function() onRefresh;
  final PageController pageController;

  const MobileHomeView({
    super.key,
    required this.firstName,
    required this.birthDate,
    required this.loadingDay,
    required this.day,
    required this.loadingMonth,
    required this.month,
    required this.onRefresh,
    required this.pageController,
  });

  Widget _buildToday({required bool wide, bool fill = false})
  {
    if (loadingDay)
    {
      return const MobileWaiting();
    }

    final MobileHomeDay? today = day;

    if (today == null)
    {
      return const MobileHomeStatus(kMobileDayUnavailable);
    }

    if (today.isClosed)
    {
      return const MobileHomeClosed();
    }

    return MobileDayTimeline(
      day: today,
      minBandHeight: wide ? _wideBandHeight : _phoneBandHeight,
      fill: fill,
    );
  }

  Widget _buildMonth()
  {
    if (loadingMonth)
    {
      return const MobileWaiting();
    }

    return month ?? const MobileHomeStatus(kMobileMonthUnavailable);
  }

  @override
  Widget build(BuildContext context)
  {
    const List<String> names = MobileHomeFrame.pageNames;

    return MobileHomeFrame(
      firstName: firstName,
      birthDate: birthDate,
      onRefresh: onRefresh,
      pageController: pageController,
      pages: () => [
        MobileLoadSwitcher(child: _buildToday(wide: false)),
        MobileLoadSwitcher(child: _buildMonth()),
        const MobileNoticesList(),
      ],
      tabletBody: (wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: wide ? 11 : 10,
                  child: MobileHomeSection(
                    title: names[0],
                    fill: true,
                    child: MobileLoadSwitcher(child: _buildToday(wide: wide, fill: true)),
                  ),
                ),
                const SizedBox(width: MobileHomeFrame.columnGap),
                Expanded(
                  flex: 10,
                  child: MobileHomeSection(
                    title: names[1],
                    child: MobileLoadSwitcher(child: _buildMonth()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MobileHomeFrame.sectionGap),
          MobileHomeSection(title: names[2], child: const MobileNoticesList()),
        ],
      ),
    );
  }
}

const String kMobileDayUnavailable = 'Gli orari di oggi non sono disponibili.';
const String kMobileMonthUnavailable = 'Il riepilogo del mese non è disponibile.';
const String kMobileClosedTitle = "L'Associazione è chiusa";

class MobileHomeStatus extends StatelessWidget
{
  final String text;

  const MobileHomeStatus(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

class MobileHomeClosed extends StatelessWidget
{
  const MobileHomeClosed({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_rounded, size: 26, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kMobileClosedTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Nessuna apertura prevista.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
