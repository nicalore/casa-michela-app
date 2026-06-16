class SubjectOption {
  final int id;
  final String discipline;
  final String? specialization;
  SubjectOption({required this.id, required this.discipline, this.specialization});
}

class SchoolOption {
  final String mechanographicCode;
  final String name;
  SchoolOption({required this.mechanographicCode, required this.name});
}

class StudyProgramOption {
  final int id;
  final String name;
  StudyProgramOption({required this.id, required this.name});
}

class OfferingOptions {
  final List<SchoolOption> schools;
  final List<StudyProgramOption> studyPrograms;
  final List<SubjectOption> subjects;

  OfferingOptions({required this.schools, required this.studyPrograms, required this.subjects});
}

class TeachingOfferingItem {
  final int id;
  final String schoolCode;
  final String schoolName;
  final int studyProgramId;
  final String studyProgramName;
  final String level;
  final List<int> years;
  final List<int> subjectIds;
  final List<SubjectOption> subjects;

  TeachingOfferingItem({
    required this.id,
    required this.schoolCode,
    required this.schoolName,
    required this.studyProgramId,
    required this.studyProgramName,
    required this.level,
    required this.years,
    required this.subjectIds,
    required this.subjects,
  });
}