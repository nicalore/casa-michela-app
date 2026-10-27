import 'package:flutter/widgets.dart';

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

const String _title = 'Associazione';

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
  const String intro = "In questa pagina trovi tutti i docenti che collaborano con l'Associazione. "
      'Cliccando su ciascuno di essi puoi visualizzarne alcune informazioni';

  if (opinions.isEmpty)
  {
    return '$intro.';
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
    return 'Puoi ordinare i docenti per nome o cognome e filtrarli per disciplina insegnata.';
  }

  final String whose = _self
      ? ''
      : opinions.length == 1
          ? (_daughter(opinions.single) ? ' da tua figlia' : ' da tuo figlio')
          : (opinions.every(_daughter) ? ' dalle tue figlie' : ' dai tuoi figli');

  return 'Puoi ordinare i docenti per nome o cognome, filtrarli per disciplina insegnata, o visualizzare solo quelli '
      'non graditi$whose.';
}

String _opinionText(List<String?> opinions)
{
  if (_self)
  {
    return 'Puoi segnalare se preferisci non fare lezione con il docente.';
  }

  final String who = opinions.length == 1
      ? (_daughter(opinions.single) ? 'tua figlia preferisce' : 'tuo figlio preferisce')
      : (opinions.every(_daughter) ? 'le tue figlie preferiscono' : 'i tuoi figli preferiscono');

  return 'Puoi segnalare se $who non fare lezione con il docente.';
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
final DesktopTourStep _variationStep = DesktopTourStep(
  targets: const [kTourAssociationVariation],
  text: "Questo simbolo indica che l'orario per questo giorno è diverso rispetto all'orario standard.",
  sides: _beside,
  // The bare symbol: a round hole.
  pad: 8,
  radius: 11,
  reveal: true,
  present: () => !associationNoticesShown.value && _shown(kTourAssociationVariation),
  seen: _variationSeen,
);

final DesktopTourStep _pinnedStep = DesktopTourStep(
  targets: const [kTourAssociationPinned],
  text: 'I messaggi fissati in alto sono particolarmente importanti: ti preghiamo di leggerli con attenzione.',
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
        text: "Qui puoi consultare gli orari di apertura dell'Associazione, giorno per giorno.",
        sides: _below,
        pad: 8,
        radius: 24,
        reveal: true,
      ),
      _variationStep,
      const DesktopTourStep(
        targets: [kTourAssociationWeek],
        text: 'Puoi scorrere tra le settimane con le frecce, oppure cliccare il calendario per scegliere una settimana '
            'qualsiasi.',
        sides: _belowLeft,
        pad: 6,
        radius: 25,
      ),
      const DesktopTourStep(
        targets: [kTourAssociationStandard],
        text: "Questi sono gli orari di apertura ufficiali dell'Associazione, senza eventuali variazioni.",
        sides: _over,
        pad: 6,
        radius: 35,
        reveal: true,
      ),
      DesktopTourStep(
        targets: const [kTourAssociationVariations],
        text: "Queste sono le prossime variazioni rispetto all'orario standard, previste in occasione di festività o "
            'per altre esigenze.',
        sides: _over,
        pad: 6,
        radius: 35,
        reveal: true,
        present: () => _shown(kTourAssociationVariations),
      ),
      if (reader) ...[
        _click(kTourAssociationToSubjects, 'Clicca «Discipline».', 'subjects'),
        // The cards' list, read once the section opens: the hole waits for it.
        DesktopTourStep(
          targets: const [kTourAssociationSubjects],
          text: 'In questa pagina trovi tutte le discipline che vengono insegnate in Associazione.',
          sides: _beside,
          pad: 6,
          radius: 27,
          undo: () => show('hours'),
          present: () => _on('subjects'),
          coming: () => true,
        ),
        DesktopTourStep(
          targets: const [kTourAssociationReport],
          text: 'Se manca una disciplina che ti interessa, puoi segnalarlo tramite questo bottone.',
          sides: _over,
          pad: 6,
          radius: 28,
          reveal: true,
          present: () => _on('subjects'),
          coming: () => true,
        ),
        _click(kTourAssociationToTeachers, 'Clicca «Docenti».', 'teachers'),
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
        text: 'Clicca «Comunicazioni e avvisi».',
        sides: _beside,
        pad: 0,
        radius: 12,
        listen: associationNoticesShown,
        reached: onNotices,
      ),
      DesktopTourStep(
        targets: const [kTourAssociationNotices],
        text: "Qui puoi leggere tutti i messaggi inviati dal Direttivo dell'Associazione.",
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
        text: 'Puoi ordinare i messaggi dal più recente al meno recente o viceversa, filtrare gli avvisi per una data '
            'specifica oppure cercarli in base al titolo o al contenuto.',
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
final DesktopTour associationPickerTour = DesktopTour(
  slug: 'association.picker',
  title: _title,
  version: _pickerVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourAssociationPickerDays],
      text: 'Il pallino sotto una data indica la presenza di un messaggio inviato in quel giorno.',
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
DesktopTour associationTeacherTour({required List<String?> opinions})
{
  return DesktopTour(
    slug: _teacherWindowSeen.$1,
    title: _title,
    version: _teacherWindowSeen.$2,
    steps: [
      const DesktopTourStep(
        targets: [kTourAssociationTeacherProfile, kTourAssociationTeacherSubjects],
        text: 'Da qui puoi vedere la formazione del docente e le discipline che insegna in Associazione.',
        sides: _beside,
        pad: 6,
        radius: 31,
      ),
      if (opinions.isNotEmpty)
        DesktopTourStep(
          targets: const [kTourAssociationTeacherOpinion],
          text: _opinionText(opinions),
          sides: _beside,
          pad: 6,
          radius: 31,
          present: () => _shown(kTourAssociationTeacherOpinion),
        ),
    ],
  );
}
