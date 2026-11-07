import '../core/utils/rome_clock.dart';
import '../features/home/home_link.dart';
import '../features/lessons/utils/calendar_jump.dart';
import '../features/notifications/week_jump.dart';
import '../features/people/person_jump.dart';
import '../shared/widgets/desktop_tour.dart';
import 'app_router.dart';

const String _teacherRole = 'TEACHER';

const String _availabilitySlug = 'availability';
const String _bookingsSlug = 'bookings';
const String _calendarSlug = 'calendar';
const String _childrenSlug = 'children';

// Where a band or a figure of the home leads on the desktop, the home being [role]'s.
void followHomeLink(HomeLink link, {required String role})
{
  if (isDesktopTourShown)
  {
    return;
  }

  final String home = homeForRole(role);

  switch (link)
  {
    case HomeCalendarLink(:final band):
      CalendarJumps.role.request(romeNow(), band, role: role);
      appRouter.go('$home/$_calendarSlug');
    case HomeWeekLink():
      final bool teacher = role == _teacherRole;

      (teacher ? WeekJumps.availability : WeekJumps.bookings).request(romeNow(), role: role);
      appRouter.go('$home/${teacher ? _availabilitySlug : _bookingsSlug}');
    case HomeStatsLink(:final pupil):
      if (pupil == null)
      {
        OwnPageJumps.requestStats();
        appRouter.go(ownPageForRole(role));
      }
      else
      {
        ChildStatsJumps.request(pupil);
        appRouter.go('$home/$_childrenSlug');
      }
  }
}
