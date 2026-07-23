class SchoolItem
{
  static const Object _unchanged = Object();

  final int id;
  final String name;
  final String city;
  final String province;
  final String? mechanographicCode;
  final DateTime createdAt;
  final List<SchoolStudyProgramOption> studyPrograms;

  const SchoolItem({
    required this.id,
    required this.name,
    required this.city,
    required this.province,
    this.mechanographicCode,
    required this.createdAt,
    this.studyPrograms = const [],
  });

  // The sentinel default tells an omitted argument apart from one explicitly
  // set to null, which is what allows the mechanographic code to be cleared.
  SchoolItem copyWith({
    int? id,
    String? name,
    String? city,
    String? province,
    Object? mechanographicCode = _unchanged,
    DateTime? createdAt,
    List<SchoolStudyProgramOption>? studyPrograms,
  })
  {
    return SchoolItem(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      province: province ?? this.province,
      mechanographicCode: identical(mechanographicCode, _unchanged)
          ? this.mechanographicCode
          : mechanographicCode as String?,
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