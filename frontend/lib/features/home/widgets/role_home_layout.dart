import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../routing/app_router.dart';
import '../../../services/api_service.dart';
import '../../association/models/opening_day_item.dart';
import '../../auth/models/me_response.dart';
import '../../dashboard/widgets/dashboard_greeting.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../../lessons/models/activity_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../people/models/person_item.dart';
import '../models/month_summary_items.dart';
import 'home_month_section.dart';
import 'home_schedule_data.dart';
import 'home_schedule_section.dart';

const String kTeacherRole = 'TEACHER';
const String kParentRole = 'PARENT';

// Titles and empty-band wording, the only thing that differs between the three
// cards the roles get.
String scheduleTitleFor(String role)
{
  return role == kTeacherRole ? 'Orari e disponibilità' : 'Orari e presenze';
}

String emptyBandLabelFor(String role)
{
  return role == kTeacherRole ? 'Nessuna disponibilità' : 'Nessuna prenotazione';
}

// Only a teacher can offer hours and be left out of the published calendar.
String? unconvenedLabelFor(String role)
{
  return role == kTeacherRole ? 'Non sei stato convocato' : null;
}

String monthTitleFor(String role) => 'Presenze e lezioni';

// Failures become null so one bad call does not fail the whole day.
Future<T?> _quiet<T>(Future<T> future)
{
  return future.then<T?>((value) => value).catchError((_) => null);
}

class RoleHomeLayout extends StatefulWidget
{
  final String role;

  final double width;
  final double height;

  const RoleHomeLayout({
    super.key,
    required this.role,
    required this.width,
    required this.height,
  });

  @override
  State<RoleHomeLayout> createState() => _RoleHomeLayoutState();
}

class _RoleHomeLayoutState extends State<RoleHomeLayout>
{
  static const double _greetingBottomGap = 24;
  static const double _sectionGap = 22;

  static const double _maxContentWidth = 1240;

  // Two equal columns, so the month card lines up with the pair below.
  static const double _twoColumnsFrom = 700;

  // Row minimums, not maximums: cards can grow past them.
  static const double _dayRowHeight = 300;
  static const double _listHeight = 286;

  final ApiService _apiService = ApiService();

  bool _loadingToday = true;
  List<HomeBandStatus>? _bands;

  bool _loadingMonth = true;
  List<HomeFigureGroup>? _month;

  // Bumped on every fetch so a stale response is dropped instead of
  // overwriting fresher data.
  int _todayRequest = 0;
  int _monthRequest = 0;

  @override
  void initState()
  {
    super.initState();

    _loadTodayData();
    _loadMonthData();
  }

  @override
  void didUpdateWidget(RoleHomeLayout oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.role != oldWidget.role)
    {
      _loadTodayData();
      _loadMonthData();
    }
  }

  // A parent with one child needs no name on the figures; with more, every
  // child is named. A pupil answers for their own hours only when nobody
  // else does.
  Future<void> _loadMonthData() async
  {
    final int request = ++_monthRequest;
    final String role = widget.role;

    List<HomeFigureGroup>? groups;

    try
    {
      if (role == kTeacherRole)
      {
        final TeacherMonthSummaryItem month = await _apiService.getTeacherMonth();

        groups = [HomeFigureGroup(name: '', figures: teacherFigures(month))];
      }
      else if (role == kParentRole)
      {
        final ParentMonthSummaryItem month = await _apiService.getParentMonth();
        final bool named = month.children.length > 1;

        groups = [
          for (final child in month.children)
            HomeFigureGroup(
              name: named ? child.student.firstName : '',
              figures: pupilFigures(child, withTariff: true),
            ),
        ];
      }
      else
      {
        final StudentMonthSummaryItem month = await _apiService.getStudentMonth();

        groups = [
          HomeFigureGroup(
            name: '',
            figures: pupilFigures(
              month.figures,
              withTariff: !month.hasParentalResponsibility,
            ),
          ),
        ];
      }
    }
    catch (_)
    {
      groups = null;
    }

    if (!mounted || request != _monthRequest)
    {
      return;
    }

    setState(()
    {
      _month = groups;
      _loadingMonth = false;
    });
  }

  // Every reading or none: a missing one would misreport the day, so _bands
  // stays null ("unknown"), which is distinct from an empty day with no
  // openings. Only the parent's own record, read to name the children, may
  // fail on its own.
  Future<void> _loadTodayData() async
  {
    final int request = ++_todayRequest;
    final String role = widget.role;
    final bool teacher = role == kTeacherRole;
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Future<List<OpeningDayItem>?> inBuildingFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kPresenceMode));
    final Future<List<OpeningDayItem>?> onScreenFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kOnlineMode));
    final Future<List<CalendarPublicationItem>?> publicationsFuture =
        _quiet(_apiService.getCalendarPublications(dateFrom: today, dateTo: today));

    final Future<List<AvailabilityItem>?> availabilitiesFuture = teacher
        ? _quiet(_apiService.getAvailabilities(dateFrom: today, dateTo: today))
        : Future.value(const []);
    final Future<List<LessonItem>?> lessonsFuture = teacher
        ? _quiet(_apiService.getLessons(dateFrom: today, dateTo: today))
        : Future.value(const []);
    final Future<List<ActivityItem>?> activitiesFuture = teacher
        ? _quiet(_apiService.getCalendarActivities(dateFrom: today, dateTo: today))
        : Future.value(const []);
    final Future<List<PresenceItem>?> presencesFuture = teacher
        ? Future.value(const [])
        : _quiet(_apiService.getPresences(dateFrom: today, dateTo: today));

    // Only the parent needs it, and only to name the children who did not
    // book: the ones who did arrive named inside their presence.
    final Future<PersonItem?> readerFuture = role == kParentRole && taxCode != null
        ? _quiet(_apiService.getPerson(taxCode))
        : Future.value(null);

    final inBuilding = await inBuildingFuture;
    final onScreen = await onScreenFuture;
    final publications = await publicationsFuture;
    final availabilities = await availabilitiesFuture;
    final lessons = await lessonsFuture;
    final activities = await activitiesFuture;
    final presences = await presencesFuture;
    final reader = await readerFuture;

    if (!mounted || request != _todayRequest)
    {
      return;
    }

    // A parent with a single child needs no names; more than one, and every
    // child is listed whether or not they booked.
    final List<String> children =
        (reader?.children ?? const []).map((child) => child.firstName).toList();

    final bool named = children.length > 1;

    List<HomeBandStatus>? bands;

    if (inBuilding != null &&
        onScreen != null &&
        publications != null &&
        availabilities != null &&
        lessons != null &&
        activities != null &&
        presences != null)
    {
      bands = homeBands(
        day: today,
        openingDays: [...inBuilding, ...onScreen],
        slots: teacher
            ? availabilitySlots(availabilities)
            : presenceSlots(presences, named: named),
        published: {
          for (final publication in publications)
            if (isSameDate(publication.date, today)) publication.band,
        },
        convened: teacher
            ? convenedSlots(day: today, lessons: lessons, activities: activities)
            : null,
        names: named ? children : const [],
      );
    }

    setState(()
    {
      _bands = bands;
      _loadingToday = false;
    });
  }

  // The slot is the card's reading-order position in the grid.
  Widget _staggered({required int slot, required Widget card})
  {
    return PageTransitionItem(slot: PageTransitionItem.header + slot, child: card);
  }

  // Beside the month card the tallest of the two sets the height and the
  // bands share the extra; alone, the minimum only keeps a quiet day from
  // collapsing to a strip.
  Widget _scheduleCard({required bool inRow})
  {
    return _staggered(
      slot: 0,
      card: HomeScheduleSection(
        bands: _bands,
        isLoading: _loadingToday,
        title: scheduleTitleFor(widget.role),
        emptyBandLabel: emptyBandLabelFor(widget.role),
        unconvenedLabel: unconvenedLabelFor(widget.role),
        minHeight: inRow ? _dayRowHeight : 0,
        fill: inRow,
      ),
    );
  }

  // Never taller than its figures: what it leaves of the column goes to
  // the notices under it.
  Widget _monthCard({required double cardWidth})
  {
    return _staggered(
      slot: 1,
      card: HomeMonthSection(
        groups: _month,
        isLoading: _loadingMonth,
        title: monthTitleFor(widget.role),
        columns: HomeMonthSection.columnsFor(width: cardWidth, groups: _month ?? const []),
      ),
    );
  }

  // tall keeps a placeholder from collapsing to a strip; fill is only for a
  // card given its height from outside, which a column's plain child is not.
  Widget _noticesCard({required bool tall, bool fill = false})
  {
    return _staggered(
      slot: 3,
      card: DashboardSectionCard(
        eyebrow: 'Messaggi',
        title: 'Comunicazioni e avvisi',
        minHeight: tall ? _listHeight : 0,
        fill: fill,
        child: const DashboardComingSoon(
          icon: Icons.campaign_rounded,
          description: '',
        ),
      ),
    );
  }

  Widget _tasksCard({required bool tall})
  {
    return _staggered(
      slot: 2,
      card: DashboardSectionCard(
        eyebrow: 'Cose da fare',
        title: 'Attività e notifiche',
        minHeight: tall ? _listHeight : 0,
        child: const DashboardComingSoon(
          icon: Icons.checklist_rounded,
          description: '',
        ),
      ),
    );
  }

  Widget _buildHome(double width)
  {
    if (width < _twoColumnsFrom)
    {
      return _column([
        _scheduleCard(inRow: false),
        _monthCard(cardWidth: width - 2 * DashboardSectionCard.padding.left),
        _tasksCard(tall: false),
        _noticesCard(tall: false),
      ]);
    }

    // The card's own width, less the padding DashboardSectionCard keeps.
    final double cardWidth = (width - _sectionGap) / 2 - 2 * DashboardSectionCard.padding.left;

    // Two columns of one height. The month card is as tall as its figures
    // and the notices under it take the rest; on the left the day grows
    // over the tasks the same way.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _scheduleCard(inRow: true)),
                const SizedBox(height: _sectionGap),
                _tasksCard(tall: true),
              ],
            ),
          ),
          const SizedBox(width: _sectionGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _monthCard(cardWidth: cardWidth),
                const SizedBox(height: _sectionGap),
                Expanded(child: _noticesCard(tall: true, fill: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _column(List<Widget> rows)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _sectionGap),
          rows[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // widget.width is the page width, not the window width.
    final AppWindowSize size = AppBreakpoints.fromWidth(widget.width);
    final double margin = AppBreakpoints.pageMargin(size);

    final double topInset = AppTopBar.contentTopInsetFor(size);
    final double greetingFontSize = size.isCompact ? 34.0 : 50.0;

    final double contentWidth = math.min(widget.width - 2 * margin, _maxContentWidth);

    final MeResponse? user = _apiService.lastKnownIdentity;

    return Container(
      width: widget.width,
      height: widget.height,
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
              padding: EdgeInsets.fromLTRB(margin, topInset, margin, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.frame,
                    child: DashboardGreeting(
                      firstName: user?.firstName ?? '',
                      fontSize: greetingFontSize,
                    ),
                  ),
                  const SizedBox(height: _greetingBottomGap),
                  Expanded(
                    child: PageTransitionScrollView(
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: _buildHome(contentWidth),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppTopBar(currentRoute: homeForRole(widget.role)),
        ],
      ),
    );
  }
}
