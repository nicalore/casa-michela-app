import 'package:flutter/widgets.dart';

import '../../../features/home/home_tour_texts.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';

const String kHomeTourTitle = 'Home';

// One tour per role, so whoever has two sees both. Bump a version on every change to that tour.
const String _teacherSlug = 'home.teacher';
const int _teacherVersion = 9;
const String _studentSlug = 'home.student';
const int _studentVersion = 6;
const String _parentSlug = 'home.parent';
const int _parentVersion = 5;

// Phones: the three names of the page strip, and the three pages they show.
const List<String> kHomeTourTabs = ['home.tab.today', 'home.tab.month', 'home.tab.notices'];
const List<String> kHomeTourPages = ['home.page.today', 'home.page.month', 'home.page.notices'];

// Tablets: the three sections, side by side and below.
const String kHomeTourToday = 'home.today';
const String kHomeTourMonth = 'home.month';
const String kHomeTourNotices = 'home.notices';

const EdgeInsets kHomeTourSectionInflate = EdgeInsets.all(12);
const double kHomeTourSectionRadius = 22;

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
    today: kTeacherTodayTourText,
    month: kTeacherMonthTourText,
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
    today: kStudentTodayTourText,
    month: studentMonthTourText(answeredFor: answeredFor),
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
    today: parentTodayTourText(genders),
    month: parentMonthTourText(genders),
    tablet: tablet,
    pages: pages,
  );
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
        const MobileTourStep(text: kHomeNoticesTourText, shown: [kHomeTourNotices], reveal: kHomeTourNotices),
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
      MobileTourStep(text: kHomeNoticesTourText, shown: [kHomeTourPages[2]]),
      ...menu,
    ],
  );
}
