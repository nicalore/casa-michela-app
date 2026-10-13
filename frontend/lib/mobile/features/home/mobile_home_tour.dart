import 'package:flutter/widgets.dart';

import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';

const String kHomeTourTitle = 'Home';

// One tour per role, so whoever has two sees both. Bump a version on every change to that tour.
const String _teacherSlug = 'home.teacher';
const int _teacherVersion = 8;
const String _studentSlug = 'home.student';
const int _studentVersion = 5;
const String _parentSlug = 'home.parent';
const int _parentVersion = 4;

// Phones: the three names of the page strip, and the three pages they show.
const List<String> kHomeTourTabs = ['home.tab.today', 'home.tab.month', 'home.tab.notices'];
const List<String> kHomeTourPages = ['home.page.today', 'home.page.month', 'home.page.notices'];

// Tablets: the three sections, side by side and below.
const String kHomeTourToday = 'home.today';
const String kHomeTourMonth = 'home.month';
const String kHomeTourNotices = 'home.notices';

const EdgeInsets kHomeTourSectionInflate = EdgeInsets.all(12);
const double kHomeTourSectionRadius = 22;

const String _teacherToday = "Qui puoi vedere le disponibilità che hai dato per oggi e l'eventuale convocazione.";
const String _teacherMonth =
    'Qui puoi leggere alcune statistiche sul mese corrente: disponibilità date, ore di lezione e compenso accumulato.';
const String _studentToday = 'Qui puoi vedere un riepilogo degli orari e delle lezioni prenotate per oggi.';
const String _studentMonth =
    'Qui puoi leggere alcune statistiche sul mese corrente: presenze, giorni prenotati e ore di lezione.';

// A student nobody answers for pays too, as parents do.
const String _ownStudentMonth =
    'Qui puoi leggere alcune statistiche sul mese corrente: presenze, giorni prenotati, ore di lezione e pagamenti.';

const String _notices =
    "Qui puoi trovare le notifiche dell'app e le ultime comunicazioni inviate dal Direttivo di Casa Michela.";
const String _sections = "Qui trovi tutte le sezioni dell'applicazione: toccane una per aprirla.";

const String _toMonth = 'Tocca «Questo mese».';
const String _toNotices = 'Tocca «Notifiche e avvisi».';
const String _toMenu = 'Tocca la barra in basso per aprire il menù.';

const Duration _pageBack = Duration(milliseconds: 320);

// A spring settles within a tolerance, never exactly on its end.
const double _settled = 0.001;

bool _menuOpen() => MobileNavSheet.openness.value >= 1 - _settled;

// The last step ends as the menu closes on the section chosen.
bool _menuClosing() => MobileNavSheet.openness.value < 0.5;

MobileTour teacherHomeTour({required bool tablet, required PageController pages})
{
  return _homeTour(
    slug: _teacherSlug,
    version: _teacherVersion,
    today: _teacherToday,
    month: _teacherMonth,
    tablet: tablet,
    pages: pages,
  );
}

// [answeredFor]: a parent answers for the student, who then sees no payments.
MobileTour studentHomeTour({required bool tablet, required PageController pages, required bool answeredFor})
{
  return _homeTour(
    slug: _studentSlug,
    version: _studentVersion,
    today: _studentToday,
    month: answeredFor ? _studentMonth : _ownStudentMonth,
    tablet: tablet,
    pages: pages,
  );
}

// [genders] has one entry per child, 'F' for a daughter.
MobileTour parentHomeTour({required bool tablet, required PageController pages, required List<String?> genders})
{
  return _homeTour(
    slug: _parentSlug,
    version: _parentVersion,
    today: 'Qui puoi vedere un riepilogo delle lezioni prenotate per ${_yourChildren(genders)}.',
    month: 'Qui puoi leggere alcune statistiche sul mese corrente per ${_eachChild(genders)}: presenze, giorni '
        'prenotati, ore di lezione e pagamenti.',
    tablet: tablet,
    pages: pages,
  );
}

bool _daughters(List<String?> genders) => genders.isNotEmpty && genders.every((gender) => gender == 'F');

// Daughters only take the feminine; without children the plural stands.
String _yourChildren(List<String?> genders)
{
  if (genders.length == 1)
  {
    return _daughters(genders) ? 'tua figlia' : 'tuo figlio';
  }

  return _daughters(genders) ? 'le tue figlie' : 'i tuoi figli';
}

String _eachChild(List<String?> genders)
{
  if (genders.length == 1)
  {
    return _daughters(genders) ? 'tua figlia' : 'tuo figlio';
  }

  return _daughters(genders) ? 'ciascuna figlia' : 'ciascun figlio';
}

// A page is described with the forward button, then the next name is touched.
MobileTour _homeTour({
  required String slug,
  required int version,
  required String today,
  required String month,
  required bool tablet,
  required PageController pages,
})
{
  bool onPage(int index) => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  void backTo(int index)
  {
    if (pages.hasClients)
    {
      pages.animateToPage(index, duration: _pageBack, curve: Curves.easeInOutCubic);
    }
  }

  final List<MobileTourStep> menu = [
    MobileTourStep(
      text: _toMenu,
      touched: const [kMobileTourNavSheet],
      watch: MobileNavSheet.openness,
      reached: _menuOpen,
      undo: MobileNavSheet.close,
    ),
    MobileTourStep(
      text: _sections,
      touched: const [kMobileTourNavSections],
      watch: MobileNavSheet.openness,
      reached: _menuClosing,
    ),
  ];

  if (tablet)
  {
    return MobileTour(
      slug: slug,
      title: kHomeTourTitle,
      version: version,
      steps: [
        MobileTourStep(text: today, shown: const [kHomeTourToday], reveal: kHomeTourToday),
        MobileTourStep(text: month, shown: const [kHomeTourMonth], reveal: kHomeTourMonth),
        const MobileTourStep(text: _notices, shown: [kHomeTourNotices], reveal: kHomeTourNotices),
        ...menu,
      ],
    );
  }

  return MobileTour(
    slug: slug,
    title: kHomeTourTitle,
    version: version,
    steps: [
      MobileTourStep(text: today, shown: [kHomeTourPages[0]]),
      MobileTourStep(
        text: _toMonth,
        touched: [kHomeTourTabs[1]],
        watch: pages,
        reached: () => onPage(1),
        undo: () => backTo(0),
      ),
      MobileTourStep(text: month, shown: [kHomeTourPages[1]]),
      MobileTourStep(
        text: _toNotices,
        touched: [kHomeTourTabs[2]],
        watch: pages,
        reached: () => onPage(2),
        undo: () => backTo(1),
      ),
      MobileTourStep(text: _notices, shown: [kHomeTourPages[2]]),
      ...menu,
    ],
  );
}
