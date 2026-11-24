import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/week_range.dart';
import '../association/notices/notice_format.dart';
import 'notification_item.dart';
import 'notification_strings.dart';

class NotificationLook
{
  final IconData icon;
  final Color color;

  const NotificationLook(this.icon, this.color);

  factory NotificationLook.of(NotificationKind kind)
  {
    return switch (kind)
    {
      NotificationKind.test => NotificationLook(Icons.notifications_active_rounded, AppTheme.trialVioletText),
      NotificationKind.bookingsClosed => NotificationLook(Icons.event_available_rounded, AppTheme.trialTealDeepText),
      NotificationKind.calendarPublished => NotificationLook(Icons.event_note_rounded, AppTheme.trialOceanText),
      NotificationKind.convocation => NotificationLook(Icons.how_to_reg_rounded, AppTheme.trialOceanText),
      NotificationKind.arrivalReminder => NotificationLook(Icons.watch_rounded, AppTheme.trialTealDeepText),
      NotificationKind.availabilityOpened => NotificationLook(Icons.edit_calendar_rounded, AppTheme.trialTealDeepText),
      NotificationKind.bookingsOpened => NotificationLook(Icons.bookmark_added_rounded, AppTheme.trialTealDeepText),
      NotificationKind.availabilityReminder => NotificationLook(Icons.alarm_rounded, AppTheme.trialTealDeepText),
      NotificationKind.bookingReminder => NotificationLook(Icons.alarm_rounded, AppTheme.trialTealDeepText),
      NotificationKind.openingHoursChanged => NotificationLook(Icons.schedule_rounded, AppTheme.trialOceanText),
      NotificationKind.noticeReceived => NotificationLook(Icons.campaign_rounded, AppTheme.trialOceanText),
      NotificationKind.bookingAdded => NotificationLook(Icons.playlist_add_check_rounded, AppTheme.trialOceanText),
      NotificationKind.bookingCancelled => NotificationLook(Icons.event_busy_rounded, AppTheme.trialOceanText),
      NotificationKind.bookingChanged => NotificationLook(Icons.edit_note_rounded, AppTheme.trialOceanText),
      NotificationKind.availabilityAdded => NotificationLook(Icons.more_time_rounded, AppTheme.trialTealDeepText),
      NotificationKind.availabilityChanged => NotificationLook(Icons.update_rounded, AppTheme.trialTealDeepText),
      NotificationKind.availabilityCancelled => NotificationLook(Icons.timer_off_rounded, AppTheme.trialTealDeepText),
      NotificationKind.newDevice => NotificationLook(Icons.devices_rounded, AppTheme.trialOceanText),
      NotificationKind.reportReceived => NotificationLook(Icons.flag_rounded, AppTheme.trialOceanText),
      NotificationKind.ratingReminder => NotificationLook(Icons.rate_review_rounded, AppTheme.trialTealDeepText),
      NotificationKind.teacherNoteAdded => NotificationLook(Icons.speaker_notes_rounded, AppTheme.trialOceanText),
      NotificationKind.administratorNoteAdded => NotificationLook(Icons.speaker_notes_rounded, AppTheme.trialOceanText),
      NotificationKind.volunteeringChanged => NotificationLook(Icons.volunteer_activism_rounded, AppTheme.trialTealDeepText),
      NotificationKind.paymentReceiptAvailable => NotificationLook(Icons.receipt_long_rounded, AppTheme.trialOceanText),
      NotificationKind.unknown => NotificationLook(Icons.notifications_rounded, AppTheme.trialOceanText),
    };
  }
}

// The hour today, "Ieri", then the day.
String notificationWhen(DateTime instant, {required DateTime now})
{
  final DateTime day = DateUtils.dateOnly(instant);
  final DateTime today = DateUtils.dateOnly(now);

  if (day == today)
  {
    return noticeHour(instant);
  }

  // On the calendar: the day after a clock change, 24 hours back is not midnight.
  if (day == addDays(today, -1))
  {
    return kNotificationsYesterday;
  }

  return noticeShortDay(instant, today: now);
}

class NotificationIcon extends StatelessWidget
{
  final NotificationKind kind;
  final bool unread;
  final double size;
  final Color surface;

  const NotificationIcon({
    super.key,
    required this.kind,
    required this.unread,
    required this.size,
    required this.surface,
  });

  @override
  Widget build(BuildContext context)
  {
    final NotificationLook look = NotificationLook.of(kind);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.trialGold.withValues(alpha: unread ? 1 : 0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.trialGold.withValues(alpha: unread ? 0.55 : 0),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(look.icon, size: size * 0.55, color: look.color),
    );
  }
}
