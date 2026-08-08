import 'package:flutter/widgets.dart';

import '../../association/models/school_item.dart';
import '../models/membership_item.dart';
import '../../association/models/study_program_item.dart';

// The rows added and removed inside an edit dialog: one per membership, one per
// school year. Mutable models holding their own controllers, because a row of a
// list that grows cannot live in a field of the State.

// A membership, as the row editing it writes it. The year and the day sit in
// two separate fields, because the year is also the membership's identity, and
// asking for it inside a full date would mean asking twice.
class MembershipRowData
{
  // The server-side id, when the row comes from a membership that already
  // exists. Null for a freshly added row: the key is not sent on save.
  final int? id;

  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;

  // Carried along and never touched: this dialog changes the years, not the
  // fact that a membership was revoked. Hard-coded to 'NO' on save, as it used
  // to be, editing an expelled person's details readmitted them silently.
  final String revocation;

  MembershipRowData({
    this.id,
    required this.yearCtrl,
    required this.dateCtrl,
    this.revocation = MembershipItem.revocationNone,
  });

  factory MembershipRowData.empty({
    int? id,
    String year = '',
    String date = '',
    String revocation = MembershipItem.revocationNone,
  })
  {
    return MembershipRowData(
      id: id,
      yearCtrl: TextEditingController(text: year),
      dateCtrl: TextEditingController(text: date),
      revocation: revocation,
    );
  }

  void dispose()
  {
    yearCtrl.dispose();
    dateCtrl.dispose();
  }
}

// A school year: the starting year, the school, the programme and the class.
// The three choices cascade — changing the school clears programme and class,
// changing the programme clears the class — because a programme belongs to the
// school offering it and a class to the years the programme has.
class SchoolEnrollmentRowData
{
  final TextEditingController yearCtrl;

  SchoolItem? school;
  StudyProgramItem? program;

  // In Roman numerals, as the dropdown writes it: I, II, III…
  String? grade;

  SchoolEnrollmentRowData({
    required this.yearCtrl,
    this.school,
    this.program,
    this.grade,
  });

  factory SchoolEnrollmentRowData.empty({
    String year = '',
    SchoolItem? school,
    StudyProgramItem? program,
    String? grade,
  })
  {
    return SchoolEnrollmentRowData(
      yearCtrl: TextEditingController(text: year),
      school: school,
      program: program,
      grade: grade,
    );
  }

  void dispose()
  {
    yearCtrl.dispose();
  }
}
