import '../../../core/language/app_language.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';
import 'pupil_band_presence.dart';
import 'teacher_band_call.dart';

String get kCalendarLoadFailed => tr('Non è stato possibile caricare il calendario.', "Couldn't load the calendar.");

String get kCalendarUnpublishedTitle => tr('Calendario in preparazione', 'Calendar in preparation');

String get kCalendarUnavailableTitle => tr('Calendario non disponibile', 'Calendar not available');

String get kNoAvailabilityGiven => tr('Non hai dato disponibilità.', "You haven't given any availability.");

// [childGenders]: a parent's children on show; [booksOwn] false for a pupil whose parents book.
String noLessonsRequested({List<String?> childGenders = const [], bool booksOwn = true})
{
  if (childGenders.isNotEmpty)
  {
    final bool girls = childGenders.every((gender) => gender == 'F');
    final String whose = childGenders.length == 1
        ? (girls ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son'))
        : (girls ? tr('le tue figlie', 'your daughters') : tr('i tuoi figli', 'your children'));

    return tr('Non hai richiesto lezioni per $whose.', "You haven't requested any lessons for $whose.");
  }

  return booksOwn
      ? tr('Non hai richiesto lezioni.', "You haven't requested any lessons.")
      : tr('Non ci sono lezioni richieste per te.', 'There are no lessons requested for you.');
}

String get kNoLessonsTitle => tr('Nessuna lezione', 'No lessons');

String get kOnlineLessonsTitle => tr('Lezioni online', 'Online lessons');

String get kAssociationClosedTitle => tr("L'Associazione è chiusa", 'The Association is closed');

String ofBand(TimeBucket band) => ofBandLabel(band);

String _enBand(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => 'morning',
    TimeBucket.afternoon => 'afternoon',
    TimeBucket.evening => 'evening',
  };
}

String unpublishedBandMessage(TimeBucket band)
{
  return tr(
    'Il calendario ${ofBand(band)} non è ancora stato pubblicato.',
    "The ${_enBand(band)} calendar hasn't been published yet.",
  );
}

// "Clicca" on the desktop, "Tocca" on mobile; the verb comes in the language in force.
String lessonDetailsHint({required String verb})
{
  return tr(
    'Quando il calendario viene pubblicato, $verb su ciascuna lezione per vedere i dettagli.',
    'When the calendar is published, $verb each lesson to see its details.',
  );
}

String get kPresentWord => tr('Presente', 'Present');

String get kNoPresenceTitle => tr('Nessuna presenza', 'No attendance');

String pupilNothingTitle({required bool inBuilding}) => inBuilding ? kNoPresenceTitle : kNoLessonsTitle;

String notConvenedTitle({required bool feminine})
{
  return feminine
      ? tr('Non sei stata convocata', "You haven't been called in")
      : tr('Non sei stato convocato', "You haven't been called in");
}

String notConvenedSentence({required bool feminine}) => '${notConvenedTitle(feminine: feminine)}.';

String convokedWord({required bool feminine}) => feminine ? tr('Convocata', 'Called in') : tr('Convocato', 'Called in');

// Every mode counts: online lessons convoke as much as those in the building.
String convocationTitle(TeacherBandCall call, {required bool feminine})
{
  final word = convokedWord(feminine: feminine);
  final hull = call.hull;

  if (hull == null)
  {
    return word;
  }

  final String from = formatTimeOfDayShort(timeOfDayFromMinutes(hull.$1));
  final String to = formatTimeOfDayShort(timeOfDayFromMinutes(hull.$2));

  return tr('$word dalle $from alle $to', '$word from $from to $to');
}

typedef ConvocationFigure = ({String value, String label});

List<ConvocationFigure> convocationFigures(TeacherBandCall call)
{
  final lessons = call.lessons.length;
  final students = call.studentCount;

  return [
    (value: '$lessons', label: lessons == 1 ? tr('lezione', 'lesson') : tr('lezioni', 'lessons')),
    (value: '$students', label: students == 1 ? tr('studente', 'student') : tr('studenti', 'students')),
    if (call.activities.isNotEmpty)
      (
        value: '${call.activities.length}',
        label: call.activities.length == 1 ? tr('attività', 'activity') : tr('attività', 'activities'),
      ),
    (value: formatMinutes(call.lessonMinutes), label: tr('di lezione', 'of lessons')),
  ];
}

String get kSelfMark => tr('Tu', 'You');

String roomSupervisorsHeading(int count) => count == 1 ? kSupervisorLabel : kSupervisorsLabel;

// Null for a lone supervisor, who covers every lesson hour by the publication rule.
String? supervisorHours(RoomSupervisor supervisor, {required int count})
{
  if (count < 2)
  {
    return null;
  }

  return supervisor.spans.map((span) => formatMinutesRange(span.$1, span.$2)).join(', ');
}

String convocationSummary(TeacherBandCall call)
{
  return convocationFigures(call).map((figure) => '${figure.value} ${figure.label}').join(' · ');
}

List<ConvocationFigure> presenceFigures(PupilBandPresence presence)
{
  final lessons = presence.lessons.length;

  return [
    (value: '$lessons', label: lessons == 1 ? tr('lezione', 'lesson') : tr('lezioni', 'lessons')),
    (value: formatMinutes(presence.lessonMinutes), label: tr('di lezione', 'of lessons')),
  ];
}

String presenceSummary(PupilBandPresence presence)
{
  return presenceFigures(presence).map((figure) => '${figure.value} ${figure.label}').join(' · ');
}
