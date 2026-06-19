class SchoolItem 
{
  final String mechanographicCode;
  final String name;
  final String city;
  final String province;
  final DateTime createdAt;
  final List<SchoolStudyProgramOption> studyPrograms;

  const SchoolItem({
    required this.mechanographicCode,
    required this.name,
    required this.city,
    required this.province,
    required this.createdAt,
    this.studyPrograms = const [],
  });

  SchoolItem copyWith({
    String? mechanographicCode,
    String? name,
    String? city,
    String? province,
    DateTime? createdAt,
    List<SchoolStudyProgramOption>? studyPrograms,
  }) 
  {
    return SchoolItem(
      mechanographicCode: mechanographicCode ?? this.mechanographicCode,
      name: name ?? this.name,
      city: city ?? this.city,
      province: province ?? this.province,
      createdAt: createdAt ?? this.createdAt,
      studyPrograms: studyPrograms ?? this.studyPrograms,
    );
  }
}

class SchoolStudyProgramOption 
{
  final int id;
  final String name;
  final String level;

  const SchoolStudyProgramOption({
    required this.id,
    required this.name,
    required this.level,
  });
}