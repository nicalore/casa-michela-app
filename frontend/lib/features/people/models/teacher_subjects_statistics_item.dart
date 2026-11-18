import '../../../core/utils/json_parsing.dart';
import '../../lessons/models/person_option_item.dart';

class SubjectDistributionItem
{
  final String name;
  final String? programName;
  final int count;

  const SubjectDistributionItem({required this.name, this.programName, required this.count});

  factory SubjectDistributionItem.fromJson(Map<String, dynamic> json)
  {
    return SubjectDistributionItem(
      name: json['name'],
      programName: json['program_name'],
      count: json['count'],
    );
  }
}

class AreaDistributionItem
{
  final String area;
  final int count;
  final double percentage;

  const AreaDistributionItem({
    required this.area,
    required this.count,
    required this.percentage,
  });

  factory AreaDistributionItem.fromJson(Map<String, dynamic> json)
  {
    return AreaDistributionItem(
      area: json['area'],
      count: json['count'],
      percentage: parseDouble(json['percentage']),
    );
  }
}

// Count of disciplines, or of discipline and programme pairs, as ranked.
class TeacherCompetenceRankItem
{
  final PersonOptionItem teacher;
  final int count;

  const TeacherCompetenceRankItem({required this.teacher, required this.count});

  factory TeacherCompetenceRankItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherCompetenceRankItem(
      teacher: PersonOptionItem.fromJson(json['teacher'] as Map<String, dynamic>),
      count: json['count'],
    );
  }
}

class TeacherSubjectsStatisticsItem
{
  final double avgSubjectsPerTeacher;
  final double avgTeachersPerSubject;
  final int uncoveredSubjects;
  final List<TeacherCompetenceRankItem> top10Teachers;
  final List<SubjectDistributionItem> top10Subjects;

  // All of them, by name.
  final List<SubjectDistributionItem> subjectsWithoutTeachers;
  final List<AreaDistributionItem> areaDistribution;

  const TeacherSubjectsStatisticsItem({
    required this.avgSubjectsPerTeacher,
    required this.avgTeachersPerSubject,
    required this.uncoveredSubjects,
    required this.top10Teachers,
    required this.top10Subjects,
    required this.subjectsWithoutTeachers,
    required this.areaDistribution,
  });

  factory TeacherSubjectsStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherSubjectsStatisticsItem(
      avgSubjectsPerTeacher: parseDouble(json['avg_subjects_per_teacher']),
      avgTeachersPerSubject: parseDouble(json['avg_teachers_per_subject']),
      uncoveredSubjects: json['uncovered_subjects'],
      top10Teachers: parseList(json['top_10_teachers'], TeacherCompetenceRankItem.fromJson),
      top10Subjects: parseList(json['top_10_subjects'], SubjectDistributionItem.fromJson),
      subjectsWithoutTeachers: parseList(json['subjects_without_teachers'], SubjectDistributionItem.fromJson),
      areaDistribution: parseList(json['area_distribution'], AreaDistributionItem.fromJson),
    );
  }
}