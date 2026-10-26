import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_page_container.dart';
import '../../../shared/utils/day_marks.dart';
import '../../../shared/widgets/app_calendar_button.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../association/tabs/opening_hours/calendar_bounds.dart';
import '../../lessons/widgets/lessons_closed_day.dart';
import '../calendar_tour.dart';
import '../utils/calendar_strings.dart';
import '../utils/day_marks_loader.dart';

export '../utils/calendar_strings.dart' show ofBand;

const double _headerGap = 22;
const double _denseHeaderGap = 12;

const double _dayLabelWidth = 250;
const double _denseDayLabelWidth = 200;

// The day nav's buttons, below the wide window.
const double _denseButton = 36;

const double _toolGap = 16;

const double _dayNavMin = 470;

const double kCalendarCardGap = 52;

const double _introGap = 24;

// Below this the page lists lessons, not a timeline, as the admin's kCalendarTimelineMin.
const double kCalendarListBelow = 900;

const double kDenseCalendarCardGap = 12;

// A band's summary over its lessons: below the wide window the summary stays put and the lessons scroll.
class CalendarSplitBody extends StatelessWidget
{
  final Widget top;
  final Widget day;

  const CalendarSplitBody({super.key, required this.top, required this.day});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        SizedBox(height: AppBreakpoints.of(context).isDense ? kDenseCalendarCardGap : kCalendarCardGap),
        day,
      ],
    );
  }
}

class CalendarPageShell extends StatelessWidget
{
  final String currentRoute;

  final TimeBucket band;
  final ValueChanged<TimeBucket> onBand;

  final DateTime day;
  // Today, or tomorrow once one of its bands is published.
  final DateTime lastDay;
  final bool isFirstDay;
  final bool isBusy;
  final ValueChanged<DateTime> onDay;

  final bool isClosed;
  final String? closureNote;

  // What the month picker marks besides closures; closures alone when null.
  final DayMarksLoader? loadMarks;

  final List<Widget> Function(bool isNarrow) tools;

  final String? intro;

  // Told when the month picker comes up and goes, for its tour.
  final void Function(BuildContext context, bool open)? onPickerOpen;

  final Widget Function(bool isNarrow) body;

  const CalendarPageShell({
    super.key,
    required this.currentRoute,
    required this.band,
    required this.onBand,
    required this.day,
    required this.lastDay,
    required this.isFirstDay,
    required this.isBusy,
    required this.onDay,
    required this.isClosed,
    this.closureNote,
    this.loadMarks,
    this.tools = _noTools,
    this.intro,
    this.onPickerOpen,
    required this.body,
  });

  static List<Widget> _noTools(bool isNarrow) => const [];

  Widget _buildBandPicker(bool dense)
  {
    return DesktopTourTarget(
      id: kTourCalendarBands,
      child: AppSegmentedTabs(
        labels: [for (final bucket in TimeBucket.values) bandLabel(bucket)],
        selectedIndex: band.index,
        onSelected: (index) => onBand(TimeBucket.values[index]),
        padding: EdgeInsets.zero,
        hugContent: true,
        height: dense ? _denseButton : 44,
        fontSize: dense ? 13.5 : 14,
      ),
    );
  }

  Widget _buildDayLabel(bool dense)
  {
    return Text(
      '${formatWeekdayColumnLabel(day)} ${day.year}',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 14 : 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );
  }

  Widget _buildBackArrow(bool dense)
  {
    return CarouselArrowButton(
      icon: Icons.chevron_left_rounded,
      isDisabled: isFirstDay || isBusy,
      size: dense ? _denseButton : CarouselArrowButton.defaultSize,
      onTap: () => onDay(addDays(day, -1)),
    );
  }

  Widget _buildForwardArrow(bool dense)
  {
    return CarouselArrowButton(
      icon: Icons.chevron_right_rounded,
      isDisabled: !day.isBefore(lastDay) || isBusy,
      size: dense ? _denseButton : CarouselArrowButton.defaultSize,
      onTap: () => onDay(addDays(day, 1)),
    );
  }

  Widget _buildCalendarButton(bool dense)
  {
    return AppCalendarButton(
      selected: day,
      first: oldestKeptDay(romeNow()),
      last: lastDay,
      onPicked: onDay,
      loadMarks: loadMarks ?? (from, to) => loadDayMarks(from, to, published: true),
      tourDays: kTourCalendarPickerDays,
      onOpen: onPickerOpen,
      size: dense ? _denseButton : CarouselArrowButton.defaultSize,
    );
  }

  Widget _buildDayNav(bool dense)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCalendarButton(dense),
        SizedBox(width: dense ? 8 : 12),
        _buildBackArrow(dense),
        SizedBox(width: dense ? 6 : 8),
        SizedBox(width: dense ? _denseDayLabelWidth : _dayLabelWidth, child: _buildDayLabel(dense)),
        SizedBox(width: dense ? 6 : 8),
        _buildForwardArrow(dense),
      ],
    );
  }

  Widget _buildNarrowDayNav(bool dense)
  {
    return Row(
      children: [
        _buildCalendarButton(dense),
        const SizedBox(width: 8),
        _buildBackArrow(dense),
        Expanded(child: Center(child: _buildDayLabel(dense))),
        _buildForwardArrow(dense),
      ],
    );
  }

  Widget _buildHeader(bool navFits, bool isNarrow, AppWindowSize size)
  {
    final bool dense = size.isDense;

    // Minimal: the bands on a line of their own and the day across the whole next one.
    final bool stacked = !navFits || size.isMinimal;

    final Widget dayNav = DesktopTourTarget(
      id: kTourCalendarDay,
      child: stacked ? _buildNarrowDayNav(dense) : _buildDayNav(dense),
    );

    if (isClosed)
    {
      return Align(alignment: stacked ? Alignment.center : Alignment.centerRight, child: dayNav);
    }

    final Widget group = Wrap(
      spacing: dense ? 12 : _toolGap,
      runSpacing: dense ? 10 : 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildBandPicker(dense),
        ...tools(isNarrow),
      ],
    );

    if (stacked)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group,
          SizedBox(height: dense ? 10 : 16),
          dayNav,
        ],
      );
    }

    return Wrap(
      spacing: dense ? 12 : 24,
      runSpacing: dense ? 10 : 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        group,
        dayNav,
      ],
    );
  }

  Widget _buildIntroduced(Widget content)
  {
    final String? intro = this.intro;

    if (intro == null)
    {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          intro,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: _introGap),
        content,
      ],
    );
  }

  Widget _buildPage(double contentWidth, AppWindowSize size)
  {
    final navFits = contentWidth >= _dayNavMin;
    final isNarrow = contentWidth < kCalendarListBelow;
    final double headerGap = size.isDense ? _denseHeaderGap : _headerGap;

    final Widget header = PageTransitionItem(
      slot: PageTransitionItem.header,
      child: _buildHeader(navFits, isNarrow, size),
    );

    if (isClosed)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: headerGap),
          Expanded(child: LessonsClosedDay(message: closureNote)),
        ],
      );
    }

    final Widget content = body(isNarrow);

    if (size.isDense && intro == null && content is CalendarSplitBody)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: headerGap),
          PageTransitionItem(slot: PageTransitionItem.list, child: content.top),
          const SizedBox(height: kDenseCalendarCardGap),
          Expanded(
            child: PageTransitionScrollView(
              child: PageTransitionItem(slot: PageTransitionItem.list, child: content.day),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: headerGap),
        Expanded(
          child: PageTransitionScrollView(
            child: PageTransitionItem(
              slot: PageTransitionItem.list,
              child: _buildIntroduced(content),
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
        // Below the wide window the page fits the window: the day scrolls inside it.
        minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.of(context);
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
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, AppTopBar.contentTopInsetFor(size), margin, size.isDense ? 16 : 28),
                    child: Center(
                      child: SizedBox(
                        width: width - 2 * margin,
                        child: _buildPage(width - 2 * margin, size),
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
  final String? message;

  const CalendarEmptyBand({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? message = this.message;

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
          if (message != null) ...[
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
        ],
      ),
    );
  }
}

class CalendarClosedBand extends StatelessWidget
{
  const CalendarClosedBand({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const CalendarEmptyBand(icon: Icons.event_busy_rounded, title: kAssociationClosedTitle);
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
      title: kCalendarUnpublishedTitle,
      message: unpublishedBandMessage(band),
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
