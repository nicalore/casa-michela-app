import 'package:flutter/widgets.dart';

import '../../association/models/school_item.dart';
import '../models/membership_item.dart';
import '../../association/models/study_program_item.dart';

class MembershipRowData
{
  // Null for a freshly added row: the key is not sent on save.
  final int? id;

  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;

  // Carried along untouched: hard-coding 'NO' on save silently readmitted
  // expelled people.
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

class SchoolEnrollmentRowData
{
  final TextEditingController yearCtrl;

  SchoolItem? school;
  StudyProgramItem? program;

  // Roman numerals, as the dropdown writes it.
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
