import '../../core/language/app_language.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/desktop_tour.dart';
import 'home_tour_texts.dart';

const String kTourHomeToday = 'home.today';
const String kTourHomeMonth = 'home.month';
const String kTourHomeNotifications = 'home.notifications';
const String kTourHomeNotices = 'home.notices';

const String _title = 'Home';

// One tour per role, so whoever has two sees both. Bump a version on every change to that tour.
const int _teacherVersion = 2;
const int _studentVersion = 2;
const int _parentVersion = 2;

const List<DesktopTourSide> _below = [DesktopTourSide.below];
const List<DesktopTourSide> _rightOf = [DesktopTourSide.right, DesktopTourSide.below];
const List<DesktopTourSide> _leftOf = [DesktopTourSide.left, DesktopTourSide.below];
const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];

// Round the home cards, whose corners are 28.
const double _cardPad = 6;
const double _cardRadius = 34;

void _openMenu() => AppTopBar.userMenuOpen.value = true;
void _closeMenu() => AppTopBar.userMenuOpen.value = false;

// Every desktop home tour ends on the bar; clicking a section leaves the home and ends it.
List<DesktopTourStep> homeBarTourSteps({required bool manyRoles})
{
  return [
    DesktopTourStep(
      targets: const [kTourTopBar],
      text: tr(
        "Attraverso questa barra puoi raggiungere tutti i menù dell'applicazione.",
        'Through this bar you can reach all the menus of the app.',
      ),
      sides: _below,
      pad: 6,
      radius: 46,
    ),
    DesktopTourStep(
      targets: const [kTourTopBarRole],
      text: tr(
        "Qui puoi vedere il ruolo con cui stai utilizzando l'applicazione, che determina le funzionalità a "
            'cui puoi accedere e le voci di menù che visualizzi. Cliccaci sopra.',
        'Here you can see the role you are using the app with, which decides the features you can access '
            'and the menu items you see. Click on it.',
      ),
      sides: _below,
      radius: 16,
      listen: AppTopBar.userMenuOpen,
      reached: () => AppTopBar.userMenuOpen.value,
    ),
    DesktopTourStep(
      targets: const [kTourTopBarMenu],
      text: manyRoles
          ? tr(
              "Da qui puoi accedere alle tue informazioni personali e alle impostazioni dell'app. "
                  'Puoi inoltre cambiare ruolo e uscire dal tuo account.',
              'From here you can reach your personal information and the app settings. '
                  'You can also switch role and sign out of your account.',
            )
          : tr(
              "Da qui puoi accedere alle tue informazioni personali e alle impostazioni dell'app. "
                  'Puoi inoltre uscire dal tuo account.',
              'From here you can reach your personal information and the app settings. '
                  'You can also sign out of your account.',
            ),
      sides: const [DesktopTourSide.left, DesktopTourSide.below],
      radius: 24,
      undo: _closeMenu,
    ),
    DesktopTourStep(
      targets: const [kTourTopBarSections],
      text: tr(
        "Qui trovi tutte le sezioni dell'applicazione: cliccane una per aprirla.",
        'Here you find all the sections of the app: click one to open it.',
      ),
      sides: _below,
      pad: 12,
      radius: 18,
      doneByLeaving: true,
      enter: _closeMenu,
      undo: _openMenu,
    ),
  ];
}

DesktopTour teacherHomeTour({required bool manyRoles})
{
  return _homeTour(
    slug: 'home.teacher',
    version: _teacherVersion,
    today: kTeacherTodayTourText,
    month: kTeacherMonthTourText,
    manyRoles: manyRoles,
  );
}

// [answeredFor]: a parent answers for the student, who then sees no payments.
DesktopTour studentHomeTour({required bool manyRoles, required bool answeredFor})
{
  return _homeTour(
    slug: 'home.student',
    version: _studentVersion,
    today: kStudentTodayTourText,
    month: studentMonthTourText(answeredFor: answeredFor),
    manyRoles: manyRoles,
  );
}

// [genders] has one entry per child, 'F' for a daughter.
DesktopTour parentHomeTour({required bool manyRoles, required List<String?> genders})
{
  return _homeTour(
    slug: 'home.parent',
    version: _parentVersion,
    today: parentTodayTourText(genders),
    month: parentMonthTourText(genders),
    manyRoles: manyRoles,
  );
}

DesktopTour _homeTour({
  required String slug,
  required int version,
  required String today,
  required String month,
  required bool manyRoles,
})
{
  return DesktopTour(
    slug: slug,
    title: _title,
    version: version,
    steps: [
      DesktopTourStep(
        targets: const [kTourHomeToday],
        text: today,
        sides: _rightOf,
        pad: _cardPad,
        radius: _cardRadius,
        reveal: true,
      ),
      DesktopTourStep(
        targets: const [kTourHomeMonth],
        text: month,
        sides: _leftOf,
        pad: _cardPad,
        radius: _cardRadius,
        reveal: true,
      ),
      // One hole round both cards would light part of the day's card too.
      DesktopTourStep(
        targets: const [kTourHomeNotifications, kTourHomeNotices],
        apart: true,
        text: kHomeNoticesTourText,
        sides: _over,
        pad: _cardPad,
        radius: _cardRadius,
        reveal: true,
      ),
      ...homeBarTourSteps(manyRoles: manyRoles),
    ],
  );
}
