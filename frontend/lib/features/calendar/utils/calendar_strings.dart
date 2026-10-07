import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/utils/opening_window.dart';
import 'pupil_band_presence.dart';
import 'teacher_band_call.dart';

const String kCalendarLoadFailed = 'Non è stato possibile caricare il calendario.';

const String kCalendarUnpublishedTitle = 'Calendario in preparazione';

const String kCalendarUnavailableTitle = 'Calendario non disponibile';

const String kNoAvailabilityGiven = 'Non hai dato disponibilità.';

const String kNoLessonsRequested = 'Non hai richiesto lezioni.';

const String kNoLessonsTitle = 'Nessuna lezione';

const String kOnlineLessonsTitle = 'Lezioni online';

const String kAssociationClosedTitle = "L'Associazione è chiusa";

String ofBand(TimeBucket band) => ofBandLabel(band);

String unpublishedBandMessage(TimeBucket band)
{
  return 'Il calendario ${ofBand(band)} non è ancora stato pubblicato.';
}

// "Clicca" on the desktop, "Tocca" on mobile.
String lessonDetailsHint({required String verb}) => 'Quando il calendario viene pubblicato, $verb su ciascuna lezione per vedere i dettagli.';

const String kPresentWord = 'Presente';

const String kNoPresenceTitle = 'Nessuna presenza';

String pupilNothingTitle({required bool inBuilding}) => inBuilding ? kNoPresenceTitle : kNoLessonsTitle;

String notConvenedTitle({required bool feminine})
{
  return feminine ? 'Non sei stata convocata' : 'Non sei stato convocato';
}

String notConvenedSentence({required bool feminine}) => '${notConvenedTitle(feminine: feminine)}.';

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

List<ConvocationFigure> presenceFigures(PupilBandPresence presence)
{
  final lessons = presence.lessons.length;

  return [
    (value: '$lessons', label: lessons == 1 ? 'lezione' : 'lezioni'),
    (value: formatMinutes(presence.lessonMinutes), label: 'di lezione'),
  ];
}

String presenceSummary(PupilBandPresence presence)
{
  return presenceFigures(presence).map((figure) => '${figure.value} ${figure.label}').join(' · ');
}
