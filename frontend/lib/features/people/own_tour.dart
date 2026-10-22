import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourOwnFace = 'profile.face';
const String kTourOwnReport = 'profile.report';
const String kTourOwnToOther = 'profile.tab.other';
const String kTourOwnStudies = 'profile.studies';
const String kTourOwnStudiesEdit = 'profile.studies.edit';
const String kTourOwnToStats = 'profile.tab.stats';
const String kTourOwnStats = 'profile.stats';
const String kTourOwnFilters = 'profile.filters';
const String kTourOwnToObservations = 'profile.tab.observations';
const String kTourOwnObservations = 'profile.observations';

const String kTourOwnMode = 'profile.mode';
const String kTourOwnPeriod = 'profile.period';

// The section on show, by name ('info', 'other', 'stats'...): the tour's clicks wait for it.
final ValueNotifier<String?> ownPageSection = ValueNotifier(null);

// Bump a version on every change to that tour.
const int _teacherVersion = 5;
const int _studentVersion = 1;
const int _parentVersion = 1;
const int _psychologistVersion = 1;

const String _about = 'In questo menù puoi consultare tutte le tue informazioni personali.';
const String _report = 'Se noti inesattezze o alcune informazioni sono cambiate, ti preghiamo di farcelo sapere.';
const String _faceEdit = 'Cliccando sulla tua foto profilo puoi modificarla.';
const String _filters =
    "Puoi consultare le statistiche delle lezioni in presenza oppure online, e scegliere l'intervallo di tempo che "
    'desideri analizzare.';
const String _observations =
    'Qui trovi le osservazioni che gli amministratori scrivono su di te, derivate dai feedback ricevuti da studenti e '
    'genitori sulle tue lezioni.';

const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];

bool _shown(String id) => isDesktopTourTargetShown(id);

bool _on(String section) => ownPageSection.value == section;

void startOwnTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

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

Future<bool> ownTourSeen(DesktopTour tour) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode == null || await isDesktopTourSeen(taxCode: taxCode, tour: tour);
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
List<DesktopTourStep> _pageSteps({required String face})
{
  return [
    const DesktopTourStep(text: _about),
    const DesktopTourStep(
      targets: [kTourOwnReport],
      text: _report,
      sides: _over,
      pad: 6,
      radius: 17,
      reveal: true,
    ),
    DesktopTourStep(
      targets: const [kTourOwnFace],
      text: face,
      sides: _beside,
      pad: 6,
      radius: 51,
    ),
  ];
}

// A click on a rail entry, done once its section is on show.
DesktopTourStep _click(String target, String text, String section)
{
  return DesktopTourStep(
    targets: [target],
    text: text,
    sides: _beside,
    // The entry spans the rail: the hole keeps inside its edges.
    pad: 0,
    radius: 12,
    listen: ownPageSection,
    reached: () => _on(section),
    present: () => _shown(target),
  );
}

DesktopTour studentOwnTour({required String title, required ValueChanged<String> show})
{
  return DesktopTour(
    slug: 'profile.student',
    title: title,
    version: _studentVersion,
    steps: [
      ..._pageSteps(face: _faceEdit),
      _click(kTourOwnToStats, 'Clicca «Statistiche personali».', 'stats'),
      DesktopTourStep(
        targets: const [kTourOwnStats],
        text: 'Qui puoi vedere le presenze che hai fatto nel tempo, le materie su cui hai svolto più ore di lezione e i '
            'docenti con cui hai lavorato di più.',
        sides: _below,
        pad: 6,
        radius: 43,
        undo: () => show('info'),
        // The statistics are read once their section opens: the hole waits for them.
        present: () => _on('stats'),
        coming: () => _shown(kTourOwnToStats),
      ),
      // The mode's and the period's pills as one part: the ranking's one beside them is not told.
      DesktopTourStep(
        targets: const [kTourOwnMode, kTourOwnPeriod],
        text: _filters,
        sides: _below,
        pad: 6,
        radius: 25,
        present: () => _on('stats'),
        coming: () => _shown(kTourOwnToStats),
      ),
    ],
  );
}

DesktopTour parentOwnTour({required String title})
{
  return DesktopTour(
    slug: 'profile.parent',
    title: title,
    version: _parentVersion,
    steps: _pageSteps(face: _faceEdit),
  );
}

DesktopTour psychologistOwnTour({required String title})
{
  return DesktopTour(
    slug: 'profile.psychologist',
    title: title,
    version: _psychologistVersion,
    steps: _pageSteps(face: _faceEdit),
  );
}

// [noted]: the Osservazioni hold a card of notes, not the empty one.
DesktopTour teacherOwnTour({required String title, required ValueChanged<String> show, required bool noted})
{
  return DesktopTour(
    slug: 'profile.teacher',
    title: title,
    version: _teacherVersion,
    steps: [
      ..._pageSteps(
        face: '$_faceEdit Sarà visibile a studenti e genitori, pertanto scegline una in cui sia presente solo tu e in '
            'cui ti si veda bene in volto.',
      ),
      _click(kTourOwnToOther, 'Clicca «Altre informazioni».', 'other'),
      DesktopTourStep(
        targets: const [kTourOwnStudies, kTourOwnStudiesEdit],
        apart: true,
        text: 'Puoi modificare in qualsiasi momento le informazioni relative ai tuoi studi. Poiché saranno visibili a '
            'studenti e genitori, ti chiediamo di mantenerle sempre accurate e aggiornate.',
        sides: _beside,
        pad: 6,
        radius: 17,
        // The card's corner, then the button's.
        radii: [43, 17],
        reveal: true,
        revealing: kTourOwnStudiesEdit,
        undo: () => show('info'),
        present: () => _on('other') && _shown(kTourOwnStudies),
        coming: () => true,
      ),
      _click(kTourOwnToStats, 'Clicca «Statistiche personali».', 'stats'),
      DesktopTourStep(
        targets: const [kTourOwnStats],
        text: 'Qui puoi vedere le disponibilità che hai dato nel tempo, le discipline che hai insegnato e gli studenti '
            'che hai seguito.',
        sides: _below,
        pad: 6,
        radius: 43,
        undo: () => show('other'),
        present: () => _on('stats'),
        coming: () => _shown(kTourOwnToStats),
      ),
      DesktopTourStep(
        targets: const [kTourOwnFilters],
        text: _filters,
        sides: _below,
        pad: 6,
        radius: 25,
        present: () => _on('stats'),
        coming: () => _shown(kTourOwnToStats),
      ),
      _click(kTourOwnToObservations, 'Clicca «Osservazioni».', 'observations'),
      DesktopTourStep(
        targets: const [kTourOwnObservations],
        text: _observations,
        sides: _below,
        pad: 6,
        radius: noted ? 35 : 31,
        undo: () => show('stats'),
        present: () => _on('observations'),
        coming: () => _shown(kTourOwnToObservations),
      ),
    ],
  );
}
