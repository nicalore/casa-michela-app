import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/association/models/ministry_subject_item.dart';
import '../../../features/association/models/opening_day_item.dart';
import '../../../features/bookings/utils/booking_moves.dart';
import '../../../features/lessons/models/booking_summary_item.dart';
import '../../../features/lessons/models/presence_group.dart';
import '../../../features/lessons/models/presence_item.dart';
import '../../../features/lessons/utils/booking_window.dart';
import '../../../features/lessons/utils/opening_window.dart';
import '../../../features/lessons/widgets/booking_fields_section.dart' show bookingTagLabels;
import '../../../features/people/models/person_item.dart';

const List<String> kBookingModes = [kPresenceMode, kOnlineMode];

class MobileBookingLesson
{
  final PresenceItem slot;
  final BookingSummaryItem booking;

  final String title;

  // Only for a subject with several disciplines: one alone would repeat its name.
  final List<String> disciplines;

  final List<String> tags;
  final List<PersonItem> teachers;

  final bool closed;

  final bool editable;

  const MobileBookingLesson({
    required this.slot,
    required this.booking,
    required this.title,
    required this.disciplines,
    required this.tags,
    required this.teachers,
    required this.closed,
    required this.editable,
  });

  String? get topic => _said(booking.topic);

  String? get notes => _said(booking.notes);

  static String? _said(String? text)
  {
    final String? trimmed = text?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class MobileBookingMode
{
  final String mode;
  final TimeBucket band;

  final List<PresenceItem> slots;
  final List<MobileBookingLesson> lessons;

  final Set<int> closedSlotIds;

  final bool changeable;

  // Nothing past its deadline yet.
  final bool deletable;

  const MobileBookingMode({
    required this.mode,
    required this.band,
    required this.slots,
    required this.lessons,
    required this.closedSlotIds,
    required this.changeable,
    required this.deletable,
  });

  bool get hasClosed => closedSlotIds.isNotEmpty;

  bool get canAddLesson => changeable && slots.any((slot) => !isClosed(slot));

  bool isClosed(PresenceItem slot) => closedSlotIds.contains(slot.id);
}

// Mirrors the desktop row; [readOnly] leaves every action and lock out.
class MobileBookingDay
{
  final DateTime date;

  final bool isToday;
  final bool isPast;

  // No band opens in either mode.
  final bool isShut;

  final PresenceGroup? group;

  // One per mode and band: presence first, then by band.
  final List<MobileBookingMode> modes;

  final List<String> addable;

  const MobileBookingDay({
    required this.date,
    required this.isToday,
    required this.isPast,
    required this.isShut,
    required this.group,
    required this.modes,
    required this.addable,
  });

  bool get isEmpty => group == null;

  bool get isClosed => isShut && isEmpty;

  bool get canDeleteDay => modes.isNotEmpty && modes.every((mode) => mode.deletable);
}

bool _slotClosed(PresenceItem slot, DateTime day, DateTime now)
{
  final TimeBucket? band = bucketFor(slot.startTime);

  return band != null && haveBookingsClosed(day, band, now);
}

List<String> _disciplinesOf(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects)
{
  if (booking.kind != BookingRequestKind.ministrySubject)
  {
    return const [];
  }

  for (final subject in ministrySubjects)
  {
    if (subject.id == booking.ministrySubjectId && subject.associationSubjects.length <= 1)
    {
      return const [];
    }
  }

  return [for (final subject in booking.associationSubjects) subject.name];
}

MobileBookingDay bookingDay({
  required DateTime date,
  required DateTime now,
  required String pupilTaxCode,
  required BookingMovePlanner planner,
  required List<OpeningDayItem> openingDays,
  required List<MinistrySubjectItem> ministrySubjects,
  required List<PersonItem> teachers,
  bool readOnly = false,
})
{
  final DateTime today = DateTime(now.year, now.month, now.day);
  final PresenceGroup? group = planner.groupOn(date, pupilTaxCode);

  bool locked(PresenceItem slot) => !readOnly && _slotClosed(slot, date, now);

  MobileBookingLesson lesson(PresenceItem slot, BookingSummaryItem booking)
  {
    final bool closed = locked(slot);

    return MobileBookingLesson(
      slot: slot,
      booking: booking,
      title: bookingTitle(booking, ministrySubjects),
      disciplines: _disciplinesOf(booking, ministrySubjects),
      tags: bookingTagLabels(booking.tags),
      teachers: [
        for (final taxCode in booking.preferredTeacherTaxCodes)
          for (final teacher in teachers)
            if (teacher.fiscalCode == taxCode) teacher,
      ],
      closed: closed,
      editable: !readOnly && !closed,
    );
  }

  MobileBookingMode booked(PresenceGroup group, String mode, TimeBucket band)
  {
    final List<PresenceItem> slots = group.slotsFor(mode, band: band);
    final Set<int> closed = {
      for (final slot in slots)
        if (locked(slot)) slot.id,
    };

    return MobileBookingMode(
      mode: mode,
      band: band,
      slots: slots,
      lessons: [
        for (final slot in slots)
          for (final booking in slot.bookings) lesson(slot, booking),
      ],
      closedSlotIds: closed,
      changeable: !readOnly && !haveBookingsClosed(date, band, now),
      deletable: !readOnly && closed.isEmpty,
    );
  }

  final List<MobileBookingMode> modes = [
    if (group != null)
      for (final mode in kBookingModes)
        for (final band in group.bandsFor(mode)) booked(group, mode, band),
  ];

  bool free(String mode, TimeBucket band) =>
      !haveBookingsClosed(date, band, now) &&
      openingWindowFor(openingDays, date, mode, band) != null &&
      (group == null || kBookingModes.every((either) => group.slotsFor(either, band: band).isEmpty));

  return MobileBookingDay(
    date: date,
    isToday: isSameDate(date, today),
    isPast: date.isBefore(today),
    isShut: !TimeBucket.values.any((band) => unionOpeningWindow(openingDays, date, band) != null),
    group: group,
    modes: modes,
    addable: [
      for (final mode in kBookingModes)
        if (!readOnly && TimeBucket.values.any((band) => free(mode, band))) mode,
    ],
  );
}
