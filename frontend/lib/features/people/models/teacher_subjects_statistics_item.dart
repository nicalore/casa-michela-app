class SubjectDistributionItem 
{
  final String name;
  final int    count;

  SubjectDistributionItem({required this.name, required this.count});

  factory SubjectDistributionItem.fromJson(Map<String, dynamic> json) 
  {
    return SubjectDistributionItem(name: json['name'], count: json['count']);
  }
}

class AreaDistributionItem 
{
  final String area;
  final int    count;
  final double percentage;

  AreaDistributionItem({required this.area, required this.count, required this.percentage});

  factory AreaDistributionItem.fromJson(Map<String, dynamic> json) 
  {
    return AreaDistributionItem(
      area:       json['area'], 
      count:      json['count'], 
      percentage: (json['percentage'] as num).toDouble()
    );
  }
}

class TeacherSubjectsStatisticsItem 
{
  final double                        avgSubjectsPerTeacher;
  final double                        avgTeachersPerSubject;
  final List<SubjectDistributionItem> top10Subjects;
  final List<SubjectDistributionItem> bottom10Subjects;
  final List<AreaDistributionItem>    areaDistribution;

  TeacherSubjectsStatisticsItem({
    required this.avgSubjectsPerTeacher,
    required this.avgTeachersPerSubject,
    required this.top10Subjects,
    required this.bottom10Subjects,
    required this.areaDistribution,
  });

  factory TeacherSubjectsStatisticsItem.fromJson(Map<String, dynamic> json) 
  {
    return TeacherSubjectsStatisticsItem(
      avgSubjectsPerTeacher: (json['avg_subjects_per_teacher'] as num).toDouble(),
      avgTeachersPerSubject: (json['avg_teachers_per_subject'] as num).toDouble(),
      top10Subjects:         (json['top_10_subjects'] as List).map((e) => SubjectDistributionItem.fromJson(e)).toList(),
      bottom10Subjects:      (json['bottom_10_subjects'] as List).map((e) => SubjectDistributionItem.fromJson(e)).toList(),
      areaDistribution:      (json['area_distribution'] as List).map((e) => AreaDistributionItem.fromJson(e)).toList(),
    );
  }
}