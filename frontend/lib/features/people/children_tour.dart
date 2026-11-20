import 'package:flutter/widgets.dart';

import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourChildrenReport = 'children.report';
const String kTourChildrenToStats = 'children.tab.stats';
const String kTourChildrenStats = 'children.stats';
const String kTourChildrenMode = 'children.mode';
const String kTourChildrenPeriod = 'children.period';

// Followed child's section on show, by name ('info', 'stats'...): the tour's clicks wait for it.
final ValueNotifier<String?> childrenPageSection = ValueNotifier(null);

String get _title => tr('Figli', 'Children');

const String _parentRole = 'PARENT';

// Bump the version on every change to the tour.
const (String, int) _seen = ('children', 3);

const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];

bool _shown(String id) => isDesktopTourTargetShown(id);

bool _on(String section) => childrenPageSection.value == section;

bool _daughter(String? gender) => gender == 'F';

String? get _parent
{
  final identity = ApiService().lastKnownIdentity;

  return identity?.activeRole == _parentRole ? identity?.taxCode : null;
}

void startChildrenTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = _parent;

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

Future<bool> childrenTourSeen(DesktopTour tour) async
{
  final String? taxCode = _parent;

  return taxCode == null || await isDesktopTourSeen(taxCode: taxCode, tour: tour);
}

// [followed]: gender of the child whose sections are lit; [pupil]: that child has statistics.
// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
DesktopTour childrenTour({
  required List<String?> genders,
  required String? followed,
  required bool pupil,
  required ValueChanged<String> show,
})
{
  final String whom = genders.length > 1
      ? (genders.every(_daughter) ? tr('sulle tue figlie', "your daughters'") : tr('sui tuoi figli', "your children's"))
      : (genders.isNotEmpty && _daughter(genders.first)
          ? tr('su tua figlia', "your daughter's")
          : tr('su tuo figlio', "your son's"));
  final String yours = _daughter(followed) ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son');
  final String pronoun = _daughter(followed) ? 'she' : 'he';

  return DesktopTour(
    slug: _seen.$1,
    title: _title,
    version: _seen.$2,
    steps: [
      DesktopTourStep(
        text: tr('In questo menù puoi consultare le informazioni personali $whom.', 'In this menu you can see $whom personal information.'),
      ),
      DesktopTourStep(
        targets: const [kTourChildrenReport],
        text: tr(
          'Se noti inesattezze o alcune informazioni sono cambiate, ti preghiamo di farcelo sapere.',
          'If you notice any mistakes or some information has changed, please let us know.',
        ),
        sides: _over,
        pad: 6,
        radius: 17,
        reveal: true,
        present: () => _shown(kTourChildrenReport),
      ),
      if (pupil) ...[
        DesktopTourStep(
          targets: const [kTourChildrenToStats],
          text: tr('Clicca «Statistiche personali».', 'Click “Personal statistics”.'),
          sides: _beside,
          // The entry spans the rail: the hole keeps inside its edges.
          pad: 0,
          radius: 12,
          listen: childrenPageSection,
          reached: () => _on('stats'),
          present: () => _shown(kTourChildrenToStats),
        ),
        DesktopTourStep(
          targets: const [kTourChildrenStats],
          text: tr(
            'Qui puoi vedere le presenze che ha fatto $yours nel tempo, le materie su cui ha svolto più ore di '
                'lezione e i docenti con cui ha lavorato di più.',
            "Here you can see $yours's attendance over time, the subjects with the most lesson hours and the "
                'teachers $pronoun worked with the most.',
          ),
          sides: _below,
          pad: 6,
          radius: 43,
          undo: () => show('info'),
          // The statistics are read once their section opens: the hole waits for them.
          present: () => _on('stats'),
          coming: () => _shown(kTourChildrenToStats),
        ),
        // The mode's and the period's pills as one part: the ranking's one beside them is not told.
        DesktopTourStep(
          targets: const [kTourChildrenMode, kTourChildrenPeriod],
          text: tr(
            "Puoi consultare le statistiche delle lezioni in presenza oppure online, e scegliere l'intervallo di "
                'tempo che desideri analizzare.',
            'You can see the statistics of in-person or online lessons, and choose the time range you want to '
                'analyse.',
          ),
          sides: _below,
          pad: 6,
          radius: 25,
          present: () => _on('stats'),
          coming: () => _shown(kTourChildrenToStats),
        ),
      ],
    ],
  );
}
