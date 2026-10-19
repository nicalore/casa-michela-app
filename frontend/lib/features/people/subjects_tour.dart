import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourSubjectsHeld = 'subjects.held';
const String kTourSubjectsTools = 'subjects.tools';
const String kTourSubjectsAdd = 'subjects.add';

const String kTourSubjectsFilters = 'subjects.catalogue.filters';
const String kTourSubjectsList = 'subjects.catalogue.list';
const String kTourSubjectsPlus = 'subjects.catalogue.plus';
const String kTourSubjectsConfirm = 'subjects.catalogue.confirm';

const String kTourSubjectsChosenBin = 'subjects.catalogue.chosen.bin';
const String kTourSubjectsChosenRow = 'subjects.catalogue.chosen.row';

const String kTourProgramsList = 'subjects.programs.list';
const String kTourProgramsSector = 'subjects.programs.sector';
const String kTourProgramsSingle = 'subjects.programs.single';
const String kTourProgramsConfirm = 'subjects.programs.confirm';

// True while the catalogue is open: the page's tour asks for it with a click.
final ValueNotifier<bool> subjectsCatalogueOpen = ValueNotifier(false);

const String _title = 'Discipline';

// Bump a version on every change to that tour.
const int _pageVersion = 2;
const int _catalogueVersion = 2;
const int _programsVersion = 2;
const int _chosenVersion = 1;

const List<DesktopTourSide> _belowFirst = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _rightFirst = [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.below];
const List<DesktopTourSide> _besideFirst = [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.above];

const String _confirm = 'Quando hai finito, clicca «Conferma».';

// The same windows serve an administrator on a teacher's record: only the teacher is shown around.
void startSubjectsTour(BuildContext context, DesktopTour tour)
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  if (taxCode == null || ApiService().lastKnownIdentity?.activeRole != 'TEACHER')
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
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
// A teacher with no discipline yet has no pencil to show.
final DesktopTour subjectsPageTour = DesktopTour(
  slug: 'subjects',
  title: _title,
  version: _pageVersion,
  steps: [
    const DesktopTourStep(
      targets: [kTourSubjectsHeld],
      text: 'Qui trovi le discipline che hai scelto di insegnare.',
      sides: _belowFirst,
      pad: 8,
      radius: 34,
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsTools],
      text: 'Con la matita puoi modificare i percorsi di studio di una disciplina, con il cestino puoi rimuoverla.',
      sides: _rightFirst,
      pad: 4,
      radius: 12,
      present: () => isDesktopTourTargetShown(kTourSubjectsTools),
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsAdd],
      text: 'Clicca «Aggiungi discipline».',
      sides: _besideFirst,
      pad: 6,
      radius: 17,
      reveal: true,
      listen: subjectsCatalogueOpen,
      reached: () => subjectsCatalogueOpen.value,
    ),
  ],
);

// Everything already held leaves no + to show.
final DesktopTour subjectsCatalogueTour = DesktopTour(
  slug: 'subjects.catalogue',
  title: _title,
  version: _catalogueVersion,
  steps: [
    const DesktopTourStep(
      targets: [kTourSubjectsFilters],
      text: 'Puoi filtrare le discipline disponibili per area (umanistica, linguistica, scientifica, servizi) oppure '
          'cercarle direttamente tramite la barra in alto.',
      sides: _rightFirst,
      pad: 6,
      radius: 31,
    ),
    const DesktopTourStep(
      targets: [kTourSubjectsList],
      text: 'Queste sono tutte le discipline che puoi decidere di insegnare in Associazione. Selezionandone una puoi '
          'indicare gli indirizzi di studio in cui sei disponibile a tenere lezioni.',
      sides: _rightFirst,
      pad: 6,
      radius: 31,
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsPlus],
      text: 'Con il «+» selezioni direttamente la disciplina con tutti i percorsi di studio in cui è offerta.',
      sides: _rightFirst,
      pad: 4,
      radius: 12,
      present: () => isDesktopTourTargetShown(kTourSubjectsPlus),
    ),
    const DesktopTourStep(targets: [kTourSubjectsConfirm], text: _confirm, sides: _rightFirst, pad: 6, radius: 17),
  ],
);

// The first time a discipline is chosen in the catalogue.
const DesktopTour subjectsChosenTour = DesktopTour(
  slug: 'subjects.catalogue.chosen',
  title: _title,
  version: _chosenVersion,
  steps: [
    DesktopTourStep(
      targets: [kTourSubjectsChosenBin],
      text: 'Per rimuovere una disciplina selezionata, clicca sul cestino.',
      // Beside the bin it would hide the programmes count on the same row.
      sides: [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.left],
      pad: 4,
      radius: 12,
    ),
    DesktopTourStep(
      targets: [kTourSubjectsChosenRow],
      text: 'Per modificare i percorsi, clicca sul nome della disciplina.',
      sides: [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above],
      pad: 4,
      radius: 18,
    ),
  ],
);

const DesktopTour subjectsProgramsTour = DesktopTour(
  slug: 'subjects.programs',
  title: _title,
  version: _programsVersion,
  steps: [
    DesktopTourStep(
      targets: [kTourProgramsList],
      text: "L'elenco mostra tutti gli indirizzi in cui la disciplina viene studiata. Puoi selezionare quelli in cui "
          'desideri insegnare.',
      sides: _besideFirst,
      pad: 6,
      radius: 31,
    ),
    DesktopTourStep(
      targets: [kTourProgramsSector],
      text: 'Puoi selezionare direttamente un intero settore.',
      sides: _rightFirst,
      pad: 6,
      radius: 10,
    ),
    DesktopTourStep(
      targets: [kTourProgramsSingle],
      text: 'Altrimenti, puoi selezionare i singoli percorsi di studio.',
      sides: _rightFirst,
      pad: 4,
      radius: 16,
    ),
    DesktopTourStep(targets: [kTourProgramsConfirm], text: _confirm, sides: _rightFirst, pad: 6, radius: 17),
  ],
);
