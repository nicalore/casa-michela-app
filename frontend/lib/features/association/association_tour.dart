import 'package:flutter/widgets.dart';

import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourAssociationDays = 'association.days';
const String kTourAssociationVariation = 'association.variation';
const String kTourAssociationWeek = 'association.week';
const String kTourAssociationStandard = 'association.standard';
const String kTourAssociationVariations = 'association.variations';

const String kTourAssociationToSubjects = 'association.tab.subjects';
const String kTourAssociationToTeachers = 'association.tab.teachers';
const String kTourAssociationToNotices = 'association.tab.notices';

const String kTourAssociationSubjects = 'association.subjects';
const String kTourAssociationReport = 'association.report';
const String kTourAssociationTeachers = 'association.teachers';
const String kTourAssociationTeachersTop = 'association.teachers.top';

const String kTourAssociationTeacherProfile = 'association.teacher.profile';
const String kTourAssociationTeacherSubjects = 'association.teacher.subjects';
const String kTourAssociationTeacherOpinion = 'association.teacher.opinion';

const String kTourAssociationNotices = 'association.notices';
const String kTourAssociationPinned = 'association.pinned';
const String kTourAssociationSearch = 'association.search';
const String kTourAssociationFilters = 'association.filters';
const String kTourAssociationPickerDays = 'association.picker.days';

// True while the notices section is on show or its picker is up; tours wait on it.
final ValueNotifier<bool> associationNoticesShown = ValueNotifier(false);

// Section on show: 'hours', 'subjects', 'teachers' or 'notices'; tour clicks wait on it.
final ValueNotifier<String?> associationSection = ValueNotifier(null);
final ValueNotifier<bool> associationPickerOpen = ValueNotifier(false);

String get _title => tr('Associazione', 'Association');

// Bump a version on every change to that tour.
const Map<String, (String, int)> _mainSeen = {
  'TEACHER': ('association.teacher', 3),
  'PARENT': ('association.parent', 4),
  'STUDENT': ('association.student', 4),
};

const (String, int) _teacherWindowSeen = ('association.reader.teacher', 1);

// Conditional parts: in the main tour when present, else a late tour on first sight.
const (String, int) _variationSeen = ('association.variation', 2);
const (String, int) _pinnedSeen = ('association.pinned', 1);

const int _pickerVersion = 2;

const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _belowLeft = [DesktopTourSide.below, DesktopTourSide.left, DesktopTourSide.above];
const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];

bool _shown(String id) => isDesktopTourTargetShown(id);

bool _on(String section) => associationSection.value == section;

bool _daughter(String? gender) => gender == 'F';

bool get _self => ApiService().lastKnownIdentity?.activeRole == 'STUDENT';

// [opinions]: genders of those the reader gives teacher opinions for; empty if none.
String _teachersText(List<String?> opinions)
{
  final String intro = tr(
    "In questa pagina trovi tutti i docenti che collaborano con l'Associazione. "
        'Cliccando su ciascuno di essi puoi visualizzarne alcune informazioni',
    "On this page you'll find all the teachers who work with the Association. "
        'Click any of them to view some information about them',
  );

  if (opinions.isEmpty)
  {
    return '$intro.';
  }

  if (isEnglish)
  {
    final String who = _self
        ? 'you'
        : opinions.length == 1
            ? (_daughter(opinions.single) ? 'your daughter' : 'your son')
            : (opinions.every(_daughter) ? 'your daughters' : 'your children');

    return "$intro and, if you wish, say whether $who didn't get on well with them.";
  }

  final String gotOn = _self
      ? 'non ti sei ${_daughter(opinions.first) ? 'trovata' : 'trovato'}'
      : opinions.length == 1
          ? (_daughter(opinions.single) ? 'tua figlia non si è trovata' : 'tuo figlio non si è trovato')
          : (opinions.every(_daughter) ? 'le tue figlie non si sono trovate' : 'i tuoi figli non si sono trovati');

  return '$intro e, se lo desideri, indicare se $gotOn bene.';
}

String _teachersTopText(List<String?> opinions)
{
  if (opinions.isEmpty)
  {
    return tr(
      'Puoi ordinare i docenti per nome o cognome e filtrarli per disciplina insegnata.',
      'You can sort the teachers by first name or surname and filter them by the discipline they teach.',
    );
  }

  if (isEnglish)
  {
    final String byWhom = _self
        ? ''
        : opinions.length == 1
            ? (_daughter(opinions.single) ? ' by your daughter' : ' by your son')
            : (opinions.every(_daughter) ? ' by your daughters' : ' by your children');

    return 'You can sort the teachers by first name or surname, filter them by the discipline they teach, or show only '
        'those not liked$byWhom.';
  }

  final String whose = _self
      ? ''
      : opinions.length == 1
          ? (_daughter(opinions.single) ? ' da tua figlia' : ' da tuo figlio')
          : (opinions.every(_daughter) ? ' dalle tue figlie' : ' dai tuoi figli');

  return 'Puoi ordinare i docenti per nome o cognome, filtrarli per disciplina insegnata, o visualizzare solo quelli '
      'non graditi$whose.';
}

String _opinionText(List<String?> opinions, String teacher)
{
  if (_self)
  {
    return tr(
      'Puoi segnalare se preferisci non fare lezione con $teacher.',
      "You can let us know if you'd rather not have lessons with this teacher.",
    );
  }

  if (isEnglish)
  {
    final String who = opinions.length == 1
        ? (_daughter(opinions.single) ? 'your daughter' : 'your son')
        : (opinions.every(_daughter) ? 'your daughters' : 'your children');

    return "You can let us know if $who would rather not have lessons with this teacher.";
  }

  final String who = opinions.length == 1
      ? (_daughter(opinions.single) ? 'tua figlia preferisce' : 'tuo figlio preferisce')
      : (opinions.every(_daughter) ? 'le tue figlie preferiscono' : 'i tuoi figli preferiscono');

  return 'Puoi segnalare se $who non fare lezione con $teacher.';
}

// Tax code of a reading role; null for the administrator, who edits instead.
String? get _reader
{
  final identity = ApiService().lastKnownIdentity;

  return _mainSeen.containsKey(identity?.activeRole) ? identity?.taxCode : null;
}

void startAssociationTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = _reader;

  if (taxCode == null)
  {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_)
  {
    if (context.mounted)
    {
      startDesktopTourOnce(context, taxCode: taxCode, tour: tour);
    }
  });

  // Asked from another frame's callback, it still needs a frame to come.
  WidgetsBinding.instance.scheduleFrame();
}

// Radius = the part's corner + pad / 2; the hole adds the other half, so it stays concentric.
DesktopTourStep get _variationStep => DesktopTourStep(
  targets: const [kTourAssociationVariation],
  text: tr(
    "Questo simbolo indica che l'orario per questo giorno è diverso rispetto all'orario standard.",
    'This symbol means the hours for this day differ from the standard hours.',
  ),
  sides: _beside,
  // The bare symbol: a round hole.
  pad: 8,
  radius: 11,
  reveal: true,
  present: () => !associationNoticesShown.value && _shown(kTourAssociationVariation),
  seen: _variationSeen,
);

DesktopTourStep get _pinnedStep => DesktopTourStep(
  targets: const [kTourAssociationPinned],
  text: tr(
    'I messaggi fissati in alto sono particolarmente importanti: ti preghiamo di leggerli con attenzione.',
    'The messages pinned at the top are especially important: please read them carefully.',
  ),
  sides: _below,
  pad: 6,
  radius: 27,
  reveal: true,
  present: () => associationNoticesShown.value && _shown(kTourAssociationPinned),
  seen: _pinnedSeen,
);

DesktopTourStep _click(String target, String text, String section)
{
  return DesktopTourStep(
    targets: [target],
    text: text,
    sides: _beside,
    // The entry spans the rail: the hole keeps inside its edges.
    pad: 0,
    radius: 12,
    listen: associationSection,
    reached: () => _on(section),
  );
}

// Hours, then "Discipline" and "Docenti" for parents and students, then notices; null if none.
// [show] turns the page to a section by name when stepping back.
DesktopTour? associationTour({required ValueChanged<String> show, List<String?> opinions = const []})
{
  final (String slug, int version)? seen = _mainSeen[ApiService().lastKnownIdentity?.activeRole];

  if (seen == null)
  {
    return null;
  }

  bool onNotices() => associationNoticesShown.value;

  final bool reader = ApiService().lastKnownIdentity?.activeRole != 'TEACHER';

  return DesktopTour(
    slug: seen.$1,
    title: _title,
    version: seen.$2,
    steps: [
      DesktopTourStep(
        targets: const [kTourAssociationDays],
        text: tr(
          "Qui puoi consultare gli orari di apertura dell'Associazione, giorno per giorno.",
          "Here you can check the Association's opening hours, day by day.",
        ),
        sides: _below,
        pad: 8,
        radius: 24,
        reveal: true,
      ),
      _variationStep,
      DesktopTourStep(
        targets: const [kTourAssociationWeek],
        text: tr(
          'Puoi scorrere tra le settimane con le frecce, oppure cliccare il calendario per scegliere una settimana '
              'qualsiasi.',
          'You can move between weeks with the arrows, or click the calendar to pick any week.',
        ),
        sides: _belowLeft,
        pad: 6,
        radius: 25,
      ),
      DesktopTourStep(
        targets: const [kTourAssociationStandard],
        text: tr(
          "Questi sono gli orari di apertura ufficiali dell'Associazione, senza eventuali variazioni.",
          "These are the Association's official opening hours, without any schedule changes.",
        ),
        sides: _over,
        pad: 6,
        radius: 35,
        reveal: true,
      ),
      DesktopTourStep(
        targets: const [kTourAssociationVariations],
        text: tr(
          "Queste sono le prossime variazioni rispetto all'orario standard, previste in occasione di festività o "
              'per altre esigenze.',
          'These are the upcoming changes to the standard hours, planned for holidays or other needs.',
        ),
        sides: _over,
        pad: 6,
        radius: 35,
        reveal: true,
        present: () => _shown(kTourAssociationVariations),
      ),
      if (reader) ...[
        _click(kTourAssociationToSubjects, tr('Clicca «Discipline».', 'Click “Disciplines”.'), 'subjects'),
        // The cards' list, read once the section opens: the hole waits for it.
        DesktopTourStep(
          targets: const [kTourAssociationSubjects],
          text: tr(
            'In questa pagina trovi tutte le discipline che vengono insegnate in Associazione.',
            "On this page you'll find all the disciplines taught at the Association.",
          ),
          sides: _beside,
          pad: 6,
          radius: 27,
          undo: () => show('hours'),
          present: () => _on('subjects'),
          coming: () => true,
        ),
        DesktopTourStep(
          targets: const [kTourAssociationReport],
          text: tr(
            'Se manca una disciplina che ti interessa, puoi segnalarlo tramite questo bottone.',
            "If a discipline you're interested in is missing, you can report it with this button.",
          ),
          sides: _over,
          pad: 6,
          radius: 28,
          reveal: true,
          present: () => _on('subjects'),
          coming: () => true,
        ),
        _click(kTourAssociationToTeachers, tr('Clicca «Docenti».', 'Click “Teachers”.'), 'teachers'),
        DesktopTourStep(
          targets: const [kTourAssociationTeachers],
          text: _teachersText(opinions),
          sides: _beside,
          pad: 6,
          radius: 27,
          undo: () => show('subjects'),
          present: () => _on('teachers'),
          coming: () => true,
        ),
        DesktopTourStep(
          targets: const [kTourAssociationTeachersTop],
          text: _teachersTopText(opinions),
          sides: _below,
          pad: 6,
          radius: 25,
          present: () => _on('teachers'),
          coming: () => true,
        ),
      ],
      DesktopTourStep(
        targets: const [kTourAssociationToNotices],
        text: tr('Clicca «Comunicazioni e avvisi».', 'Click “Announcements and notices”.'),
        sides: _beside,
        pad: 0,
        radius: 12,
        listen: associationNoticesShown,
        reached: onNotices,
      ),
      DesktopTourStep(
        targets: const [kTourAssociationNotices],
        text: tr(
          "Qui puoi leggere tutti i messaggi inviati dal Direttivo dell'Associazione.",
          "Here you can read all the messages sent by the Association's Board.",
        ),
        sides: _beside,
        pad: 6,
        radius: 27,
        undo: () => show(reader ? 'teachers' : 'hours'),
        present: onNotices,
        coming: () => true,
      ),
      _pinnedStep,
      DesktopTourStep(
        targets: const [kTourAssociationSearch, kTourAssociationFilters],
        text: tr(
          'Puoi ordinare i messaggi dal più recente al meno recente o viceversa, filtrare gli avvisi per una data '
              'specifica oppure cercarli in base al titolo o al contenuto.',
          'You can sort the messages from newest to oldest or the other way round, filter the notices by a specific '
              'date or search them by title or content.',
        ),
        sides: _below,
        pad: 6,
        radius: 28,
        present: onNotices,
        coming: () => true,
      ),
    ],
  );
}

Future<bool> associationTourSeen(DesktopTour tour) async
{
  final String? taxCode = _reader;

  return taxCode == null || await isDesktopTourSeen(taxCode: taxCode, tour: tour);
}

// Variation symbol or pinned notice seen for the first time after the main tour.
Future<DesktopTour?> associationLateTour() async
{
  final String? taxCode = _reader;

  return taxCode == null
      ? null
      : dueDesktopTour(taxCode: taxCode, title: _title, steps: [_variationStep, _pinnedStep]);
}

// Over the notices' picker; a click on a day picks it and ends the tour.
DesktopTour get associationPickerTour => DesktopTour(
  slug: 'association.picker',
  title: _title,
  version: _pickerVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourAssociationPickerDays],
      text: tr(
        'Il pallino sotto una data indica la presenza di un messaggio inviato in quel giorno.',
        'The dot under a date means a message was sent on that day.',
      ),
      sides: _beside,
      pad: 6,
      radius: 12,
      interactive: true,
      listen: associationPickerOpen,
      reached: () => !associationPickerOpen.value,
    ),
  ],
);

// First time a parent or student opens a teacher's window; [opinions] as for the page's tour.
DesktopTour associationTeacherTour({required List<String?> opinions, String? teacherGender})
{
  final bool she = teacherGender == 'F';
  final String theyTeach = switch (teacherGender) { 'F' => 'she teaches', 'M' => 'he teaches', _ => 'they teach' };

  return DesktopTour(
    slug: _teacherWindowSeen.$1,
    title: _title,
    version: _teacherWindowSeen.$2,
    steps: [
      DesktopTourStep(
        targets: const [kTourAssociationTeacherProfile, kTourAssociationTeacherSubjects],
        text: tr(
          'Da qui puoi vedere la formazione ${she ? 'della docente' : 'del docente'} e le discipline che insegna '
              'in Associazione.',
          "From here you can see the teacher's education and the disciplines $theyTeach at the Association.",
        ),
        sides: _beside,
        pad: 6,
        radius: 31,
      ),
      if (opinions.isNotEmpty)
        DesktopTourStep(
          targets: const [kTourAssociationTeacherOpinion],
          text: _opinionText(opinions, she ? 'la docente' : 'il docente'),
          sides: _beside,
          pad: 6,
          radius: 31,
          present: () => _shown(kTourAssociationTeacherOpinion),
        ),
    ],
  );
}
