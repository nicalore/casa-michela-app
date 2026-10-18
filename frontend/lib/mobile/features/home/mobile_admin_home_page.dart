import 'package:flutter/material.dart';

import '../../../core/utils/rome_clock.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/association/notices/notice_item.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/dashboard/widgets/dashboard_birthdays_section.dart';
import '../../../features/dashboard/widgets/dashboard_stats_section.dart';
import '../../../features/dashboard/widgets/dashboard_today_section.dart';
import '../../../features/home/widgets/home_month_section.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/notifications/notification_board.dart';
import '../../../features/people/models/current_totals_item.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../notifications/mobile_notifications_offer.dart';
import 'mobile_admin_home_view.dart';
import 'widgets/mobile_admin_cards.dart';
import 'widgets/mobile_notices_list.dart';

// Their own page on phones holds more than the desktop card.
const int _birthdaysShown = 10;

// Failures become null so one bad call does not fail the whole page.
Future<T?> _quiet<T>(Future<T> future)
{
  return future.then<T?>((value) => value).catchError((_) => null);
}

// The minus is the typographic one (U+2212), as on the desktop tiles.
HomeFigure _figureOf(DashboardStat stat)
{
  final int change = stat.deltaMonth;

  return HomeFigure(
    label: stat.label,
    value: '${stat.value}',
    delta: change == 0
        ? HomeDelta.still
        : HomeDelta(text: '${change > 0 ? '+' : '−'}${change.abs()}', direction: change.sign),
  );
}

class MobileAdminHomePage extends StatefulWidget
{
  // Kept past sign-out: the shell clears the identity before the page leaves.
  final MeResponse user;

  const MobileAdminHomePage({super.key, required this.user});

  @override
  State<MobileAdminHomePage> createState() => _MobileAdminHomePageState();
}

class _MobileAdminHomePageState extends State<MobileAdminHomePage>
{
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  bool _loadingDay = true;
  List<MobileAdminBand>? _day;

  bool _loadingMonth = true;
  List<HomeFigure>? _month;

  bool _loadingBirthdays = true;
  List<DashboardBirthday> _birthdays = const [];

  MobileHomeNotices _notices = const MobileHomeNotices();

  // Bumped on every fetch so a stale response is dropped.
  int _dayRequest = 0;
  int _monthRequest = 0;
  int _birthdaysRequest = 0;
  int _noticesRequest = 0;

  bool _offered = false;

  @override
  void initState()
  {
    super.initState();
    _reload().whenComplete(MobileHoldScope.hold(context));
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_offered && mobileTourSettled(context))
    {
      _offered = true;
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          offerMobileNotificationsOnce(context);
        }
      });
    }
  }

  @override
  void dispose()
  {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reload()
  {
    return Future.wait([
      _loadDay(),
      _loadMonth(),
      _loadBirthdays(),
      _loadNotices(),
      NotificationBoard.instance.load(),
    ]);
  }

  // Only those sent to the administrators.
  Future<void> _loadNotices() async
  {
    final int request = ++_noticesRequest;
    final List<NoticeHeadlineItem>? items = await _quiet(_apiService.getHomeNotices('ADMIN'));

    if (!mounted || request != _noticesRequest)
    {
      return;
    }

    setState(() => _notices = MobileHomeNotices(loading: false, items: items));
  }

  // As the desktop: both opening modes or neither, the rest counts as empty when unread.
  Future<void> _loadDay() async
  {
    final int request = ++_dayRequest;

    final DateTime now = romeNow();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Future<List<OpeningDayItem>?> inBuildingFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kPresenceMode));
    final Future<List<OpeningDayItem>?> onScreenFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kOnlineMode));
    final Future<List<AvailabilityItem>?> availabilitiesFuture =
        _quiet(_apiService.getAvailabilities(dateFrom: today, dateTo: today));
    final Future<List<PresenceItem>?> presencesFuture =
        _quiet(_apiService.getPresences(dateFrom: today, dateTo: today));
    final Future<List<LessonItem>?> lessonsFuture = _quiet(_apiService.getLessons(dateFrom: today, dateTo: today));
    final Future<List<CalendarPublicationItem>?> publicationsFuture =
        _quiet(_apiService.getCalendarPublications(dateFrom: today, dateTo: today));

    final inBuilding = await inBuildingFuture;
    final onScreen = await onScreenFuture;
    final availabilities = await availabilitiesFuture;
    final presences = await presencesFuture;
    final lessons = await lessonsFuture;
    final publications = await publicationsFuture;

    if (!mounted || request != _dayRequest)
    {
      return;
    }

    setState(()
    {
      _day = inBuilding == null || onScreen == null
          ? null
          : adminDayBands(
              openBands(
                day: today,
                openingDays: [...inBuilding, ...onScreen],
                availabilities: availabilities ?? const [],
                presences: presences ?? const [],
                lessons: lessons ?? const [],
                publications: publications ?? const [],
              ),
            );
      _loadingDay = false;
    });
  }

  // Unlike the desktop, a total not read leaves the whole month unread rather than zero.
  Future<void> _loadMonth() async
  {
    final int request = ++_monthRequest;

    final Future<CurrentTotalsItem?> generalFuture = _quiet(_apiService.getCurrentTotals());
    final Future<CurrentTotalsItem?> teachersFuture = _quiet(_apiService.getRoleCurrentTotals('teacher'));
    final Future<CurrentTotalsItem?> studentsFuture = _quiet(_apiService.getRoleCurrentTotals('student'));

    final general = await generalFuture;
    final teachers = await teachersFuture;
    final students = await studentsFuture;

    if (!mounted || request != _monthRequest)
    {
      return;
    }

    setState(()
    {
      _month = general == null || teachers == null || students == null
          ? null
          : [
              for (final stat in dashboardStats(general: general, teachers: teachers, students: students))
                _figureOf(stat),
            ];
      _loadingMonth = false;
    });
  }

  // As the desktop, people not read leave no birthdays.
  Future<void> _loadBirthdays() async
  {
    final int request = ++_birthdaysRequest;
    final List<PersonItem>? people = await _quiet(_apiService.getPeople());

    if (!mounted || request != _birthdaysRequest)
    {
      return;
    }

    setState(()
    {
      _birthdays = upcomingBirthdays(people ?? const [], limit: _birthdaysShown);
      _loadingBirthdays = false;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final MeResponse user = widget.user;

    return MobileAdminHomeView(
      firstName: user.firstName,
      birthDate: user.birthDate,
      loadingDay: _loadingDay,
      day: _day,
      loadingMonth: _loadingMonth,
      month: _month,
      loadingBirthdays: _loadingBirthdays,
      birthdays: _birthdays,
      onRefresh: _reload,
      pageController: _pageController,
      notices: _notices,
    );
  }
}
