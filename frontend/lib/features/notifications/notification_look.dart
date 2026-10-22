import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
      NotificationKind.test => const NotificationLook(Icons.notifications_active_rounded, AppTheme.trialViolet),
      NotificationKind.bookingsClosed => const NotificationLook(Icons.event_available_rounded, AppTheme.trialTealDeep),
      NotificationKind.calendarPublished => const NotificationLook(Icons.event_note_rounded, AppTheme.trialOcean),
      NotificationKind.convocation => const NotificationLook(Icons.how_to_reg_rounded, AppTheme.trialOcean),
      NotificationKind.arrivalReminder => const NotificationLook(Icons.watch_rounded, AppTheme.trialTealDeep),
      NotificationKind.availabilityOpened => const NotificationLook(Icons.edit_calendar_rounded, AppTheme.trialTealDeep),
      NotificationKind.bookingsOpened => const NotificationLook(Icons.bookmark_added_rounded, AppTheme.trialTealDeep),
      NotificationKind.availabilityReminder => const NotificationLook(Icons.alarm_rounded, AppTheme.trialTealDeep),
      NotificationKind.bookingReminder => const NotificationLook(Icons.alarm_rounded, AppTheme.trialTealDeep),
      NotificationKind.openingHoursChanged => const NotificationLook(Icons.schedule_rounded, AppTheme.trialOcean),
      NotificationKind.noticeReceived => const NotificationLook(Icons.campaign_rounded, AppTheme.trialOcean),
      NotificationKind.bookingAdded => const NotificationLook(Icons.playlist_add_check_rounded, AppTheme.trialOcean),
      NotificationKind.bookingCancelled => const NotificationLook(Icons.event_busy_rounded, AppTheme.trialOcean),
      NotificationKind.bookingChanged => const NotificationLook(Icons.edit_note_rounded, AppTheme.trialOcean),
      NotificationKind.availabilityAdded => const NotificationLook(Icons.more_time_rounded, AppTheme.trialTealDeep),
      NotificationKind.availabilityChanged => const NotificationLook(Icons.update_rounded, AppTheme.trialTealDeep),
      NotificationKind.availabilityCancelled => const NotificationLook(Icons.timer_off_rounded, AppTheme.trialTealDeep),
      NotificationKind.newDevice => const NotificationLook(Icons.devices_rounded, AppTheme.trialOcean),
      NotificationKind.reportReceived => const NotificationLook(Icons.flag_rounded, AppTheme.trialOcean),
      NotificationKind.ratingReminder => const NotificationLook(Icons.rate_review_rounded, AppTheme.trialTealDeep),
      NotificationKind.teacherNoteAdded => const NotificationLook(Icons.speaker_notes_rounded, AppTheme.trialOcean),
      NotificationKind.administratorNoteAdded => const NotificationLook(Icons.speaker_notes_rounded, AppTheme.trialOcean),
      NotificationKind.unknown => const NotificationLook(Icons.notifications_rounded, AppTheme.trialOcean),
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

  if (day == today.subtract(const Duration(days: 1)))
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
