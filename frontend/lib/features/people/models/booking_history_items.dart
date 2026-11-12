import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/time_bucket.dart';

class BookingHistoryPerson
{
  final String taxCode;
  final String firstName;
  final String lastName;

  const BookingHistoryPerson({required this.taxCode, required this.firstName, required this.lastName});

  String get fullName => '$firstName $lastName';

  factory BookingHistoryPerson.fromJson(Map<String, dynamic> json)
  {
    return BookingHistoryPerson(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
    );
  }
}

class BookingHistoryLesson
{
  final int id;
  final BookingHistoryPerson teacher;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const BookingHistoryLesson({required this.id, required this.teacher, required this.startTime, required this.endTime});

  factory BookingHistoryLesson.fromJson(Map<String, dynamic> json)
  {
    return BookingHistoryLesson(
      id: json['id'] as int,
      teacher: BookingHistoryPerson.fromJson(json['teacher'] as Map<String, dynamic>),
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
    );
  }
}

enum BookingHistoryKind { subject, discipline, service }

class BookingHistoryBooking
{
  final int id;
  final BookingHistoryKind kind;

  // The disciplines or the service; the subject only where it says more.
  final String name;
  final String? subject;

  final int duration;
  final List<String> tags;
  final String? topic;

  // Lessons are known only once their band is published.
  final bool published;
  final List<BookingHistoryLesson> lessons;

  const BookingHistoryBooking({
    required this.id,
    required this.kind,
    required this.name,
    required this.subject,
    required this.duration,
    required this.tags,
    required this.topic,
    required this.published,
    required this.lessons,
  });

  factory BookingHistoryBooking.fromJson(Map<String, dynamic> json)
  {
    return BookingHistoryBooking(
      id: json['id'] as int,
      kind: switch (json['kind'])
      {
        'SERVICE' => BookingHistoryKind.service,
        'DISCIPLINE' => BookingHistoryKind.discipline,
        _ => BookingHistoryKind.subject,
      },
      name: json['name'] as String,
      subject: json['subject'] as String?,
      duration: json['duration'] as int,
      tags: parseStringList(json['tags']),
      topic: json['topic'] as String?,
      published: json['published'] as bool,
      lessons: parseList(json['lessons'], BookingHistoryLesson.fromJson),
    );
  }
}

// One presence: a mode's hours in a band, and who asked for them.
class BookingHistoryStretch
{
  final int id;
  final String mode;
  final TimeBucket band;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final BookingHistoryPerson booker;
  final DateTime bookedAt;
  final List<BookingHistoryBooking> bookings;

  const BookingHistoryStretch({
    required this.id,
    required this.mode,
    required this.band,
    required this.startTime,
    required this.endTime,
    required this.booker,
    required this.bookedAt,
    required this.bookings,
  });

  factory BookingHistoryStretch.fromJson(Map<String, dynamic> json)
  {
    return BookingHistoryStretch(
      id: json['id'] as int,
      mode: json['mode'] as String,
      band: switch (json['band'])
      {
        'MORNING' => TimeBucket.morning,
        'EVENING' => TimeBucket.evening,
        _ => TimeBucket.afternoon,
      },
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      booker: BookingHistoryPerson.fromJson(json['booker'] as Map<String, dynamic>),
      bookedAt: parseInstant(json['booked_at'])!,
      bookings: parseList(json['bookings'], BookingHistoryBooking.fromJson),
    );
  }
}

class BookingHistoryDay
{
  final DateTime date;
  final List<BookingHistoryStretch> stretches;

  const BookingHistoryDay({required this.date, required this.stretches});

  factory BookingHistoryDay.fromJson(Map<String, dynamic> json)
  {
    return BookingHistoryDay(
      date: DateTime.parse(json['date'] as String),
      stretches: parseList(json['stretches'], BookingHistoryStretch.fromJson),
    );
  }
}

class BookingHistoryMonth
{
  final int bookedDays;
  final int bookedMinutes;
  final int presenceMinutes;
  final int onlineMinutes;
  final List<BookingHistoryDay> days;

  const BookingHistoryMonth({
    required this.bookedDays,
    required this.bookedMinutes,
    required this.presenceMinutes,
    required this.onlineMinutes,
    required this.days,
  });

  factory BookingHistoryMonth.fromJson(Map<String, dynamic> json)
  {
    return BookingHistoryMonth(
      bookedDays: json['booked_days'] as int,
      bookedMinutes: json['booked_minutes'] as int,
      presenceMinutes: json['presence_minutes'] as int,
      onlineMinutes: json['online_minutes'] as int,
      days: parseList(json['days'], BookingHistoryDay.fromJson),
    );
  }
}
