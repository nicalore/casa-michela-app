import '../../../core/language/app_language.dart';

String _count(int value, String singular, String plural)
{
  return '$value ${value == 1 ? singular : plural}';
}

// Counts are pre-search and count people, not rows.
String lessonsDaySummary({required int availableTeachers, required int presentStudents})
{
  return [
    _count(availableTeachers, tr('docente disponibile', 'teacher available'), tr('docenti disponibili', 'teachers available')),
    _count(presentStudents, tr('alunno prenotato', 'pupil booked'), tr('alunni prenotati', 'pupils booked')),
  ].join(' · ');
}
