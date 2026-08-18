import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../association/models/ministry_subject_item.dart';
import 'booking_summary_item.dart';
import 'person_option_item.dart';

// The room a teacher was put in for the day. Not [RoomItem]: that one insists
// on a created_at this does not carry.
class RoomOptionItem
{
  final int id;
  final String name;

  // Null where nobody measured, which is not a zero.
  final int? capacity;

  const RoomOptionItem({
    required this.id,
    required this.name,
    this.capacity,
  });

  factory RoomOptionItem.fromJson(Map<String, dynamic> json)
  {
    return RoomOptionItem(
      id: json['id'] as int,
      name: json['name'] as String,
      capacity: json['capacity'] as int?,
    );
  }
}

// What bounds a lesson on the pupil's side, as the availability does on the
// teacher's.
class LessonPresenceRef
{
  final int id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final PersonOptionItem student;

  const LessonPresenceRef({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.student,
  });

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  factory LessonPresenceRef.fromJson(Map<String, dynamic> json)
  {
    return LessonPresenceRef(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      student: PersonOptionItem.fromJson(json['student'] as Map<String, dynamic>),
    );
  }
}

// A booking as it hangs off a lesson. The server's BookingResponse is a
// BookingSummaryResponse plus two fields, so the object is read twice rather
// than restating fourteen fields. Composition for the same reason.
class LessonBookingItem
{
  final BookingSummaryItem booking;
  final int presenceId;
  final LessonPresenceRef presence;

  const LessonBookingItem({
    required this.booking,
    required this.presenceId,
    required this.presence,
  });

  int get id => booking.id;

  String get studentTaxCode => presence.student.taxCode;

  factory LessonBookingItem.fromJson(Map<String, dynamic> json)
  {
    return LessonBookingItem(
      booking: BookingSummaryItem.fromJson(json),
      presenceId: json['presence_id'] as int,
      presence: LessonPresenceRef.fromJson(json['presence'] as Map<String, dynamic>),
    );
  }
}

// One hour of the calendar: a teacher's availability spent on one or more
// bookings, over a subset of the disciplines they asked for.
class LessonItem
{
  final int id;

  // Three quarters of a composite foreign key on the server, so [date] and
  // [teacherMode] cannot drift from it.
  final int availabilityId;

  final String teacherTaxCode;
  final PersonOptionItem teacher;
  final DateTime date;

  // Where the teacher is, read from the availability.
  final String teacherMode;

  // What the hour is for the pupils, read from their presences. A teacher in
  // the building takes both; one connected from home can only take online.
  final String mode;

  // Computed by the database from [startTime]. Carried and not recomputed:
  // what the server published is what the server decided.
  final TimeBucket band;

  final TimeOfDay startTime;
  final TimeOfDay endTime;

  // The teacher's room for the whole day, not the lesson's own. Null while
  // nobody has assigned one, and for a teacher at home.
  final RoomOptionItem? room;

  final List<AssociationSubjectOption> disciplines;
  final List<LessonBookingItem> bookings;

  final bool isPublished;

  // Filled by a POST or PUT and empty on every read: a warning has no column to
  // live in, so it travels with the answer that raised it.
  final List<String> warnings;

  final DateTime createdAt;
  final DateTime updatedAt;

  const LessonItem({
    required this.id,
    required this.availabilityId,
    required this.teacherTaxCode,
    required this.teacher,
    required this.date,
    required this.teacherMode,
    required this.mode,
    required this.band,
    required this.startTime,
    required this.endTime,
    this.room,
    this.disciplines = const [],
    this.bookings = const [],
    this.isPublished = false,
    this.warnings = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  int get minutes => endMinutes - startMinutes;

  Set<int> get bookingIds => bookings.map((entry) => entry.id).toSet();

  Set<int> get disciplineIds => disciplines.map((subject) => subject.id).toSet();

  // Alphabetical and not as they arrived: an optimistic drawing and the
  // server's answer order them differently, and the hour would visibly reshuffle
  // a round trip after being moved.
  List<String> get disciplineNames
  {
    return disciplines.map((subject) => subject.name).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Set<String> get studentTaxCodes => bookings.map((entry) => entry.studentTaxCode).toSet();

  // The client's own drawing of an hour the server has not answered for yet, so
  // the calendar moves with the hand and not with the network. Its id is
  // negative: nothing that would reach the server may be done to one.
  bool get isProvisional => id < 0;

  // The same hour moved or stretched: a block let go after a drag has to be
  // where it was dropped now, not once a request has come back. [band] follows
  // [startTime] the way the database computes it.
  LessonItem copyWith({
    int? id,
    int? availabilityId,
    String? teacherTaxCode,
    PersonOptionItem? teacher,
    String? teacherMode,
    RoomOptionItem? room,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<AssociationSubjectOption>? disciplines,
  })
  {
    final start = startTime ?? this.startTime;

    return LessonItem(
      id: id ?? this.id,
      availabilityId: availabilityId ?? this.availabilityId,
      teacherTaxCode: teacherTaxCode ?? this.teacherTaxCode,
      teacher: teacher ?? this.teacher,
      date: date,
      teacherMode: teacherMode ?? this.teacherMode,
      mode: mode,
      band: bucketFor(start) ?? band,
      startTime: start,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      disciplines: disciplines ?? this.disciplines,
      bookings: bookings,
      isPublished: isPublished,
      warnings: warnings,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // The one place the frontend enum and the server's capitals meet.
  static TimeBucket parseBand(Object? value)
  {
    return switch (value as String)
    {
      'MORNING' => TimeBucket.morning,
      'AFTERNOON' => TimeBucket.afternoon,
      _ => TimeBucket.evening,
    };
  }

  static String formatBand(TimeBucket band)
  {
    return switch (band)
    {
      TimeBucket.morning => 'MORNING',
      TimeBucket.afternoon => 'AFTERNOON',
      TimeBucket.evening => 'EVENING',
    };
  }

  factory LessonItem.fromJson(Map<String, dynamic> json)
  {
    final room = json['room'];

    return LessonItem(
      id: json['id'] as int,
      availabilityId: json['availability_id'] as int,
      teacherTaxCode: json['teacher_tax_code'] as String,
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      date: DateTime.parse(json['date'] as String),
      teacherMode: json['teacher_mode'] as String,
      mode: json['mode'] as String,
      band: parseBand(json['band']),
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      room: room == null ? null : RoomOptionItem.fromJson(room as Map<String, dynamic>),
      disciplines: parseList(
        json['disciplines'],
        (e) => AssociationSubjectOption.fromJson(e),
      ),
      bookings: parseList(json['bookings'], LessonBookingItem.fromJson),
      isPublished: json['is_published'] as bool? ?? false,
      warnings: parseStringList(json['warnings']),
      createdAt: parseInstant(json['created_at'])!,
      // parseInstant forces UTC: without it the round trip loses the offset
      // and every second save answers 409.
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
