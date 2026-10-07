import 'package:flutter/material.dart';

import '../../../core/utils/rome_clock.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/home/models/month_summary_items.dart';
import '../../../features/lessons/models/activity_item.dart';
import '../../../features/lessons/models/availability_item.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/lesson_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../services/api_service.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import 'mobile_home_view.dart';
import 'mobile_teacher_day.dart';
import 'widgets/mobile_month_figures.dart';

// Failures become null so one bad call does not fail the whole day.
Future<T?> _quiet<T>(Future<T> future)
{
  return future.then<T?>((value) => value).catchError((_) => null);
}

class MobileTeacherHomePage extends StatefulWidget
{
  // Kept past sign-out: the shell clears the identity before the page leaves.
  final MeResponse user;

  const MobileTeacherHomePage({super.key, required this.user});

  @override
  State<MobileTeacherHomePage> createState() => _MobileTeacherHomePageState();
}

class _MobileTeacherHomePageState extends State<MobileTeacherHomePage>
{
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  bool _loadingDay = true;
  MobileTeacherDay? _day;

  bool _loadingMonth = true;
  TeacherMonthSummaryItem? _month;

  // Bumped on every fetch so a stale response is dropped.
  int _dayRequest = 0;
  int _monthRequest = 0;

  @override
  void initState()
  {
    super.initState();
    _reload().whenComplete(MobileHoldScope.hold(context));
  }

  @override
  void dispose()
  {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reload()
  {
    return Future.wait([_loadDay(), _loadMonth()]);
  }

  // Any failed reading leaves _day null ("unknown"), distinct from a closed day.
  Future<void> _loadDay() async
  {
    final int request = ++_dayRequest;

    final DateTime now = romeNow();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Future<List<OpeningDayItem>?> inBuildingFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kPresenceMode));
    final Future<List<OpeningDayItem>?> onScreenFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kOnlineMode));
    final Future<List<CalendarPublicationItem>?> publicationsFuture =
        _quiet(_apiService.getCalendarPublications(dateFrom: today, dateTo: today));
    final Future<List<AvailabilityItem>?> availabilitiesFuture =
        _quiet(_apiService.getAvailabilities(dateFrom: today, dateTo: today));
    final Future<List<LessonItem>?> lessonsFuture =
        _quiet(_apiService.getLessons(dateFrom: today, dateTo: today));
    final Future<List<ActivityItem>?> activitiesFuture =
        _quiet(_apiService.getCalendarActivities(dateFrom: today, dateTo: today));

    final inBuilding = await inBuildingFuture;
    final onScreen = await onScreenFuture;
    final publications = await publicationsFuture;
    final availabilities = await availabilitiesFuture;
    final lessons = await lessonsFuture;
    final activities = await activitiesFuture;

    if (!mounted || request != _dayRequest)
    {
      return;
    }

    MobileTeacherDay? day;

    if (inBuilding != null &&
        onScreen != null &&
        publications != null &&
        availabilities != null &&
        lessons != null &&
        activities != null)
    {
      day = teacherDayFrom(
        day: today,
        openingDays: [...inBuilding, ...onScreen],
        publications: publications,
        availabilities: availabilities,
        lessons: lessons,
        activities: activities,
        teacherTaxCode: widget.user.taxCode,
      );
    }

    setState(()
    {
      _day = day;
      _loadingDay = false;
    });
  }

  Future<void> _loadMonth() async
  {
    final int request = ++_monthRequest;

    final TeacherMonthSummaryItem? month = await _quiet(_apiService.getTeacherMonth());

    if (!mounted || request != _monthRequest)
    {
      return;
    }

    setState(()
    {
      _month = month;
      _loadingMonth = false;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final MeResponse user = widget.user;
    final MobileTeacherDay? day = _day;
    final TeacherMonthSummaryItem? month = _month;

    return MobileHomeView(
      firstName: user.firstName,
      birthDate: user.birthDate,
      loadingDay: _loadingDay,
      day: day == null ? null : teacherHomeDay(day, feminine: user.gender == 'F'),
      loadingMonth: _loadingMonth,
      month: month == null ? null : MobileMonthFigures(month: month),
      onRefresh: _reload,
      pageController: _pageController,
    );
  }
}

