import '../auth/models/me_response.dart';
import 'notification_item.dart';

// The roles whose calendar a notification of a published calendar opens.
const Map<NotificationKind, List<String>> kCalendarRoles = {
  NotificationKind.calendarPublished: ['PARENT', 'STUDENT'],
  NotificationKind.convocation: ['TEACHER'],
};

// The roles whose week page a notification about availabilities or bookings leads to.
const Map<NotificationKind, List<String>> kWeekRoles = {
  NotificationKind.availabilityOpened: ['TEACHER'],
  NotificationKind.bookingsOpened: ['PARENT', 'STUDENT'],
  NotificationKind.availabilityReminder: ['TEACHER'],
  NotificationKind.bookingReminder: ['PARENT', 'STUDENT'],
};

// The roles with an Associazione to read the hours in; the administrator's is on the desktop only.
const List<String> kHoursRoles = ['ADMIN', 'TEACHER', 'PARENT', 'STUDENT'];

// The roles with a Comunicazioni e avvisi to read a notice in; the administrator's is on the desktop only.
const List<String> kNoticeRoles = ['ADMIN', 'TEACHER', 'PARENT', 'STUDENT'];

// The active role if it is one of [roles], else the first of them the person holds.
String? calendarRoleFor(MeResponse me, List<String> roles)
{
  if (roles.contains(me.activeRole))
  {
    return me.activeRole;
  }

  return roles.where(me.availableRoles.contains).firstOrNull;
}
