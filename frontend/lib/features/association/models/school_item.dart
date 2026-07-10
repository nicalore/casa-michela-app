class SchoolItem 
{
  final int id;
  final String name;
  final String city;
  final String province;

  // Ora solo attributo descrittivo: opzionale, senza vincoli di formato.
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

  SchoolItem copyWith({
    int? id,
    String? name,
    String? city,
    String? province,
    // Object? con sentinella per poter distinguere "non passato"
    // da "passato esplicitamente null" (azzeramento del codice).
    Object? mechanographicCode = _sentinel,
    DateTime? createdAt,
    List<SchoolStudyProgramOption>? studyPrograms,
  }) 
  {
    return SchoolItem(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      province: province ?? this.province,
      mechanographicCode: identical(mechanographicCode, _sentinel)
          ? this.mechanographicCode
          : mechanographicCode as String?,
      createdAt: createdAt ?? this.createdAt,
      studyPrograms: studyPrograms ?? this.studyPrograms,
    );
  }

  static const Object _sentinel = Object();
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