import '../../../core/language/app_language.dart';
import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';
import 'personal_statistics_items.dart';

class StudentPresenceRankItem
{
  final PersonOptionItem student;
  final int presenceDays;

  const StudentPresenceRankItem({
    required this.student,
    required this.presenceDays,
  });

  factory StudentPresenceRankItem.fromJson(Map<String, dynamic> json)
  {
    return StudentPresenceRankItem(
      student: PersonOptionItem.fromJson(json['student'] as Map<String, dynamic>),
      presenceDays: json['presence_days'] as int,
    );
  }
}

enum RequestedSubjectKind
{
  ministrySubject,
  discipline,
  service;

  String get label => switch (this)
  {
    ministrySubject => tr('Materie', 'Subjects'),
    discipline => tr('Discipline', 'Disciplines'),
    service => tr('Servizi', 'Services'),
  };

  String get rankingTitle => switch (this)
  {
    ministrySubject => tr('materie più richieste', 'most requested subjects'),
    discipline => tr('discipline più richieste', 'most requested disciplines'),
    service => tr('servizi più richiesti', 'most requested services'),
  };

  String get hoursTitle => switch (this)
  {
    ministrySubject => tr('materie con più ore', 'subjects with the most hours'),
    discipline => tr('discipline con più ore', 'disciplines with the most hours'),
    service => tr('servizi con più ore', 'services with the most hours'),
  };
}

class RequestedSubjectItem
{
  final String name;
  final int requestCount;

  // Share over all entries in the period, not just the ones shown.
  final double percentage;

  const RequestedSubjectItem({
    required this.name,
    required this.requestCount,
    required this.percentage,
  });

  factory RequestedSubjectItem.fromJson(Map<String, dynamic> json)
  {
    return RequestedSubjectItem(
      name: json['name'] as String,
      requestCount: json['request_count'] as int,
      percentage: parseDouble(json['percentage']),
    );
  }
}

class RequestedSubjectRankings
{
  final List<RequestedSubjectItem> ministrySubjects;
  final List<RequestedSubjectItem> disciplines;
  final List<RequestedSubjectItem> services;

  const RequestedSubjectRankings({
    required this.ministrySubjects,
    required this.disciplines,
    required this.services,
  });

  List<RequestedSubjectItem> of(RequestedSubjectKind kind)
  {
    return switch (kind)
    {
      RequestedSubjectKind.ministrySubject => ministrySubjects,
      RequestedSubjectKind.discipline => disciplines,
      RequestedSubjectKind.service => services,
    };
  }

  factory RequestedSubjectRankings.fromJson(Map<String, dynamic> json)
  {
    return RequestedSubjectRankings(
      ministrySubjects: parseList(json['ministry_subjects'], RequestedSubjectItem.fromJson),
      disciplines: parseList(json['disciplines'], RequestedSubjectItem.fromJson),
      services: parseList(json['services'], RequestedSubjectItem.fromJson),
    );
  }
}

class StudentPresenceStatisticsItem
{
  // Averaged over days with at least one presence, not over every calendar day.
  final double dailyAverage;

  // Students with at least one presence in the period.
  final int studentCount;
  final List<StudentPresenceRankItem> topStudents;
  final List<PersonHoursItem> topStudentsByHours;
  final RequestedSubjectRankings requested;

  const StudentPresenceStatisticsItem({
    required this.dailyAverage,
    required this.studentCount,
    required this.topStudents,
    required this.topStudentsByHours,
    required this.requested,
  });

  factory StudentPresenceStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return StudentPresenceStatisticsItem(
      dailyAverage: parseDouble(json['daily_average']),
      studentCount: json['student_count'] as int,
      topStudents: parseList(json['top_students'], StudentPresenceRankItem.fromJson),
      topStudentsByHours: parseList(json['top_students_by_hours'], PersonHoursItem.fromJson),
      requested: RequestedSubjectRankings.fromJson(json['requested'] as Map<String, dynamic>),
    );
  }
}
