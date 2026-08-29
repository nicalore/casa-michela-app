import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

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
  ministrySubject('Materie ministeriali', 'materie ministeriali più richieste'),
  discipline('Discipline', 'discipline più richieste'),
  service('Servizi', 'servizi più richiesti');

  final String label;
  final String rankingTitle;

  const RequestedSubjectKind(this.label, this.rankingTitle);
}

class RequestedSubjectItem
{
  final String name;
  final int requestCount;

  // Share of its own kind over the period, counted over all entries, not just
  // the ones shown.
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
  final int totalPresenceDays;
  final List<StudentPresenceRankItem> topStudents;
  final RequestedSubjectRankings requested;

  const StudentPresenceStatisticsItem({
    required this.dailyAverage,
    required this.totalPresenceDays,
    required this.topStudents,
    required this.requested,
  });

  factory StudentPresenceStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return StudentPresenceStatisticsItem(
      dailyAverage: parseDouble(json['daily_average']),
      totalPresenceDays: json['total_presence_days'] as int,
      topStudents: parseList(json['top_students'], StudentPresenceRankItem.fromJson),
      requested: RequestedSubjectRankings.fromJson(json['requested'] as Map<String, dynamic>),
    );
  }
}
