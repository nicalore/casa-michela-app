import '../../../core/utils/alphabetical_order.dart';
import 'study_program_item.dart';
import 'subject_taxonomy.dart';

enum ProgramGroupKind { level, cycle, sector }

const Map<String, String> _cycleTitles = {
  'BIENNIO': 'Biennio',
  'TRIENNIO': 'Triennio',
  'OTHER': 'Altri percorsi',
};

// The percorsi windows' groups: school level, then high school cycle, then sector.
class ProgramGroup
{
  final String key;
  final String title;
  final ProgramGroupKind kind;

  // Programmes with no deeper group of their own, shown as rows under the heading.
  final List<StudyProgramItem> programs;
  final List<ProgramGroup> children;

  const ProgramGroup({
    required this.key,
    required this.title,
    required this.kind,
    this.programs = const [],
    this.children = const [],
  });

  List<StudyProgramItem> get all => [
        ...programs,
        for (final ProgramGroup child in children) ...child.all,
      ];

  Iterable<ProgramGroup> get sectors sync*
  {
    for (final ProgramGroup child in children)
    {
      if (child.kind == ProgramGroupKind.sector)
      {
        yield child;
      }

      yield* child.sectors;
    }
  }
}

// Only the "other" cycle mixes lengths, so only its rows name their years.
String? programYearsLine(StudyProgramItem program)
{
  return program.highSchoolTrack == 'OTHER'
      ? highSchoolTrackShortLabel(program.highSchoolTrack, program.minYear, program.maxYear)
      : null;
}

// Groups left without a programme matching [query] are dropped.
List<ProgramGroup> programTree(Iterable<StudyProgramItem> programs, {String query = ''})
{
  final String wanted = query.trim().toLowerCase();
  final List<StudyProgramItem> shown = [
    for (final StudyProgramItem program in programs)
      if (wanted.isEmpty || program.fullName.toLowerCase().contains(wanted)) program,
  ]..sort((a, b) => compareAlphabetically(a.name, b.name));

  final List<String> levels = shown.map((program) => program.level).toSet().toList()
    ..sort((a, b) => schoolLevelRank(a).compareTo(schoolLevelRank(b)));

  return [
    for (final String level in levels)
      _levelGroup(level, [for (final StudyProgramItem program in shown) if (program.level == level) program]),
  ];
}

ProgramGroup _levelGroup(String level, List<StudyProgramItem> programs)
{
  final List<String> cycles = [
    for (final HighSchoolTrack track in highSchoolTracks)
      if (programs.any((program) => program.highSchoolTrack == track.value)) track.value,
    for (final String other in programs.map((program) => program.highSchoolTrack).nonNulls.toSet())
      if (!highSchoolTracks.any((track) => track.value == other)) other,
  ];
  final List<StudyProgramItem> loose = [
    for (final StudyProgramItem program in programs)
      if (program.highSchoolTrack == null) program,
  ];

  return ProgramGroup(
    key: level,
    title: schoolLevelLabel(level),
    kind: ProgramGroupKind.level,
    programs: [for (final StudyProgramItem program in loose) if (program.sector == null) program],
    children: [
      ..._sectorGroups(level, loose),
      for (final String cycle in cycles)
        _cycleGroup(level, cycle, [
          for (final StudyProgramItem program in programs)
            if (program.highSchoolTrack == cycle) program,
        ]),
    ],
  );
}

ProgramGroup _cycleGroup(String level, String cycle, List<StudyProgramItem> programs)
{
  final String key = '$level/$cycle';

  return ProgramGroup(
    key: key,
    title: _cycleTitles[cycle] ?? highSchoolTrackOf(cycle)?.label ?? cycle,
    kind: ProgramGroupKind.cycle,
    programs: [for (final StudyProgramItem program in programs) if (program.sector == null) program],
    children: _sectorGroups(key, programs),
  );
}

List<ProgramGroup> _sectorGroups(String parent, List<StudyProgramItem> programs)
{
  final List<String> sectors = programs.map((program) => program.sector).nonNulls.toSet().toList()
    ..sort(compareAlphabetically);

  return [
    for (final String sector in sectors)
      ProgramGroup(
        key: '$parent/$sector',
        title: sector,
        kind: ProgramGroupKind.sector,
        programs: [for (final StudyProgramItem program in programs) if (program.sector == sector) program],
      ),
  ];
}

// The first level split further, with its first deeper group and that group's first sector: what a tour lights.
({ProgramGroup level, ProgramGroup? cycle, ProgramGroup? sector})? firstProgramBranch(List<ProgramGroup> tree)
{
  final ProgramGroup? level = tree.where((group) => group.children.isNotEmpty).firstOrNull ?? tree.firstOrNull;

  if (level == null)
  {
    return null;
  }

  final ProgramGroup? cycle = level.children.where((group) => group.kind == ProgramGroupKind.cycle).firstOrNull;

  return (level: level, cycle: cycle, sector: (cycle ?? level).sectors.firstOrNull);
}
