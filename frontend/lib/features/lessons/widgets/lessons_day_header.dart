String _count(int value, String singular, String plural)
{
  return '$value ${value == 1 ? singular : plural}';
}

// Counts are pre-search and count people, not rows.
String lessonsDaySummary({required int availableTeachers, required int presentStudents})
{
  return [
    _count(availableTeachers, 'docente disponibile', 'docenti disponibili'),
    _count(presentStudents, 'alunno prenotato', 'alunni prenotati'),
  ].join(' · ');
}
