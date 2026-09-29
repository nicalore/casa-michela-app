import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/utils/opening_window.dart';
import 'teacher_band_call.dart';

const String kCalendarLoadFailed = 'Non è stato possibile caricare il calendario.';

const String kCalendarUnpublishedTitle = 'Calendario in preparazione';

const String kNoLessonsTitle = 'Nessuna lezione';

const String kOnlineLessonsTitle = 'Lezioni online';

const String kAssociationClosedTitle = "L'Associazione è chiusa";

String ofBand(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => 'della mattina',
    TimeBucket.afternoon => 'del pomeriggio',
    TimeBucket.evening => 'della sera',
  };
}

String unpublishedBandMessage(TimeBucket band)
{
  return 'Il calendario ${ofBand(band)} non è ancora stato pubblicato.';
}

String notConvenedTitle({required bool feminine})
{
  return feminine ? 'Non sei stata convocata' : 'Non sei stato convocato';
}

String noOwnLessonsMessage(TimeBucket band)
{
  return 'Nel calendario ${ofBand(band)} non ci sono lezioni per te.';
}

String convokedWord({required bool feminine}) => feminine ? 'Convocata' : 'Convocato';

// A convocation concerns only the in-building hours.
ModeSpan? inBuildingSpan(TeacherBandCall call)
{
  return call.byMode.where((span) => span.mode == kPresenceMode).firstOrNull;
}

String convocationTitle(TeacherBandCall call, {required bool feminine})
{
  final span = inBuildingSpan(call);

  if (span == null)
  {
    return kOnlineLessonsTitle;
  }

  return '${convokedWord(feminine: feminine)} dalle ${formatTimeOfDayShort(timeOfDayFromMinutes(span.startMinutes))} '
      'alle ${formatTimeOfDayShort(timeOfDayFromMinutes(span.endMinutes))}';
}

typedef ConvocationFigure = ({String value, String label});

List<ConvocationFigure> convocationFigures(TeacherBandCall call)
{
  final lessons = call.lessons.length;
  final students = call.studentCount;

  return [
    (value: '$lessons', label: lessons == 1 ? 'lezione' : 'lezioni'),
    (value: '$students', label: students == 1 ? 'studente' : 'studenti'),
    if (call.activities.isNotEmpty) (value: '${call.activities.length}', label: 'attività'),
    (value: formatMinutes(call.lessonMinutes), label: 'di lezione'),
  ];
}

String convocationSummary(TeacherBandCall call)
{
  return convocationFigures(call).map((figure) => '${figure.value} ${figure.label}').join(' · ');
}
