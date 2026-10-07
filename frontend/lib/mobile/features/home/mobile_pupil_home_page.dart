import 'package:flutter/material.dart';

import '../../../core/utils/rome_clock.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/home/models/month_summary_items.dart';
import '../../../features/home/widgets/home_month_section.dart';
import '../../../features/home/widgets/role_home_layout.dart';
import '../../../features/lessons/models/calendar_publication_item.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/people/models/person_item.dart';
import '../../../services/api_service.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import 'mobile_home_day.dart';
import 'mobile_home_view.dart';
import 'mobile_parent_home_view.dart';
import 'mobile_pupil_day.dart';
import 'widgets/mobile_child_cards.dart';
import 'widgets/mobile_month_figures.dart';

// Failures become null so one bad call does not fail the whole day.
Future<T?> _quiet<T>(Future<T> future)
{
  return future.then<T?>((value) => value).catchError((_) => null);
}

class MobilePupilHomePage extends StatefulWidget
{
  final String role;

  // Kept past sign-out: the shell clears the identity before the page leaves.
  final MeResponse user;

  const MobilePupilHomePage({super.key, required this.role, required this.user});

  @override
  State<MobilePupilHomePage> createState() => _MobilePupilHomePageState();
}

class _MobilePupilHomePageState extends State<MobilePupilHomePage>
{
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  bool _loadingDay = true;
  bool _loadingMonth = true;

  MobileHomeDay? _day;
  List<HomeFigure>? _figures;

  MobileParentDay? _children;
  List<MobileChildMonth>? _childMonths;

  // Bumped on every fetch so a stale response is dropped.
  int _dayRequest = 0;
  int _monthRequest = 0;

  bool get _isParent => widget.role == kParentRole;

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

  // Any failed reading leaves the day null ("unknown"), distinct from a closed day.
  Future<void> _loadDay() async
  {
    final int request = ++_dayRequest;
    final String taxCode = widget.user.taxCode;

    final DateTime now = romeNow();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Future<List<OpeningDayItem>?> inBuildingFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kPresenceMode));
    final Future<List<OpeningDayItem>?> onScreenFuture =
        _quiet(_apiService.getOpeningDays(dateFrom: today, dateTo: today, mode: kOnlineMode));
    final Future<List<CalendarPublicationItem>?> publicationsFuture =
        _quiet(_apiService.getCalendarPublications(dateFrom: today, dateTo: today));
    final Future<List<PresenceItem>?> presencesFuture =
        _quiet(_apiService.getPresences(dateFrom: today, dateTo: today));

    final Future<PersonItem?> readerFuture = _isParent
        ? _quiet(_apiService.getPerson(taxCode))
        : Future.value(null);

    final inBuilding = await inBuildingFuture;
    final onScreen = await onScreenFuture;
    final publications = await publicationsFuture;
    final presences = await presencesFuture;
    final reader = await readerFuture;

    if (!mounted || request != _dayRequest)
    {
      return;
    }

    MobileHomeDay? day;
    MobileParentDay? children;

    if (inBuilding != null && onScreen != null && publications != null && presences != null)
    {
      final List<OpeningDayItem> openingDays = [...inBuilding, ...onScreen];

      if (!_isParent)
      {
        // The server scopes by role, so an administrator would also get everybody's presences.
        day = pupilHomeDay(
          day: today,
          openingDays: openingDays,
          publications: publications,
          presences: presences.where((presence) => presence.studentTaxCode == taxCode).toList(),
        );
      }
      else if (reader != null)
      {
        children = parentHomeDay(
          day: today,
          openingDays: openingDays,
          publications: publications,
          presences: presences,
          children: [for (final child in reader.children ?? const []) (child, child.fiscalCode)],
        );
      }
    }

    setState(()
    {
      _day = day;
      _children = children;
      _loadingDay = false;
    });
  }

  Future<void> _loadMonth() async
  {
    final int request = ++_monthRequest;

    List<HomeFigure>? figures;
    List<MobileChildMonth>? childMonths;

    if (_isParent)
    {
      final ParentMonthSummaryItem? month = await _quiet(_apiService.getParentMonth());

      childMonths = month == null
          ? null
          : [
              for (final child in month.children)
                MobileChildMonth(
                  face: child.student,
                  taxCode: child.student.taxCode,
                  figures: pupilFigures(child, withTariff: true),
                ),
            ];
    }
    else
    {
      final StudentMonthSummaryItem? month = await _quiet(_apiService.getStudentMonth());

      figures = month == null
          ? null
          : pupilFigures(month.figures, withTariff: !month.hasParentalResponsibility);
    }

    if (!mounted || request != _monthRequest)
    {
      return;
    }

    setState(()
    {
      _figures = figures;
      _childMonths = childMonths;
      _loadingMonth = false;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final MeResponse user = widget.user;

    if (_isParent)
    {
      return MobileParentHomeView(
        firstName: user.firstName,
        birthDate: user.birthDate,
        loadingDay: _loadingDay,
        day: _children,
        loadingMonth: _loadingMonth,
        month: _childMonths,
        onRefresh: _reload,
        pageController: _pageController,
      );
    }

    final List<HomeFigure>? figures = _figures;

    return MobileHomeView(
      firstName: user.firstName,
      birthDate: user.birthDate,
      loadingDay: _loadingDay,
      day: _day,
      loadingMonth: _loadingMonth,
      month: figures == null ? null : MobilePupilMonthFigures(figures: figures),
      onRefresh: _reload,
      pageController: _pageController,
    );
  }
}
