import '../../../core/utils/rome_clock.dart';
import '../../../features/home/home_link.dart';
import '../../../features/lessons/utils/calendar_jump.dart';
import '../../../features/notifications/week_jump.dart';
import '../../../features/people/person_jump.dart';
import '../../shared/navigation/mobile_destinations.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../shell/mobile_shell_requests.dart';

const String _teacherRole = 'TEACHER';

const String _availabilitySlug = 'availability';
const String _bookingsSlug = 'bookings';
const String _calendarSlug = 'calendar';
const String _childrenSlug = 'children';

// Where a band or a figure of the home leads on mobile, the home being [role]'s.
void followMobileHomeLink(HomeLink link, {required String role})
{
  if (isMobileTourShown)
  {
    return;
  }

  switch (link)
  {
    case HomeCalendarLink(:final band, :final pupil):
      CalendarJumps.role.request(romeNow(), band, role: role, pupil: pupil);
      MobileShellRequests.open(role, _calendarSlug);
    case HomeWeekLink(:final pupil):
      final bool teacher = role == _teacherRole;

      (teacher ? WeekJumps.availability : WeekJumps.bookings).request(romeNow(), role: role, pupil: pupil);
      MobileShellRequests.open(role, teacher ? _availabilitySlug : _bookingsSlug);
    case HomeStatsLink(:final pupil):
      if (pupil == null)
      {
        OwnPageJumps.requestStats();
        MobileShellRequests.open(role, kMobileOwnPageSlug);
      }
      else
      {
        ChildStatsJumps.request(pupil);
        MobileShellRequests.open(role, _childrenSlug);
      }
  }
}
