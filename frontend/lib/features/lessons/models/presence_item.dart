import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import 'booking_summary_item.dart';
import 'person_option_item.dart';

class PresenceItem
{
  final int id;
  final DateTime date;

  final String mode;

  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String studentTaxCode;
  final PersonOptionItem student;
  final String bookerTaxCode;
  final PersonOptionItem booker;
  final List<BookingSummaryItem> bookings;

  // The pupil's standing list: left out of the offer when asking for teachers.
  final List<PersonOptionItem> notPreferredTeachers;

  // (booking id, teacher) the admin let through without the competence; admins only.
  final Set<(int, String)> competenceWaivers;

  final DateTime updatedAt;

  const PresenceItem({
    required this.id,
    required this.date,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.studentTaxCode,
    required this.student,
    required this.bookerTaxCode,
    required this.booker,
    required this.bookings,
    this.notPreferredTeachers = const [],
    this.competenceWaivers = const {},
    required this.updatedAt,
  });

  List<String> get notPreferredTeacherTaxCodes =>
      [for (final teacher in notPreferredTeachers) teacher.taxCode];

  // Mirrors the waivers the server records, so the next drop needs no round trip.
  PresenceItem waiving(Iterable<int> bookingIds, String teacherTaxCode)
  {
    final mine = [
      for (final id in bookingIds)
        if (bookings.any((booking) => booking.id == id)) id,
    ];

    if (mine.isEmpty)
    {
      return this;
    }

    return PresenceItem(
      id: id,
      date: date,
      mode: mode,
      startTime: startTime,
      endTime: endTime,
      studentTaxCode: studentTaxCode,
      student: student,
      bookerTaxCode: bookerTaxCode,
      booker: booker,
      bookings: bookings,
      notPreferredTeachers: notPreferredTeachers,
      competenceWaivers: {
        ...competenceWaivers,
        for (final id in mine) (id, teacherTaxCode),
      },
      updatedAt: updatedAt,
    );
  }

  factory PresenceItem.fromJson(Map<String, dynamic> json)
  {
    return PresenceItem(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      mode: json['mode'] as String,
      startTime: parseTimeOfDay(json['start_time']),
      endTime: parseTimeOfDay(json['end_time']),
      studentTaxCode: json['student_tax_code'] as String,
      student: PersonOptionItem.fromJson(json['student'] as Map<String, dynamic>),
      bookerTaxCode: json['booker_tax_code'] as String,
      booker: PersonOptionItem.fromJson(json['booker'] as Map<String, dynamic>),
      bookings: parseList(json['bookings'], BookingSummaryItem.fromJson),
      notPreferredTeachers: parseList(
        json['not_preferred_teachers'],
        PersonOptionItem.fromJson,
      ),
      competenceWaivers: parseList(
        json['competence_waivers'],
        (e) => (e['booking_id'] as int, e['teacher_tax_code'] as String),
      ).toSet(),
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
