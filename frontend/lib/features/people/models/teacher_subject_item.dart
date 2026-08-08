// A programme a teacher is competent on. Broken into parts rather than the
// single composed name, so the programmes can be grouped under their level and
// their sector, which is the only way to read twenty of them.
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

  // The full name, sector included: needed where the programme is named on its
  // own, outside the group that would say the sector for it.
  String get fullName => sector == null ? name : '$sector | $name';
}

class TeacherSubjectItem
{
  final int subjectId;
  final String subjectName;
  final String subjectArea;

  // What the discipline is, where somebody wrote it: the same text read in the
  // catalogue, carried here because this is where one meets it.
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
