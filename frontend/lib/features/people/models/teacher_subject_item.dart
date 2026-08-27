class TeacherProgramItem
{
  final int id;
  final String name;
  final String? sector;
  final String level;

  const TeacherProgramItem({
    required this.id,
    required this.name,
    required this.level,
    this.sector,
  });

  factory TeacherProgramItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherProgramItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sector: json['sector'] as String?,
      level: json['level'] ?? '',
    );
  }

  String get fullName => sector == null ? name : '$sector | $name';
}

class TeacherSubjectItem
{
  final int subjectId;
  final String subjectName;
  final String subjectArea;

  final String? subjectDescription;

  final List<TeacherProgramItem> studyPrograms;

  const TeacherSubjectItem({
    required this.subjectId,
    required this.subjectName,
    required this.subjectArea,
    this.subjectDescription,
    required this.studyPrograms,
  });

  factory TeacherSubjectItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherSubjectItem(
      subjectId: json['subject_id'] ?? 0,
      subjectName: json['subject_name'] ?? '',
      subjectArea: json['subject_area'] ?? '',
      subjectDescription: json['subject_description'] as String?,
      studyPrograms: (json['study_programs'] as List<dynamic>?)
              ?.map((entry) => TeacherProgramItem.fromJson(entry as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  List<int> get studyProgramIds =>
      studyPrograms.map((program) => program.id).toList();
}
