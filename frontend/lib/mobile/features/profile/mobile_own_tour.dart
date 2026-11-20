import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'widgets/mobile_detail_card.dart';

// Bump a version on every change to that tour.
const String _slug = 'profile.teacher';
const int _version = 11;
const String _parentSlug = 'profile.parent';
const int _parentVersion = 1;
const String _studentSlug = 'profile.student';
const int _studentVersion = 4;

String ownTourTab(String section) => 'profile.tab.$section';

const String kOwnTourReport = 'profile.report';
const String kOwnTourFace = 'profile.face';
const String kOwnTourStudies = 'profile.studies';
const String kOwnTourStats = 'profile.stats';
const String kOwnTourFilters = 'profile.filters';
const String kOwnTourObservations = 'profile.observations';
const String kOwnTourCriteria = 'profile.criteria';

String get _about => tr(
  'In questo menù puoi consultare tutte le tue informazioni personali.',
  'In this menu you can see all your personal information.',
);
String get _report => tr(
  'Se noti inesattezze o alcune informazioni sono cambiate, ti preghiamo di farcelo sapere.',
  'If you notice any mistakes or some information has changed, please let us know.',
);
String get _faceEdit => tr('Toccando la tua foto profilo puoi modificarla.', 'Tap your profile photo to change it.');
String get _face => tr(
  '$_faceEdit Sarà visibile a studenti e genitori, pertanto scegline una in cui sia presente solo tu e in cui ti si '
      'veda bene in volto.',
  '$_faceEdit Students and parents will see it, so choose one where only you appear and your face can be seen '
      'clearly.',
);
String get _toOther => tr('Tocca «Altre informazioni».', 'Tap “Other information”.');
String get _studies => tr(
  'Puoi modificare in qualsiasi momento le informazioni relative ai tuoi studi. Poiché saranno visibili a studenti e '
      'genitori, ti chiediamo di mantenerle sempre accurate e aggiornate.',
  'You can change the information about your studies at any time. Since students and parents will see it, please '
      'always keep it accurate and up to date.',
);
String get _toStats => tr('Tocca «Statistiche personali».', 'Tap “Personal statistics”.');
String get _stats => tr(
  'Qui puoi vedere le disponibilità che hai dato nel tempo, le discipline che hai insegnato e gli studenti che hai '
      'seguito.',
  'Here you can see the availability you have given over time, the disciplines you have taught and the students '
      'you have followed.',
);
String get _filters => tr(
  "Puoi consultare le statistiche delle lezioni in presenza oppure online, e scegliere l'intervallo di tempo che "
      'desideri analizzare.',
  'You can look at the statistics of in-person or online lessons, and choose the period you want to analyse.',
);
String get _toObservations => tr('Tocca «Osservazioni».', 'Tap “Observations”.');
String get _observations => tr(
  'Qui trovi le osservazioni che gli amministratori scrivono su di te, derivate sia dai feedback ricevuti da '
      'studenti e genitori sulle tue lezioni, sia da una valutazione del tuo operato in base ad alcuni criteri.',
  'Here you will find the observations the administrators write about you, drawn both from the feedback students '
      'and parents give on your lessons and from an assessment of your work against a few criteria.',
);
String get _criteria => tr(
  'In $kMobileTourGlyph trovi i criteri su cui si basa questa valutazione: toccalo per leggerli.',
  'In $kMobileTourGlyph you will find the criteria this assessment is based on: tap it to read them.',
);
String get _studentStats => tr(
  'Qui puoi vedere le presenze che hai fatto nel tempo, le materie su cui hai svolto più ore di lezione e i docenti '
      'con cui hai lavorato di più.',
  'Here you can see your attendance over time, the subjects you have had the most lesson hours in and the teachers '
      'you have worked with the most.',
);

const Duration _pageBack = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

// Statistics tab touched, then stats and filters read there; stepping back turns to page [back].
List<MobileTourStep> _statsSteps({
  required PageController pages,
  required int index,
  required int back,
  required String tab,
  required String stats,
  required String filters,
  required String text,
})
{
  bool onPage() => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  return [
    MobileTourStep(
      text: _toStats,
      touched: [tab],
      reveal: tab,
      watch: pages,
      reached: onPage,
      undo: ()
      {
        if (pages.hasClients)
        {
          pages.animateToPage(back, duration: _pageBack, curve: Curves.easeInOutCubic);
        }
      },
    ),
    MobileTourStep(text: text, shown: [stats], present: onPage, coming: () => true),
    MobileTourStep(text: _filters, shown: [filters], joined: true, present: onPage, coming: () => true),
  ];
}

// [title]: the page's name in the menu. [sections]: the strip's tabs, by name, in order.
// [noted]: the Osservazioni hold a card, whose head has the (i); else it floats above the empty card.
MobileTour ownTour({
  required PageController pages,
  required String title,
  required List<String> sections,
  bool noted = false,
})
{
  final int other = sections.indexOf('other');
  final int stats = sections.indexOf('stats');
  final int observations = sections.indexOf('observations');

  bool onPage(int index) => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  void backTo(int index)
  {
    if (pages.hasClients)
    {
      pages.animateToPage(index, duration: _pageBack, curve: Curves.easeInOutCubic);
    }
  }

  return MobileTour(
    slug: _slug,
    title: title,
    version: _version,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      // About the whole page: nothing singled out.
      MobileTourStep(text: _about, lightsAll: true),
      MobileTourStep(text: _report, shown: const [kOwnTourReport]),
      // Read only: its sheet would hide the page the next steps light.
      MobileTourStep(text: _face, shown: const [kOwnTourFace], reveal: kOwnTourFace),
      if (other >= 0) ...[
        MobileTourStep(
          text: _toOther,
          touched: [ownTourTab('other')],
          reveal: ownTourTab('other'),
          watch: pages,
          reached: () => onPage(other),
          undo: () => backTo(0),
        ),
        MobileTourStep(
          text: _studies,
          shown: const [kOwnTourStudies],
          reveal: kOwnTourStudies,
          present: () => onPage(other),
          coming: () => true,
        ),
      ],
      if (stats >= 0)
        ..._statsSteps(
          pages: pages,
          index: stats,
          back: other >= 0 ? other : 0,
          tab: ownTourTab('stats'),
          stats: kOwnTourStats,
          filters: kOwnTourFilters,
          text: _stats,
        ),
      if (observations >= 0) ...[
        MobileTourStep(
          text: _toObservations,
          touched: [ownTourTab('observations')],
          reveal: ownTourTab('observations'),
          watch: pages,
          reached: () => onPage(observations),
          undo: () => backTo(stats >= 0 ? stats : 0),
        ),
        MobileTourStep(
          text: _observations,
          shown: const [kOwnTourObservations],
          present: () => onPage(observations),
          coming: () => true,
        ),
        // Ends as the criteria sheet rises, which drops the menu bar.
        MobileTourStep(
          text: _criteria,
          touched: const [kOwnTourCriteria],
          glyph: noted ? (size) => MobileCardButton.glyph(Icons.info_outline_rounded, size) : MobileInfoButton.glyph,
          watch: MobileNavSheet.hidden,
          reached: () => MobileNavSheet.hidden.value,
          present: () => onPage(observations),
          coming: () => true,
        ),
      ],
    ],
    // A teacher who is a parent or a student too has read what their tours say.
    covers: const [(_parentSlug, _parentVersion), (_studentSlug, _studentVersion)],
  );
}

// Only to ask whether the tour was seen: its steps do not matter there.
MobileTour ownMainTour(PageController pages) => ownTour(pages: pages, title: '', sections: const []);

// A student who is no teacher: the page, the report, the face, then their statistics.
MobileTour studentOwnTour({required PageController pages, required String title, required List<String> sections})
{
  final int stats = sections.indexOf('stats');

  return MobileTour(
    slug: _studentSlug,
    title: title,
    version: _studentVersion,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      MobileTourStep(text: _about, lightsAll: true),
      MobileTourStep(text: _report, shown: const [kOwnTourReport]),
      MobileTourStep(text: _faceEdit, shown: const [kOwnTourFace], reveal: kOwnTourFace),
      if (stats >= 0)
        ..._statsSteps(
          pages: pages,
          index: stats,
          back: 0,
          tab: ownTourTab('stats'),
          stats: kOwnTourStats,
          filters: kOwnTourFilters,
          text: _studentStats,
        ),
    ],
    // A student who is a parent too has read all the parent's tour says.
    covers: const [(_parentSlug, _parentVersion)],
  );
}

// A parent who is neither teacher nor student: the page, the report, the face.
MobileTour parentOwnTour({required String title})
{
  return MobileTour(
    slug: _parentSlug,
    title: title,
    version: _parentVersion,
    steps: [
      MobileTourStep(text: _about, lightsAll: true),
      MobileTourStep(text: _report, shown: const [kOwnTourReport]),
      MobileTourStep(text: _faceEdit, shown: const [kOwnTourFace], reveal: kOwnTourFace),
    ],
  );
}

// Parents' "Figli" page: the page, the report, then the statistics of the child shown.
const String _childrenSlug = 'children';
const int _childrenVersion = 5;

String get _childrenTitle => tr('Figli', 'Children');

String childrenTourTab(String section) => 'children.tab.$section';

const String kChildrenTourReport = 'children.report';
const String kChildrenTourStats = 'children.stats';
const String kChildrenTourFilters = 'children.filters';

bool _daughter(String? gender) => gender == 'F';

// [genders]: every child's; [shown]: the gender of the child shown.
// [pupil]: the child shown has statistics.
MobileTour childrenTour({
  required PageController pages,
  required List<String> sections,
  required List<String?> genders,
  required String? shown,
  required bool pupil,
})
{
  final int stats = sections.indexOf('stats');

  final String whom = genders.length > 1
      ? (genders.every(_daughter) ? tr('sulle tue figlie', 'your daughters') : tr('sui tuoi figli', 'your children'))
      : (genders.isNotEmpty && _daughter(genders.first) ? tr('su tua figlia', 'your daughter') : tr('su tuo figlio', 'your son'));
  final String yours = _daughter(shown) ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son');

  return MobileTour(
    slug: _childrenSlug,
    title: _childrenTitle,
    version: _childrenVersion,
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      // About the whole page: nothing singled out.
      MobileTourStep(
        text: tr(
          'In questo menù puoi consultare le informazioni personali $whom.',
          'In this menu you can see the personal information about $whom.',
        ),
        lightsAll: true,
      ),
      MobileTourStep(text: _report, shown: const [kChildrenTourReport]),
      if (stats >= 0 && pupil)
        ..._statsSteps(
          pages: pages,
          index: stats,
          back: 0,
          tab: childrenTourTab('stats'),
          stats: kChildrenTourStats,
          filters: kChildrenTourFilters,
          text: tr(
            'Qui puoi vedere le presenze che ha fatto $yours nel tempo, le materie su cui ha svolto più ore di '
                'lezione e i docenti con cui ha lavorato di più.',
            "Here you can see $yours's attendance over time, the subjects with the most lesson hours and the "
                'teachers they have worked with the most.',
          ),
        ),
    ],
  );
}
