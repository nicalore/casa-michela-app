import 'package:flutter/material.dart';

import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'widgets/mobile_subject_card.dart';

const String _title = 'Discipline';

// Bump a version on every change to that tour.
const String _slug = 'subjects';
const int _version = 5;

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
      MobileTourStep(
        text: _add,
        touched: const [kSubjectsTourAdd],
        glyph: (size) => mobileSubjectAddCircle(size, iconShare: 0.78),
        tapMovesOn: true,
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
enum ProgramsMark { list, sector, single, confirm, remove }

// Bump a version on every change to that step.
const String _programsSlug = 'subjects.programs';

const Map<ProgramsMark, int> _programsVersions = {
  ProgramsMark.list: 2,
  ProgramsMark.sector: 2,
  ProgramsMark.single: 1,
  ProgramsMark.confirm: 1,
  ProgramsMark.remove: 4,
};

const Map<ProgramsMark, String> _programsTexts = {
  ProgramsMark.list:
      "L'elenco mostra tutti gli indirizzi in cui la disciplina viene studiata. Puoi selezionare quelli in cui "
      'desideri insegnare.',
  ProgramsMark.sector: 'Puoi selezionare direttamente un intero settore.',
  ProgramsMark.single: 'Altrimenti, puoi selezionare i singoli percorsi di studio.',
  ProgramsMark.confirm: 'Quando hai finito, tocca «Conferma».',
  ProgramsMark.remove: 'Con «Rimuovi disciplina» smetti di insegnarla.',
};

String programsTourTarget(ProgramsMark mark) => 'subjects.programs.${mark.name}';

(String, int) _programsSeen(ProgramsMark mark) => ('$_programsSlug.${mark.name}', _programsVersions[mark]!);

MobileTourStep _programsStep(ProgramsMark mark)
{
  final String target = programsTourTarget(mark);
  final String text = _programsTexts[mark]!;
  final (String, int) seen = _programsSeen(mark);

  return switch (mark)
  {
    ProgramsMark.list => MobileTourStep(text: text, shown: [target], scrolls: false, seen: seen),
    ProgramsMark.sector || ProgramsMark.single =>
      MobileTourStep(text: text, touched: [target], tapMovesOn: true, seen: seen),
    // "Conferma" closes the sheet, "Rimuovi" turns it to the confirmation: nothing left to light.
    ProgramsMark.confirm || ProgramsMark.remove =>
      MobileTourStep(text: text, touched: [target], tapEnds: true, seen: seen),
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
