import '../../association/models/subject_taxonomy.dart';

class TeacherProgramItem
{
  final int id;
  final String name;
  final String? sector;
  final String level;

  // Null where none exists: only high school is split into cycles.
  final String? highSchoolTrack;

  final int minYear;
  final int maxYear;

  const TeacherProgramItem({
    required this.id,
    required this.name,
    required this.level,
    this.sector,
    this.highSchoolTrack,
    required this.minYear,
    required this.maxYear,
  });

  factory TeacherProgramItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherProgramItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sector: json['sector'] as String?,
      level: json['level'] ?? '',
      highSchoolTrack: json['high_school_track'] as String?,
      minYear: json['min_year'] ?? 0,
      maxYear: json['max_year'] ?? 0,
    );
  }

  // Must stay identical to display_name on the backend.
  String get fullName
  {
    final List<String> parts = [
      ?sector,
      ?highSchoolTrackShortLabel(highSchoolTrack, minYear, maxYear),
    ];

    return parts.isEmpty ? name : '${parts.join(' · ')} | $name';
  }
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
