import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../routing/app_router.dart';
import '../../../services/api_service.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/notices/notice_item.dart';
import '../../association/notices/notice_reading.dart';
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
import '../../notifications/notification_board.dart';
import '../../notifications/widgets/desktop_notifications_offer.dart';
import '../../notifications/widgets/home_notifications_section.dart';
import '../../psychologist/psychologist_tour.dart';
import '../../updates/unread_updates.dart';
import '../home_tour.dart';
import '../models/month_summary_items.dart';
import 'home_month_section.dart';
import 'home_notices_section.dart';
import 'home_schedule_data.dart';
import 'home_day_strip.dart';

const String kTeacherRole = 'TEACHER';
const String kParentRole = 'PARENT';
const String kStudentRole = 'STUDENT';

const String kPsychologistRole = 'PSYCHOLOGIST';

String scheduleTitleFor(String role)
{
  return role == kTeacherRole ? 'Orari e disponibilità' : 'Orari e prenotazioni';
}

String emptyBandLabelFor(String role)
{
  return role == kTeacherRole ? 'Nessuna disponibilità' : 'Nessuna prenotazione';
}

String? unconvenedLabelFor(String role, {required bool feminine})
{
  if (role != kTeacherRole)
  {
    return null;
  }

  return feminine ? 'Non sei stata convocata' : 'Non sei stato convocato';
}

String ownHeadingFor(String role)
{
  return role == kTeacherRole ? 'Disponibilità' : 'Prenotazioni';
}

String? convenedHeadingFor(String role)
{
  return role == kTeacherRole ? 'Convocazione' : null;
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

class _RoleHomeLayoutState extends State<RoleHomeLayout> with DestinationRefresh
{
  static const double _greetingBottomGap = 12;
  static const double _sectionGap = 16;

  // The greeting sits nearer the bar than other pages' content: the home must fit one screen.
  static const double _greetingTopGap = 16;

  static const double _denseGreetingBottomGap = 8;
  static const double _denseSectionGap = 12;
  static const double _denseGreetingTopGap = 14;
  static const double _minimalGreetingTopGap = 12;

  // Where the page scrolls, the notifications show the newest few.
  static const int _cappedTasks = 4;

  // On a short laptop two rows of notices leave the rest of the left column room.
  static const int _compactNotices = 4;

  static const double _maxContentWidth = 1600;

  // Below it the day's three bands get too narrow beside the notifications, and the cards stack.
  static const double _besideFrom = 1150;
  static const double _leftShare = 0.6;

  // The notifications' least height when the left column is short, as on a closed day.
  static const double _tasksFloor = 520;

  final ApiService _apiService = ApiService();

  bool _loadingToday = true;
  List<HomeBandStatus>? _bands;

  // A parent of two or more: lanes per child.
  bool _named = false;

  bool _loadingMonth = true;
  List<HomeFigureGroup>? _month;

  bool _loadingNotices = true;
  List<NoticeHeadlineItem>? _notices;

  // The parent's own record, read with the day: its children decline the tour's sentences.
  Future<PersonItem?> _reader = Future.value(null);

  // Bumped on every fetch so a stale response is dropped.
  int _todayRequest = 0;
  int _monthRequest = 0;
  int _noticesRequest = 0;

  @override
  void initState()
  {
    super.initState();

    _loadTodayData();
    _loadMonthData();
    _loadNotices();
    _loadNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) => _startTour());
  }

  // The notifications question comes first, then the updates not yet read, then the tour.
  Future<void> _startTour() async
  {
    await offerNotificationsOnce(context);

    if (!mounted)
    {
      return;
    }

    await showUnreadUpdatesOnce(context);

    final MeResponse? user = _apiService.lastKnownIdentity;

    if (!mounted || user == null)
    {
      return;
    }

    final DesktopTour? tour = await _tourFor(user);

    if (!mounted || tour == null)
    {
      return;
    }

    startDesktopTourOnce(context, taxCode: user.taxCode, tour: tour);
  }

  Future<DesktopTour?> _tourFor(MeResponse user) async
  {
    final bool manyRoles = user.availableRoles.length > 1;

    return switch (widget.role)
    {
      kPsychologistRole => psychologistHomeTour(manyRoles: manyRoles),
      kTeacherRole => teacherHomeTour(manyRoles: manyRoles),
      kParentRole => parentHomeTour(manyRoles: manyRoles, genders: await _childGenders()),
      kStudentRole => studentHomeTour(manyRoles: manyRoles, answeredFor: user.hasParentalResponsibility),
      _ => null,
    };
  }

  Future<List<String?>> _childGenders() async
  {
    final PersonItem? reader = await _reader;

    return [for (final child in reader?.children ?? const []) child.gender];
  }

  @override
  void didUpdateWidget(RoleHomeLayout oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.role != oldWidget.role)
    {
      _loadTodayData();
      _loadMonthData();
      _loadNotices();
      _loadNotifications();
    }
  }

  @override
  void onDestinationShown()
  {
    _loadTodayData();
    _loadMonthData();
    _loadNotices();
    _loadNotifications();
    _startTour();
  }

  void _loadNotifications()
  {
    if (widget.role != kPsychologistRole)
    {
      NotificationBoard.instance.load();
    }
  }

  Future<void> _loadNotices() async
  {
    if (widget.role == kPsychologistRole)
    {
      return;
    }

    final int request = ++_noticesRequest;
    final List<NoticeHeadlineItem>? notices = await _quiet(_apiService.getHomeNotices(widget.role));

    if (!mounted || request != _noticesRequest)
    {
      return;
    }

    setState(()
    {
      _notices = notices;
      _loadingNotices = false;
    });
  }

  Future<void> _loadMonthData() async
  {
    if (widget.role == kPsychologistRole)
    {
      return;
    }

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
              withWeekly: true,
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

  // Any failed reading leaves _bands null ("unknown"), distinct from an empty day.
  Future<void> _loadTodayData() async
  {
    if (widget.role == kPsychologistRole)
    {
      return;
    }

    final int request = ++_todayRequest;
    final String role = widget.role;
    final bool teacher = role == kTeacherRole;
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    final DateTime now = romeNow();
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

    final Future<PersonItem?> readerFuture = role == kParentRole && taxCode != null
        ? _quiet(_apiService.getPerson(taxCode))
        : Future.value(null);

    _reader = readerFuture;

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

    final List<String> children =
        (reader?.children ?? const []).map((child) => child.firstName).toList();

    final bool named = children.length > 1;

    // The server scopes by role, so an administrator would also get everybody's presences.
    final Set<String> own = {
      if (role == kParentRole)
        for (final child in reader?.children ?? const []) child.fiscalCode
      else
        ?taxCode,
    };

    final List<PresenceItem>? ownPresences = presences
        ?.where((presence) => own.contains(presence.studentTaxCode))
        .toList();

    List<HomeBandStatus>? bands;

    if (inBuilding != null &&
        onScreen != null &&
        publications != null &&
        availabilities != null &&
        lessons != null &&
        activities != null &&
        ownPresences != null)
    {
      bands = homeBands(
        day: today,
        openingDays: [...inBuilding, ...onScreen],
        slots: teacher
            ? availabilitySlots(availabilities)
            : presenceSlots(ownPresences, named: named),
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
      _named = named;
      _loadingToday = false;
    });
  }

  Widget _staggered({required int slot, required String tour, required Widget card})
  {
    return PageTransitionItem(
      slot: PageTransitionItem.header + slot,
      child: DesktopTourTarget(id: tour, child: card),
    );
  }

  Widget _dayCard()
  {
    final DateTime now = romeNow();

    return _staggered(
      slot: 0,
      tour: kTourHomeToday,
      card: HomeDayStrip(
        bands: _bands,
        isLoading: _loadingToday,
        day: DateTime(now.year, now.month, now.day),
        title: scheduleTitleFor(widget.role),
        ownHeading: ownHeadingFor(widget.role),
        convenedHeading: convenedHeadingFor(widget.role),
        emptyBandLabel: emptyBandLabelFor(widget.role),
        unconvenedLabel: unconvenedLabelFor(
          widget.role,
          feminine: _apiService.lastKnownIdentity?.gender == 'F',
        ),
        named: _named,
      ),
    );
  }

  Widget _monthCard({required double cardWidth})
  {
    return _staggered(
      slot: 1,
      tour: kTourHomeMonth,
      card: HomeMonthSection(
        groups: _month,
        isLoading: _loadingMonth,
        title: monthTitleFor(widget.role),
        month: romeNow(),
        columns: HomeMonthSection.columnsFor(width: cardWidth, groups: _month ?? const []),
      ),
    );
  }

  Widget _noticesCard({required int columns, int shown = kHomeNoticesShown})
  {
    return _staggered(
      slot: 3,
      tour: kTourHomeNotices,
      card: HomeNoticesSection(
        notices: _notices,
        isLoading: _loadingNotices,
        onOpen: (notice) => openNoticeReading(context, notice.id),
        columns: columns,
        shown: shown,
      ),
    );
  }

  // Tall: as high as the column beside it, scrolling inside; capped: the newest few, where the page scrolls.
  Widget _tasksCard({bool tall = false, int? limit})
  {
    return _staggered(
      slot: 2,
      tour: kTourHomeNotifications,
      card: HomeNotificationsSection(fill: tall, limit: limit),
    );
  }

  Widget _buildHome(double width, AppWindowSize size)
  {
    final double inset = 2 * DashboardSectionCard.badgedPaddingOf(context).left;
    final double gap = size.isDense ? _denseSectionGap : _sectionGap;

    // The wide window as before; the compact one keeps its two columns at every width it has.
    if (size == AppWindowSize.compact || (size == AppWindowSize.wide && width >= _besideFrom))
    {
      final double left = ((width - gap) * _leftShare).floorToDouble();
      final bool compact = size == AppWindowSize.compact;

      return homeBeside(
        left: _column([
          _dayCard(),
          _monthCard(cardWidth: left - inset),
          _noticesCard(columns: 2, shown: compact ? _compactNotices : kHomeNoticesShown),
        ], gap: gap),
        right: _tasksCard(tall: true),
        leftWidth: left,
        gap: gap,
        floor: compact ? 0 : _tasksFloor,
      );
    }

    // Narrow: the day across, the rest in two columns; the page scrolls, nothing inside it.
    if (size == AppWindowSize.narrow)
    {
      final double left = ((width - gap) * _narrowLeftShare).floorToDouble();

      return _column([
        _dayCard(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: left,
              child: _column([
                _monthCard(cardWidth: left - inset),
                _noticesCard(columns: 1),
              ], gap: gap),
            ),
            SizedBox(width: gap),
            Expanded(child: _tasksCard(limit: _cappedTasks)),
          ],
        ),
      ], gap: gap);
    }

    if (size == AppWindowSize.minimal)
    {
      return _column([
        _dayCard(),
        _tasksCard(limit: _cappedTasks),
        _monthCard(cardWidth: width - inset),
        _noticesCard(columns: 1),
      ], gap: gap);
    }

    return _column([
      _dayCard(),
      _monthCard(cardWidth: width - inset),
      _tasksCard(limit: _cappedTasks),
      _noticesCard(columns: width >= _twoNoticeColumnsFrom ? 2 : 1),
    ], gap: gap);
  }

  static const double _twoNoticeColumnsFrom = 700;

  static const double _narrowLeftShare = 0.52;

  Widget _column(List<Widget> rows, {double gap = _sectionGap})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final AppWindowSize size = AppBreakpoints.of(context);
    final double margin = AppBreakpoints.pageMargin(size);

    final double topInset = AppTopBar.bottomFor(size) + switch (size)
    {
      AppWindowSize.wide => _greetingTopGap,
      AppWindowSize.minimal => _minimalGreetingTopGap,
      _ => _denseGreetingTopGap,
    };

    final double greetingFontSize = switch (size)
    {
      AppWindowSize.wide => 42.0,
      AppWindowSize.minimal => 24.0,
      _ => 28.0,
    };

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
          ),
          const CornerGlow(
            corner: GlowCorner.bottomLeft,
            tint: AppTheme.trialSeaGreen,
            edgeTint: AppTheme.trialTealDeep,
          ),
          const PageWatermark(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, topInset, margin, size.isDense ? 16 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.frame,
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: DashboardGreeting(
                          firstName: user?.firstName ?? '',
                          birthDate: user?.birthDate,
                          fontSize: greetingFontSize,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.isDense ? _denseGreetingBottomGap : _greetingBottomGap),
                  Expanded(
                    child: widget.role == kPsychologistRole
                        ? const Center(
                            child: PageTransitionItem(
                              slot: PageTransitionItem.header,
                              child: AppEmptyCard(icon: Icons.construction_rounded, message: 'In arrivo'),
                            ),
                          )
                        : PageTransitionScrollView(
                            child: Center(
                              child: SizedBox(
                                width: contentWidth,
                                child: _buildHome(contentWidth, size),
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

// The right card takes the height the left column settles on, never adding to it.
Widget homeBeside({
  required Widget left,
  required Widget right,
  required double leftWidth,
  required double gap,
  required double floor,
})
{
  return ConstrainedBox(
    constraints: BoxConstraints(minHeight: floor),
    child: Stack(
      children: [
        SizedBox(width: leftWidth, child: left),
        Positioned(top: 0, bottom: 0, left: leftWidth + gap, right: 0, child: right),
      ],
    ),
  );
}
