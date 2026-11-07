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

// Roles with an "Associazione" to read the hours in; the administrator's is desktop-only.
const List<String> kHoursRoles = ['ADMIN', 'TEACHER', 'PARENT', 'STUDENT'];

// Roles with "Comunicazioni e avvisi" to read a notice in; the administrator's is desktop-only.
const List<String> kNoticeRoles = ['ADMIN', 'TEACHER', 'PARENT', 'STUDENT'];

// The roles whose home lists each kind; a kind not here is about the account, on every home.
const Map<NotificationKind, List<String>> _homeRoles = {
  ...kCalendarRoles,
  ...kWeekRoles,
  NotificationKind.bookingsClosed: ['ADMIN'],
  NotificationKind.reportReceived: ['ADMIN'],
  NotificationKind.ratingReminder: ['ADMIN'],
  NotificationKind.teacherNoteAdded: ['ADMIN'],
  NotificationKind.arrivalReminder: ['TEACHER'],
  NotificationKind.availabilityAdded: ['TEACHER'],
  NotificationKind.availabilityChanged: ['TEACHER'],
  NotificationKind.availabilityCancelled: ['TEACHER'],
  NotificationKind.administratorNoteAdded: ['TEACHER'],
  NotificationKind.openingHoursChanged: kHoursRoles,
};

// Whether the home of [role] lists it; a booking is the pupil's own or their parent's.
bool concernsRole(NotificationItem item, String role, {required String? taxCode})
{
  return switch (item.kind)
  {
    NotificationKind.noticeReceived => item.noticeRoles.contains(role),
    NotificationKind.bookingAdded ||
    NotificationKind.bookingCancelled ||
    NotificationKind.bookingChanged => role == (item.pupilTaxCode == taxCode ? 'STUDENT' : 'PARENT'),
    _ => _homeRoles[item.kind]?.contains(role) ?? true,
  };
}

// The active role if it is one of [roles], else the first of them the person holds.
String? calendarRoleFor(MeResponse me, List<String> roles)
{
  if (roles.contains(me.activeRole))
  {
    return me.activeRole;
  }

  return roles.where(me.availableRoles.contains).firstOrNull;
}
