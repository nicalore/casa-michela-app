import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_page_container.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_today_button.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../lessons/widgets/lessons_closed_day.dart';

const double _headerGap = 22;

const double _dayLabelWidth = 250;

const double _toolGap = 16;

const double _dayNavMin = 470;

const double kCalendarCardGap = 52;

// Below this the page lists lessons instead of a timeline, matching the admin's kCalendarTimelineMin.
const double kCalendarListBelow = 900;

String ofBand(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => 'della mattina',
    TimeBucket.afternoon => 'del pomeriggio',
    TimeBucket.evening => 'della sera',
  };
}

class CalendarPageShell extends StatelessWidget
{
  final String currentRoute;

  final TimeBucket band;
  final ValueChanged<TimeBucket> onBand;

  final DateTime day;
  final bool isToday;
  final bool isFirstDay;
  final bool isBusy;
  final ValueChanged<DateTime> onDay;

  final bool isClosed;
  final String? closureNote;

  final List<Widget> Function(bool isNarrow) tools;

  final Widget Function(bool isNarrow) body;

  const CalendarPageShell({
    super.key,
    required this.currentRoute,
    required this.band,
    required this.onBand,
    required this.day,
    required this.isToday,
    required this.isFirstDay,
    required this.isBusy,
    required this.onDay,
    required this.isClosed,
    this.closureNote,
    this.tools = _noTools,
    required this.body,
  });

  static List<Widget> _noTools(bool isNarrow) => const [];

  Widget _buildBandPicker()
  {
    return AppSegmentedTabs(
      labels: [for (final bucket in TimeBucket.values) bandLabel(bucket)],
      selectedIndex: band.index,
      onSelected: (index) => onBand(TimeBucket.values[index]),
      padding: EdgeInsets.zero,
      hugContent: true,
    );
  }

  Widget _buildDayLabel()
  {
    return Text(
      '${formatWeekdayColumnLabel(day)} ${day.year}',
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
  }

  Widget _buildBackArrow()
  {
    return CarouselArrowButton(
      icon: Icons.chevron_left_rounded,
      isDisabled: isFirstDay || isBusy,
      onTap: () => onDay(addDays(day, -1)),
    );
  }

  Widget _buildForwardArrow()
  {
    return CarouselArrowButton(
      icon: Icons.chevron_right_rounded,
      isDisabled: isToday || isBusy,
      onTap: () => onDay(addDays(day, 1)),
    );
  }

  Widget _buildDayNav()
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTodayButton(onTap: () => onDay(DateTime.now())),
        const SizedBox(width: 12),
        _buildBackArrow(),
        const SizedBox(width: 8),
        SizedBox(width: _dayLabelWidth, child: _buildDayLabel()),
        const SizedBox(width: 8),
        _buildForwardArrow(),
      ],
    );
  }

  Widget _buildNarrowDayNav()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildBackArrow(),
            Expanded(child: Center(child: _buildDayLabel())),
            _buildForwardArrow(),
          ],
        ),
        const SizedBox(height: 12),
        AppTodayButton(onTap: () => onDay(DateTime.now())),
      ],
    );
  }

  Widget _buildHeader(bool navFits, bool isNarrow)
  {
    final Widget dayNav = navFits ? _buildDayNav() : _buildNarrowDayNav();

    if (isClosed)
    {
      return Align(alignment: navFits ? Alignment.centerRight : Alignment.center, child: dayNav);
    }

    final Widget group = Wrap(
      spacing: _toolGap,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildBandPicker(),
        ...tools(isNarrow),
      ],
    );

    if (!navFits)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group,
          const SizedBox(height: 16),
          dayNav,
        ],
      );
    }

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        group,
        dayNav,
      ],
    );
  }

  Widget _buildPage(double contentWidth)
  {
    final navFits = contentWidth >= _dayNavMin;
    final isNarrow = contentWidth < kCalendarListBelow;

    if (isClosed)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.header,
            child: _buildHeader(navFits, isNarrow),
          ),
          const SizedBox(height: _headerGap),
          Expanded(child: LessonsClosedDay(message: closureNote)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: _buildHeader(navFits, isNarrow),
        ),
        const SizedBox(height: _headerGap),
        Expanded(
          child: PageTransitionScrollView(
            child: PageTransitionItem(
              slot: PageTransitionItem.list,
              child: body(isNarrow),
            ),
          ),
        ),
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
                  animated: true,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                  animated: true,
                ),
                const PageWatermark(),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, AppTopBar.contentTopInsetFor(size), margin, 28),
                    child: Center(
                      child: SizedBox(
                        width: width - 2 * margin,
                        child: _buildPage(width - 2 * margin),
                      ),
                    ),
                  ),
                ),
                AppTopBar(currentRoute: currentRoute),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CalendarEmptyBand extends StatelessWidget
{
  final IconData icon;
  final String title;
  final String message;

  const CalendarEmptyBand({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 56, bottom: 8),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppTheme.trialMutedText),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarUnpublishedBand extends StatelessWidget
{
  final TimeBucket band;

  const CalendarUnpublishedBand({super.key, required this.band});

  @override
  Widget build(BuildContext context)
  {
    return CalendarEmptyBand(
      icon: Icons.pending_actions_rounded,
      title: 'Calendario in preparazione',
      message: 'Il calendario ${ofBand(band)} non è ancora stato pubblicato.',
    );
  }
}

class CalendarLoading extends StatelessWidget
{
  const CalendarLoading({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
    );
  }
}

class CalendarNote extends StatelessWidget
{
  final String text;

  const CalendarNote(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
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
}
