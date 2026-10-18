import '../../../features/auth/models/me_response.dart';
import '../../../features/lessons/utils/calendar_jump.dart';
import '../../../features/notifications/notice_jump.dart';
import '../../../features/notifications/week_jump.dart';
import '../../../features/notifications/notification_item.dart';
import '../../../features/notifications/notification_roles.dart';
import '../../../features/settings/settings_jump.dart';
import '../../../services/api_service.dart';
import '../../shared/navigation/mobile_destinations.dart';
import '../shell/mobile_shell_requests.dart';

const String _calendarSlug = 'calendar';
const String _associationSlug = 'association';
const String _adminRole = 'ADMIN';
const String _parentRole = 'PARENT';
const String _studentRole = 'STUDENT';
const String _bookingsSlug = 'bookings';
const String _teacherRole = 'TEACHER';
const String _availabilitySlug = 'availability';

// A published calendar leads to the person's own, availabilities and bookings to their page; the
// administrator has no area here yet.
void followMobileNotification(NotificationItem item)
{
  final MeResponse? me = ApiService().identity.value;

  if (me == null)
  {
    return;
  }

  switch (item.kind)
  {
    case NotificationKind.calendarPublished:
    case NotificationKind.convocation:
      final DateTime? day = item.calendarDate;
      final band = item.calendarBand;
      final String? role = calendarRoleFor(me, kCalendarRoles[item.kind]!);

      if (day == null || band == null || role == null)
      {
        return;
      }

      CalendarJumps.role.request(day, band, role: role);
      MobileShellRequests.open(role, _calendarSlug);
    case NotificationKind.availabilityOpened:
    case NotificationKind.availabilityReminder:
      _openWeek(me, item, WeekJumps.availability, _availabilitySlug);
    case NotificationKind.bookingsOpened:
    case NotificationKind.bookingReminder:
      _openWeek(me, item, WeekJumps.bookings, _bookingsSlug);
    case NotificationKind.openingHoursChanged:
      final String? role = calendarRoleFor(me, kHoursRoles.where((role) => role != _adminRole).toList());

      if (role == null)
      {
        return;
      }

      WeekJumps.hours.request(item.calendarDate ?? DateTime.now(), role: role);
      MobileShellRequests.open(role, _associationSlug);
    case NotificationKind.bookingAdded:
    case NotificationKind.bookingCancelled:
    case NotificationKind.bookingChanged:
      final DateTime? day = item.calendarDate;
      final String? pupil = item.pupilTaxCode;

      if (day == null || pupil == null)
      {
        return;
      }

      final String role = pupil == me.taxCode ? _studentRole : _parentRole;

      if (!me.availableRoles.contains(role))
      {
        return;
      }

      WeekJumps.bookings.request(day, role: role, pupil: pupil);
      MobileShellRequests.open(role, _bookingsSlug);
    case NotificationKind.availabilityAdded:
    case NotificationKind.availabilityChanged:
    case NotificationKind.availabilityCancelled:
      final DateTime? day = item.calendarDate;

      if (day == null || !me.availableRoles.contains(_teacherRole))
      {
        return;
      }

      WeekJumps.availability.request(day, role: _teacherRole);
      MobileShellRequests.open(_teacherRole, _availabilitySlug);
    case NotificationKind.newDevice:
      SettingsJumps.requestDevices();
      MobileShellRequests.open(me.activeRole, kMobileSettingsSlug);
    case NotificationKind.noticeReceived:
      final int? id = item.noticeId;
      final String? role = calendarRoleFor(
        me,
        kNoticeRoles.where((role) => role != _adminRole && item.noticeRoles.contains(role)).toList(),
      );

      if (id == null || role == null)
      {
        return;
      }

      NoticeJumps.reading.request(id, role: role);
      MobileShellRequests.open(role, _associationSlug);
    case NotificationKind.reportReceived:
      final int? id = item.reportId;

      if (id != null)
      {
        MobileShellRequests.openReport(id);
      }
    // No person editing on the phone yet: a tap only reads it, which takes it away.
    case NotificationKind.ratingReminder:
    case NotificationKind.test:
    case NotificationKind.bookingsClosed:
    case NotificationKind.arrivalReminder:
    case NotificationKind.unknown:
      break;
  }
}

// On the week of the day it is about, the one it expires on.
void _openWeek(MeResponse me, NotificationItem item, WeekJumpChannel jumps, String slug)
{
  final String? role = calendarRoleFor(me, kWeekRoles[item.kind]!);

  if (role == null)
  {
    return;
  }

  jumps.request(item.expiresAt ?? DateTime.now(), role: role);
  MobileShellRequests.open(role, slug);
}
