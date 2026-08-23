import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';
import '../../association/models/ministry_subject_item.dart';
import 'booking_summary_item.dart';
import 'person_option_item.dart';

class RoomOptionItem
{
  final int id;
  final String name;

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

class LessonItem
{
  final int id;

  final int availabilityId;

  final String teacherTaxCode;
  final PersonOptionItem teacher;
  final DateTime date;

  final String teacherMode;

  final String mode;

  final TimeBucket band;

  final TimeOfDay startTime;
  final TimeOfDay endTime;

  final RoomOptionItem? room;

  final List<AssociationSubjectOption> disciplines;
  final List<LessonBookingItem> bookings;

  final bool isLocked;

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
    this.isLocked = false,
    this.warnings = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get startMinutes => minutesOfTimeOfDay(startTime);

  int get endMinutes => minutesOfTimeOfDay(endTime);

  int get minutes => endMinutes - startMinutes;

  Set<int> get bookingIds => bookings.map((entry) => entry.id).toSet();

  Set<int> get disciplineIds => disciplines.map((subject) => subject.id).toSet();

  List<String> get disciplineNames
  {
    return disciplines.map((subject) => subject.name).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Set<String> get studentTaxCodes => bookings.map((entry) => entry.studentTaxCode).toSet();

  bool get isProvisional => id < 0;

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
      isLocked: isLocked,
      warnings: warnings,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

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
      isLocked: json['is_locked'] as bool? ?? false,
      warnings: parseStringList(json['warnings']),
      createdAt: parseInstant(json['created_at'])!,
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
