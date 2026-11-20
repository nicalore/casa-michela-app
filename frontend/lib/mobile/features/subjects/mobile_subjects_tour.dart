import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'widgets/mobile_subject_card.dart';

String get _title => tr('Discipline', 'Disciplines');

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

String get _held => tr('Qui trovi le discipline che hai scelto di insegnare.', 'Here you will find the disciplines you have chosen to teach.');
String get _filters => tr(
  'Puoi filtrare le discipline disponibili per area (umanistica, linguistica, scientifica, servizi) oppure cercarle '
      'direttamente tramite la barra in alto.',
  'You can filter the available disciplines by area (humanities, languages, sciences, services) or search for them '
      'directly with the bar at the top.',
);
String get _toOpen => tr('Tocca «Da scegliere».', 'Tap “To choose”.');
String get _open => tr(
  'Queste sono tutte le discipline che puoi decidere di insegnare in Associazione. Selezionandone una puoi '
      'indicare gli indirizzi di studio in cui sei disponibile a tenere lezioni.',
  'These are all the disciplines you can choose to teach at the Association. By choosing one you can set the '
      'courses of study you are available to teach in.',
);
String get _add => tr(
  'Con il $kMobileTourGlyph selezioni direttamente la disciplina con tutti i percorsi di studio in cui è offerta.',
  'With the $kMobileTourGlyph you choose the discipline straight away, with all the study programmes it is offered in.',
);
String get _moved => tr(
  'La disciplina è stata spostata tra quelle che hai scelto di insegnare.',
  'The discipline has been moved among those you have chosen to teach.',
);
String get _swipe => tr(
  'Puoi rimuovere una disciplina anche facendo scorrere la riga verso destra.',
  'You can also remove a discipline by swiping its row to the right.',
);

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
      MobileTourStep(text: _held, shown: const [kSubjectsTourHeld]),
      MobileTourStep(text: _filters, shown: const [kSubjectsTourFilters]),
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
      MobileTourStep(text: _open, shown: const [kSubjectsTourOpen], scrolls: false),
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
  ProgramsMark.open: 5,
  ProgramsMark.single: 6,
  ProgramsMark.confirm: 5,
  ProgramsMark.remove: 8,
};

Map<ProgramsMark, String> get _programsTexts => {
  ProgramsMark.list: tr(
    "L'elenco mostra tutti gli indirizzi in cui la disciplina viene studiata. Puoi selezionare quelli in cui "
        'desideri insegnare.',
    'The list shows all the courses of study where the discipline is studied. You can choose the ones you want to '
        'teach in.',
  ),
  ProgramsMark.all: tr(
    'Con «Seleziona tutto» selezioni immediatamente tutti i percorsi.',
    'With “Select all” you choose all the programmes at once.',
  ),
  ProgramsMark.groups: tr(
    'Puoi selezionare direttamente un intero grado scolastico, un settore o un gruppo di anni (biennio, triennio).',
    'You can choose a whole school level, a sector or a group of years (first two years, last three years) at once.',
  ),
  ProgramsMark.open: tr(
    'Tocca un settore per vedere i percorsi che lo compongono.',
    'Tap a sector to see the programmes it is made of.',
  ),
  ProgramsMark.single: tr(
    'Puoi selezionare i singoli percorsi di studio in cui vuoi insegnare.',
    'You can choose the single study programmes you want to teach in.',
  ),
  ProgramsMark.confirm: tr('Quando hai finito, tocca «Conferma».', 'When you have finished, tap “Confirm”.'),
  ProgramsMark.remove: tr(
    'Con «Rimuovi disciplina» smetti di insegnarla.',
    'With “Remove discipline” you stop teaching it.',
  ),
};

// Set once a sector of the sheet is opened: the tour asks for it with a touch. Reset: that sector closes.
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
        // The sheet closes the sector it opened; still set, a new touch would change nothing.
        undo: () => mobileProgramsSectorOpened.value = false,
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
