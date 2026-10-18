import 'dart:async';


import '../core/utils/time_bucket.dart';
import '../features/auth/models/me_response.dart';
import '../features/lessons/utils/calendar_jump.dart';
import '../features/notifications/notice_jump.dart';
import '../features/settings/settings_jump.dart';
import '../features/notifications/week_jump.dart';
import '../features/notifications/notification_item.dart';
import '../features/notifications/notification_roles.dart';
import 'app_router.dart';

const String _adminRole = 'ADMIN';
const String _parentRole = 'PARENT';
const String _studentRole = 'STUDENT';
const String _teacherRole = 'TEACHER';
const String _calendarRoute = '/lessons';
const String _adminAssociationRoute = '/association';

const String _availabilitySlug = 'availability';
const String _bookingsSlug = 'bookings';

// Where a notification leads on the desktop; kinds with nowhere to go stay put.
void followNotification(NotificationItem item)
{
  switch (item.kind)
  {
    case NotificationKind.bookingsClosed:
      unawaited(_openCalendar(item.calendarDate, item.calendarBand));
    case NotificationKind.calendarPublished:
    case NotificationKind.convocation:
      unawaited(_openRoleCalendar(item));
    case NotificationKind.availabilityOpened:
    case NotificationKind.availabilityReminder:
      unawaited(_openWeek(item, WeekJumps.availability, _availabilitySlug));
    case NotificationKind.bookingsOpened:
    case NotificationKind.bookingReminder:
      unawaited(_openWeek(item, WeekJumps.bookings, _bookingsSlug));
    case NotificationKind.openingHoursChanged:
      unawaited(_openHours(item));
    case NotificationKind.noticeReceived:
      unawaited(_openNotice(item));
    case NotificationKind.bookingAdded:
    case NotificationKind.bookingCancelled:
    case NotificationKind.bookingChanged:
      unawaited(_openPupilBookings(item));
    case NotificationKind.availabilityAdded:
    case NotificationKind.availabilityChanged:
    case NotificationKind.availabilityCancelled:
      unawaited(_openOwnAvailability(item));
    case NotificationKind.newDevice:
      _openDevices();
    case NotificationKind.test:
    case NotificationKind.arrivalReminder:
    case NotificationKind.unknown:
      break;
  }
}

// The person's own calendar on the band it is about, switching to the role it concerns.
Future<void> _openRoleCalendar(NotificationItem item) async
{
  final DateTime? day = item.calendarDate;
  final TimeBucket? band = item.calendarBand;

  if (day == null || band == null)
  {
    return;
  }

  await _openAs(
    kCalendarRoles[item.kind] ?? const [],
    jump: (role) => CalendarJumps.role.request(day, band, role: role),
    route: (role) => '${homeForRole(role)}/calendar',
  );
}

// The Lezioni calendar on the band it is about, as administrator even from another role.
Future<void> _openCalendar(DateTime? day, TimeBucket? band) async
{
  if (day == null || band == null)
  {
    return;
  }

  await _openAs(
    const [_adminRole],
    jump: (_) => CalendarJumps.admin.request(day, band),
    route: (_) => _calendarRoute,
  );
}

// Disponibilità or Prenotazioni on the week of the day it is about, the one it expires on.
Future<void> _openWeek(NotificationItem item, WeekJumpChannel jumps, String slug)
{
  final DateTime day = item.expiresAt ?? DateTime.now();

  return _openAs(
    kWeekRoles[item.kind] ?? const [],
    jump: (role) => jumps.request(day, role: role),
    route: (role) => '${homeForRole(role)}/$slug',
  );
}

// The Associazione's Orari on the week of the first day changed.
Future<void> _openHours(NotificationItem item)
{
  final DateTime day = item.calendarDate ?? DateTime.now();

  return _openAs(
    kHoursRoles,
    jump: (role) => WeekJumps.hours.request(day, role: role),
    route: (role) => role == _adminRole ? _adminAssociationRoute : '${homeForRole(role)}/association',
  );
}

// Prenotazioni on the week of the first lesson booked, changed or cancelled, as the pupil or a parent of theirs.
Future<void> _openPupilBookings(NotificationItem item) async
{
  final DateTime? day = item.calendarDate;
  final String? pupil = item.pupilTaxCode;
  final MeResponse? me = apiService.identity.value;

  if (day == null || pupil == null || me == null)
  {
    return;
  }

  await _openAs(
    [pupil == me.taxCode ? _studentRole : _parentRole],
    jump: (role) => WeekJumps.bookings.request(day, role: role, pupil: pupil),
    route: (role) => '${homeForRole(role)}/$_bookingsSlug',
  );
}

// Disponibilità on the week of the first one someone else wrote.
Future<void> _openOwnAvailability(NotificationItem item) async
{
  final DateTime? day = item.calendarDate;

  if (day == null)
  {
    return;
  }

  await _openAs(
    const [_teacherRole],
    jump: (role) => WeekJumps.availability.request(day, role: role),
    route: (role) => '${homeForRole(role)}/$_availabilitySlug',
  );
}

// Impostazioni on Dispositivi, where a session not one's own is ended.
void _openDevices()
{
  final MeResponse? me = apiService.identity.value;

  if (me == null)
  {
    return;
  }

  SettingsJumps.requestDevices();
  appRouter.go(settingsPageForRole(me.activeRole));
}

// Comunicazioni e avvisi with the notice open, in a role it reached; administrators list every notice.
Future<void> _openNotice(NotificationItem item) async
{
  final int? id = item.noticeId;

  if (id == null)
  {
    return;
  }

  await _openAs(
    [for (final role in kNoticeRoles) if (role == _adminRole || item.noticeRoles.contains(role)) role],
    jump: (role) => NoticeJumps.reading.request(id, role: role),
    route: (role) => role == _adminRole ? _adminAssociationRoute : '${homeForRole(role)}/association',
  );
}

Future<void> _openAs(
  List<String> roles, {
  required void Function(String role) jump,
  required String Function(String role) route,
}) async
{
  final MeResponse? me = apiService.identity.value;
  final String? role = me == null ? null : calendarRoleFor(me, roles);

  if (me == null || role == null)
  {
    return;
  }

  if (me.activeRole != role)
  {
    try
    {
      await apiService.setActiveRole(role);
    }
    catch (_)
    {
      return;
    }
  }

  jump(role);
  appRouter.go(route(role));
}
