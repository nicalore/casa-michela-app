import 'package:flutter/widgets.dart';

import '../../core/language/app_language.dart';
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
const String kTourProgramsAll = 'subjects.programs.all';
const String kTourProgramsBranch = 'subjects.programs.branch';
const String kTourProgramsLevel = 'subjects.programs.level';
const String kTourProgramsCycle = 'subjects.programs.cycle';
const String kTourProgramsSector = 'subjects.programs.sector';
const String kTourProgramsSectors = 'subjects.programs.sectors';
const String kTourProgramsSingle = 'subjects.programs.single';
const String kTourProgramsConfirm = 'subjects.programs.confirm';

// True while the catalogue is open: the page's tour asks for it with a click.
final ValueNotifier<bool> subjectsCatalogueOpen = ValueNotifier(false);

// Set once a sector of the programmes window is opened: its tour asks for it with a click. Reset: that sector closes.
final ValueNotifier<bool> programsSectorOpened = ValueNotifier(false);

String get _title => tr('Discipline', 'Disciplines');

// Bump a version on every change to that tour.
const int _pageVersion = 3;
const int _catalogueVersion = 4;
const int _programsVersion = 7;
const int _chosenVersion = 3;

const List<DesktopTourSide> _belowFirst = [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.right];
const List<DesktopTourSide> _rightFirst = [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.below];
const List<DesktopTourSide> _besideFirst = [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.above];

String get _confirm => tr('Quando hai finito, clicca «Conferma».', 'When you are done, click “Confirm”.');

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
DesktopTour get subjectsPageTour => DesktopTour(
  slug: 'subjects',
  title: _title,
  version: _pageVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourSubjectsHeld],
      text: tr('Qui trovi le discipline che hai scelto di insegnare.', 'Here you find the disciplines you chose to teach.'),
      sides: _belowFirst,
      pad: 8,
      radius: 34,
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsTools],
      text: tr(
        'Con la matita puoi modificare i percorsi di studio di una disciplina, con il cestino puoi rimuoverla.',
        "With the pencil you can change a discipline's study programmes, with the bin you can remove it.",
      ),
      sides: _rightFirst,
      pad: 4,
      radius: 12,
      present: () => isDesktopTourTargetShown(kTourSubjectsTools),
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsAdd],
      text: tr('Clicca «Aggiungi discipline».', 'Click “Add disciplines”.'),
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
DesktopTour get subjectsCatalogueTour => DesktopTour(
  slug: 'subjects.catalogue',
  title: _title,
  version: _catalogueVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourSubjectsFilters],
      text: tr(
        'Puoi filtrare le discipline disponibili per area (umanistica, linguistica, scientifica, servizi) oppure '
            'cercarle direttamente tramite la barra in alto.',
        'You can filter the available disciplines by area (humanities, languages, sciences, services) or search for '
            'them directly with the bar at the top.',
      ),
      sides: _rightFirst,
      pad: 6,
      radius: 31,
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsList],
      text: tr(
        'Queste sono tutte le discipline che puoi decidere di insegnare in Associazione. Selezionandone una puoi '
            'indicare gli indirizzi di studio in cui sei disponibile a tenere lezioni.',
        'These are all the disciplines you can choose to teach at the Association. When you select one you can say '
            'which courses of study you are available to teach in.',
      ),
      sides: _rightFirst,
      pad: 6,
      radius: 31,
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsPlus],
      text: tr(
        'Con il «+» selezioni direttamente la disciplina con tutti i percorsi di studio in cui è offerta.',
        'With “+” you select the discipline straight away, with all the study programmes it is offered in.',
      ),
      sides: _rightFirst,
      pad: 4,
      radius: 12,
      present: () => isDesktopTourTargetShown(kTourSubjectsPlus),
    ),
    DesktopTourStep(targets: const [kTourSubjectsConfirm], text: _confirm, sides: _rightFirst, pad: 6, radius: 17),
  ],
);

// The first time a discipline is chosen in the catalogue.
// The bin is read only, removing is the person's own choice; the name opens the programmes, as on the page.
DesktopTour get subjectsChosenTour => DesktopTour(
  slug: 'subjects.catalogue.chosen',
  title: _title,
  version: _chosenVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourSubjectsChosenBin],
      text: tr('Per rimuovere una disciplina selezionata, clicca sul cestino.', 'To remove a selected discipline, click the bin.'),
      // Beside the bin it would hide the programmes count on the same row.
      sides: const [DesktopTourSide.below, DesktopTourSide.above, DesktopTourSide.left],
      pad: 4,
      radius: 12,
    ),
    DesktopTourStep(
      targets: const [kTourSubjectsChosenRow],
      text: tr(
        'Per modificare i percorsi, clicca sul nome della disciplina.',
        'To change the programmes, click the name of the discipline.',
      ),
      sides: const [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above],
      pad: 4,
      radius: 18,
      clickEnds: true,
    ),
  ],
);

// The group rows lit are those of the first level split further: its first cycle and that cycle's first sector.
DesktopTour get subjectsProgramsTour => DesktopTour(
  slug: 'subjects.programs',
  title: _title,
  version: _programsVersion,
  steps: [
    DesktopTourStep(
      targets: const [kTourProgramsList],
      text: tr(
        "L'elenco mostra tutti gli indirizzi in cui la disciplina viene studiata. Puoi selezionare quelli in cui "
            'desideri insegnare.',
        'The list shows every course of study in which the discipline is taught. You can select the ones you want '
            'to teach in.',
      ),
      sides: _besideFirst,
      pad: 6,
      radius: 31,
    ),
    DesktopTourStep(
      targets: const [kTourProgramsAll],
      text: tr('Con «Seleziona tutto» selezioni immediatamente tutti i percorsi.', 'With “Select all” you select every programme at once.'),
      sides: _belowFirst,
      pad: 6,
      radius: 13,
    ),
    // One hole round the three rows: apart, their holes overlapped.
    DesktopTourStep(
      targets: const [kTourProgramsLevel, kTourProgramsCycle, kTourProgramsSector],
      radius: 19,
      text: tr(
        'Puoi selezionare direttamente un intero grado scolastico, un settore o un gruppo di anni (biennio, '
            'triennio).',
        'You can select a whole school level, a sector or a group of years (first two years, last three years) '
            'straight away.',
      ),
      sides: _rightFirst,
      pad: 6,
      reveal: true,
      revealing: kTourProgramsBranch,
    ),
    DesktopTourStep(
      targets: const [kTourProgramsSectors],
      text: tr('Clicca un settore per vedere i percorsi che lo compongono.', 'Click a sector to see the programmes in it.'),
      sides: _rightFirst,
      pad: 6,
      radius: 19,
      // The forward button opens the sector the groups step lit, not whatever row is in the middle.
      tapping: kTourProgramsSector,
      reveal: true,
      listen: programsSectorOpened,
      reached: () => programsSectorOpened.value,
      present: () => isDesktopTourTargetShown(kTourProgramsSectors),
    ),
    DesktopTourStep(
      targets: const [kTourProgramsSingle],
      text: tr(
        'Puoi selezionare i singoli percorsi di studio in cui vuoi insegnare.',
        'You can select the individual study programmes you want to teach in.',
      ),
      sides: _rightFirst,
      pad: 4,
      radius: 16,
      clickMovesOn: true,
      reveal: true,
      // The window closes the sector it opened; still set, a new click would change nothing.
      undo: () => programsSectorOpened.value = false,
      // The click that opens a sector moves the tour on before its rows are built.
      present: () => programsSectorOpened.value || isDesktopTourTargetShown(kTourProgramsSingle),
      coming: () => isDesktopTourTargetShown(kTourProgramsSectors),
    ),
    DesktopTourStep(targets: const [kTourProgramsConfirm], text: _confirm, sides: _rightFirst, pad: 6, radius: 17),
  ],
);
