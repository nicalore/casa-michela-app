import '../../core/utils/json_parsing.dart';
import '../../core/utils/time_bucket.dart';

// Mirrors NotificationKindEnum in backend/app/models/notification.py.
enum NotificationKind
{
  test,
  bookingsClosed,
  calendarPublished,
  convocation,
  arrivalReminder,
  availabilityOpened,
  bookingsOpened,
  availabilityReminder,
  bookingReminder,
  openingHoursChanged,
  noticeReceived,
  bookingAdded,
  bookingCancelled,
  bookingChanged,
  availabilityAdded,
  availabilityChanged,
  availabilityCancelled,
  newDevice,
  reportReceived,
  ratingReminder,
  teacherNoteAdded,
  administratorNoteAdded,
  unknown,
}

const Map<NotificationKind, String> _kindCodes = {
  NotificationKind.test: 'TEST',
  NotificationKind.bookingsClosed: 'BOOKINGS_CLOSED',
  NotificationKind.calendarPublished: 'CALENDAR_PUBLISHED',
  NotificationKind.convocation: 'CONVOCATION',
  NotificationKind.arrivalReminder: 'ARRIVAL_REMINDER',
  NotificationKind.availabilityOpened: 'AVAILABILITY_OPENED',
  NotificationKind.bookingsOpened: 'BOOKINGS_OPENED',
  NotificationKind.availabilityReminder: 'AVAILABILITY_REMINDER',
  NotificationKind.bookingReminder: 'BOOKING_REMINDER',
  NotificationKind.openingHoursChanged: 'OPENING_HOURS_CHANGED',
  NotificationKind.noticeReceived: 'NOTICE_RECEIVED',
  NotificationKind.bookingAdded: 'BOOKING_ADDED',
  NotificationKind.bookingCancelled: 'BOOKING_CANCELLED',
  NotificationKind.bookingChanged: 'BOOKING_CHANGED',
  NotificationKind.availabilityAdded: 'AVAILABILITY_ADDED',
  NotificationKind.availabilityChanged: 'AVAILABILITY_CHANGED',
  NotificationKind.availabilityCancelled: 'AVAILABILITY_CANCELLED',
  NotificationKind.newDevice: 'NEW_DEVICE',
  NotificationKind.reportReceived: 'REPORT_RECEIVED',
  NotificationKind.ratingReminder: 'RATING_REMINDER',
  NotificationKind.teacherNoteAdded: 'TEACHER_NOTE_ADDED',
  NotificationKind.administratorNoteAdded: 'ADMINISTRATOR_NOTE_ADDED',
};

NotificationKind _kindOf(Object? value)
{
  return _kindCodes.entries.where((entry) => entry.value == value).firstOrNull?.key ?? NotificationKind.unknown;
}

// A kind the account may turn on or off, and whether it is on; the choice holds on every device.
class NotificationKindChoice
{
  final NotificationKind kind;
  final bool enabled;

  const NotificationKindChoice(this.kind, {required this.enabled});

  factory NotificationKindChoice.fromJson(Map<String, dynamic> json)
  {
    return NotificationKindChoice(_kindOf(json['kind']), enabled: json['enabled'] == true);
  }

  Map<String, Object?> toJson() => {'kind': _kindCodes[kind], 'enabled': enabled};

  NotificationKindChoice turned(bool on) => NotificationKindChoice(kind, enabled: on);
}

TimeBucket? _bandOf(Object? value)
{
  return switch (value)
  {
    'MORNING' => TimeBucket.morning,
    'AFTERNOON' => TimeBucket.afternoon,
    'EVENING' => TimeBucket.evening,
    _ => null,
  };
}

class NotificationItem
{
  final int id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  // The desktop's wording where it differs: "Clicca" for the phone's "Tocca".
  final String? webBody;

  // The calendar band it is about, or just its first day, for kinds about one.
  final DateTime? calendarDate;
  final TimeBucket? calendarBand;

  // Gone by itself at this moment, for kinds that only hold until then.
  final DateTime? expiresAt;

  // The notice it announces, and the reader's roles it reached, whose pages list it.
  final int? noticeId;
  final List<String> noticeRoles;

  // The pupil whose bookings or teacher's note it is about.
  final String? pupilTaxCode;

  final int? reportId;

  // The teacher whose rating it asks to update.
  final String? teacherTaxCode;

  // The teacher's note it announces.
  final int? teacherNoteId;

  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.calendarDate,
    this.calendarBand,
    this.webBody,
    this.expiresAt,
    this.noticeId,
    this.noticeRoles = const [],
    this.pupilTaxCode,
    this.reportId,
    this.teacherTaxCode,
    this.teacherNoteId,
  });

  String get desktopBody => webBody ?? body;

  bool hasExpired(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);

  factory NotificationItem.fromJson(Map<String, dynamic> json)
  {
    return NotificationItem(
      id: json['id'] as int,
      kind: _kindOf(json['kind']),
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      read: json['read_at'] != null,
      calendarDate: parseDate(json['calendar_date']),
      calendarBand: _bandOf(json['calendar_band']),
      webBody: json['web_body'] as String?,
      expiresAt: parseInstant(json['expires_at'])?.toLocal(),
      noticeId: json['notice_id'] as int?,
      noticeRoles: [for (final role in json['notice_roles'] as List<dynamic>? ?? const []) role as String],
      pupilTaxCode: json['pupil_tax_code'] as String?,
      reportId: json['report_id'] as int?,
      teacherTaxCode: json['teacher_tax_code'] as String?,
      teacherNoteId: json['teacher_note_id'] as int?,
    );
  }

  NotificationItem asRead() => NotificationItem(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        read: true,
        calendarDate: calendarDate,
        calendarBand: calendarBand,
        webBody: webBody,
        expiresAt: expiresAt,
        noticeId: noticeId,
        noticeRoles: noticeRoles,
        pupilTaxCode: pupilTaxCode,
        reportId: reportId,
        teacherTaxCode: teacherTaxCode,
        teacherNoteId: teacherNoteId,
      );
}

// A browser's push subscription, or an app's token with no keys.
class PushAddress
{
  final String platform;
  final String address;
  final String? p256dh;
  final String? auth;

  const PushAddress({required this.platform, required this.address, this.p256dh, this.auth});

  Map<String, Object?> toJson() => {
        'platform': platform,
        'address': address,
        if (p256dh != null) 'p256dh': p256dh,
        if (auth != null) 'auth': auth,
      };
}
