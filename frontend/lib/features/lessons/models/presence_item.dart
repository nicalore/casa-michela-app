import 'package:flutter/material.dart';

import '../../../core/utils/json_parsing.dart';
import 'booking_summary_item.dart';
import 'person_option_item.dart';

class PresenceItem
{
  final int id;
  final DateTime date;

  // In the building, or reachable at a screen. In the first the hours are when
  // the pupil is here; in the second they are when the pupil can be taught.
  final String mode;

  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String studentTaxCode;
  final PersonOptionItem student;
  final String bookerTaxCode;
  final PersonOptionItem booker;
  final List<BookingSummaryItem> bookings;
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
    required this.updatedAt,
  });

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
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
