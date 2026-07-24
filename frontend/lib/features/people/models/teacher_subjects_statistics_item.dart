import '../../../core/utils/json_parsing.dart';

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

class TeacherSubjectsStatisticsItem
{
  final double avgSubjectsPerTeacher;
  final double avgTeachersPerSubject;
  final List<SubjectDistributionItem> top10Subjects;
  final List<SubjectDistributionItem> bottom10Subjects;
  final List<AreaDistributionItem> areaDistribution;

  const TeacherSubjectsStatisticsItem({
    required this.avgSubjectsPerTeacher,
    required this.avgTeachersPerSubject,
    required this.top10Subjects,
    required this.bottom10Subjects,
    required this.areaDistribution,
  });

  factory TeacherSubjectsStatisticsItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherSubjectsStatisticsItem(
      avgSubjectsPerTeacher: parseDouble(json['avg_subjects_per_teacher']),
      avgTeachersPerSubject: parseDouble(json['avg_teachers_per_subject']),
      top10Subjects: parseList(json['top_10_subjects'], SubjectDistributionItem.fromJson),
      bottom10Subjects: parseList(json['bottom_10_subjects'], SubjectDistributionItem.fromJson),
      areaDistribution: parseList(json['area_distribution'], AreaDistributionItem.fromJson),
    );
  }
}