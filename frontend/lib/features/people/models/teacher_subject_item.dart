import '../../../core/utils/json_parsing.dart';

class TeacherSubjectItem
{
  final int subjectId;
  final String subjectName;
  final String subjectArea;
  final List<int> studyProgramIds;
  final List<String> studyPrograms;

  const TeacherSubjectItem({
    required this.subjectId,
    required this.subjectName,
    required this.subjectArea,
    required this.studyProgramIds,
    required this.studyPrograms,
  });

  factory TeacherSubjectItem.fromJson(Map<String, dynamic> json)
  {
    return TeacherSubjectItem(
      subjectId: json['subject_id'] ?? 0,
      subjectName: json['subject_name'] ?? '',
      subjectArea: json['subject_area'] ?? '',
      studyProgramIds:
          (json['study_program_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      studyPrograms: parseStringList(json['study_programs']),
    );
  }
}