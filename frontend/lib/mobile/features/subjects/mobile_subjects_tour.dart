import 'package:flutter/material.dart';

import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'widgets/mobile_subject_card.dart';

const String _title = 'Discipline';

// Bump a version on every change to that tour.
const String _slug = 'subjects';
const int _version = 8;

const String _movedSlug = 'subjects.moved';
const int _movedVersion = 2;

const String _swipeSlug = 'subjects.swipe';
const int _swipeVersion = 1;

String subjectsTourTab(int page) => 'subjects.tab.$page';
String subjectsTourCard(String entry) => 'subjects.card.$entry';

const String kSubjectsTourHeld = 'subjects.held';
const String kSubjectsTourFilters = 'subjects.filters';
const String kSubjectsTourOpen = 'subjects.open';
const String kSubjectsTourAdd = 'subjects.add';

const String _held = 'Qui trovi le discipline che hai scelto di insegnare.';
const String _filters =
    'Puoi filtrare le discipline disponibili per area (umanistica, linguistica, scientifica, servizi) oppure cercarle '
    'direttamente tramite la barra in alto.';
const String _toOpen = 'Tocca «Da scegliere».';
const String _open =
    'Queste sono tutte le discipline che puoi decidere di insegnare in Associazione. Selezionandone una puoi '
    'indicare gli indirizzi di studio in cui sei disponibile a tenere lezioni.';
const String _add =
    'Con il $kMobileTourGlyph selezioni direttamente la disciplina con tutti i percorsi di studio in cui è offerta.';
const String _moved = "La disciplina è stata spostata tra quelle che hai scelto di insegnare.";
const String _swipe = 'Puoi rimuovere una disciplina anche facendo scorrere la riga verso destra.';

const Duration _pageBack = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

// [canAdd] false: no + to light, the last step is left out.
MobileTour subjectsTour({required PageController pages, required bool Function() canAdd})
{
  bool onPage(int index) => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  return MobileTour(
    slug: _slug,
    title: _title,
    version: _version,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      const MobileTourStep(text: _held, shown: [kSubjectsTourHeld]),
      const MobileTourStep(text: _filters, shown: [kSubjectsTourFilters]),
      MobileTourStep(
        text: _toOpen,
        touched: [subjectsTourTab(1)],
        watch: pages,
        reached: () => onPage(1),
        undo: ()
        {
          if (pages.hasClients)
          {
            pages.animateToPage(0, duration: _pageBack, curve: Curves.easeInOutCubic);
          }
        },
      ),
      // Longer than any screen: read where it stands.
      const MobileTourStep(text: _open, shown: [kSubjectsTourOpen], scrolls: false),
      // Read only: what to take is the person's own choice.
      MobileTourStep(
        text: _add,
        shown: const [kSubjectsTourAdd],
        glyph: (size) => mobileSubjectAddCircle(size, iconShare: 0.78),
        present: canAdd,
      ),
    ],
  );
}

// Only to ask whether the main tour was seen.
MobileTour subjectsMainTour(PageController pages) => subjectsTour(pages: pages, canAdd: () => false);

// A discipline just taken, lit in the list it went to.
MobileTour subjectsMovedTour(String card)
{
  final String target = subjectsTourCard(card);

  return MobileTour(
    slug: _movedSlug,
    title: _title,
    version: _movedVersion,
    steps: [MobileTourStep(text: _moved, shown: [target], reveal: target)],
  );
}

// The row shows the swipe while lit.
MobileTour subjectsSwipeTour(String card)
{
  final String target = subjectsTourCard(card);

  return MobileTour(
    slug: _swipeSlug,
    title: _title,
    version: _swipeVersion,
    steps: [MobileTourStep(text: _swipe, shown: [target], reveal: target)],
  );
}

// The programmes sheet: a new discipline's, or a held one's, which adds its removal.
enum ProgramsMark { list, all, groups, open, single, confirm, remove }

// Bump a version on every change to that step.
const String _programsSlug = 'subjects.programs';

const Map<ProgramsMark, int> _programsVersions = {
  ProgramsMark.list: 4,
  ProgramsMark.all: 2,
  ProgramsMark.groups: 2,
  ProgramsMark.open: 4,
  ProgramsMark.single: 5,
  ProgramsMark.confirm: 5,
  ProgramsMark.remove: 8,
};

const Map<ProgramsMark, String> _programsTexts = {
  ProgramsMark.list:
      "L'elenco mostra tutti gli indirizzi in cui la disciplina viene studiata. Puoi selezionare quelli in cui "
      'desideri insegnare.',
  ProgramsMark.all: 'Con «Seleziona tutto» selezioni immediatamente tutti i percorsi.',
  ProgramsMark.groups:
      'Puoi selezionare direttamente un intero grado scolastico, un settore o un gruppo di anni (biennio, triennio).',
  ProgramsMark.open: 'Tocca un settore per vedere i percorsi che lo compongono.',
  ProgramsMark.single: 'Puoi selezionare i singoli percorsi di studio in cui vuoi insegnare.',
  ProgramsMark.confirm: 'Quando hai finito, tocca «Conferma».',
  ProgramsMark.remove: 'Con «Rimuovi disciplina» smetti di insegnarla.',
};

// Set once a sector of the sheet is opened: the tour asks for it with a touch.
final ValueNotifier<bool> mobileProgramsSectorOpened = ValueNotifier(false);

String programsTourTarget(ProgramsMark mark) => 'subjects.programs.${mark.name}';

// The group rows lit together: a level, its first cycle and that cycle's first sector.
enum ProgramsGroupPart { level, cycle, sector }

String programsGroupTarget(ProgramsGroupPart part) => 'subjects.programs.groups.${part.name}';

(String, int) _programsSeen(ProgramsMark mark) => ('$_programsSlug.${mark.name}', _programsVersions[mark]!);

MobileTourStep _programsStep(ProgramsMark mark)
{
  final String target = programsTourTarget(mark);
  final String text = _programsTexts[mark]!;
  final (String, int) seen = _programsSeen(mark);

  return switch (mark)
  {
    ProgramsMark.list => MobileTourStep(text: text, shown: [target], scrolls: false, seen: seen),
    ProgramsMark.all => MobileTourStep(text: text, shown: [target], seen: seen),
    ProgramsMark.groups => MobileTourStep(
        text: text,
        shown: [for (final ProgramsGroupPart part in ProgramsGroupPart.values) programsGroupTarget(part)],
        // One hole round the three rows: apart, their holes overlapped.
        joined: true,
        present: () => isMobileTourTargetShown(programsGroupTarget(ProgramsGroupPart.level)),
        seen: seen,
      ),
    // The forward button opens the sector the groups step lit, not whatever row is in the middle.
    ProgramsMark.open => MobileTourStep(
        text: text,
        touched: [target],
        tapping: programsGroupTarget(ProgramsGroupPart.sector),
        reveal: target,
        watch: mobileProgramsSectorOpened,
        reached: () => mobileProgramsSectorOpened.value,
        present: () => isMobileTourTargetShown(target),
        seen: seen,
      ),
    ProgramsMark.single => MobileTourStep(
        text: text,
        touched: [target],
        reveal: target,
        tapMovesOn: true,
        // The touch that opens a sector moves the tour on before its rows are built.
        present: () => mobileProgramsSectorOpened.value || isMobileTourTargetShown(target),
        coming: () => isMobileTourTargetShown(programsTourTarget(ProgramsMark.open)),
        seen: seen,
      ),
    // Read only: confirming or removing is the person's own choice.
    ProgramsMark.confirm || ProgramsMark.remove => MobileTourStep(text: text, shown: [target], seen: seen),
  };
}

// The marks of the sheet never seen; a held discipline's sheet also has its removal.
Future<void> startProgramsTour({required String taxCode, required bool held}) async
{
  final List<ProgramsMark> fresh = [];

  for (final ProgramsMark mark in ProgramsMark.values)
  {
    if (mark == ProgramsMark.remove && !held)
    {
      continue;
    }

    final (String slug, int version) = _programsSeen(mark);
    final MobileTour alone = MobileTour(slug: slug, title: _title, version: version, steps: const []);

    if (!await isMobileTourSeen(taxCode: taxCode, tour: alone))
    {
      fresh.add(mark);
    }
  }

  if (fresh.isEmpty)
  {
    return;
  }

  final (String slug, int version) = _programsSeen(fresh.first);

  await startMobileTourOnce(
    taxCode: taxCode,
    tour: MobileTour(
      slug: slug,
      title: _title,
      version: version,
      steps: [for (final ProgramsMark mark in fresh) _programsStep(mark)],
      coversIfClosed: [for (final ProgramsMark mark in ProgramsMark.values) _programsSeen(mark)],
      // The sheet closed under it: it comes back the next time.
      leave: MobileNavSheet.hidden,
      left: () => !MobileNavSheet.hidden.value,
    ),
  );
}
