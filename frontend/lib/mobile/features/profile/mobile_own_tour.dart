import 'package:flutter/material.dart';

import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'widgets/mobile_detail_card.dart';

// Bump a version on every change to that tour.
const String _slug = 'profile.teacher';
const int _version = 9;
const String _parentSlug = 'profile.parent';
const int _parentVersion = 1;
const String _studentSlug = 'profile.student';
const int _studentVersion = 2;

String ownTourTab(String section) => 'profile.tab.$section';

const String kOwnTourReport = 'profile.report';
const String kOwnTourFace = 'profile.face';
const String kOwnTourStudies = 'profile.studies';
const String kOwnTourStats = 'profile.stats';
const String kOwnTourFilters = 'profile.filters';
const String kOwnTourObservations = 'profile.observations';
const String kOwnTourCriteria = 'profile.criteria';

const String _about = 'In questo menù puoi consultare tutte le tue informazioni personali.';
const String _report = 'Se noti inesattezze o alcune informazioni sono cambiate, ti preghiamo di farcelo sapere.';
const String _faceEdit = 'Toccando la tua foto profilo puoi modificarla.';
const String _face =
    '$_faceEdit Sarà visibile a studenti e genitori, pertanto scegline una in cui sia presente solo tu e in cui ti si '
    'veda bene in volto.';
const String _toOther = 'Tocca «Altre informazioni».';
const String _studies =
    'Puoi modificare in qualsiasi momento le informazioni relative ai tuoi studi. Poiché saranno visibili a studenti e '
    'genitori, ti chiediamo di mantenerle sempre accurate e aggiornate.';
const String _toStats = 'Tocca «Statistiche personali».';
const String _stats =
    'Qui puoi vedere le disponibilità che hai dato nel tempo, le discipline che hai insegnato e gli studenti che hai '
    'seguito.';
const String _filters =
    "Puoi consultare le statistiche delle lezioni in presenza oppure online, e scegliere l'intervallo di tempo che "
    'desideri analizzare.';
const String _toObservations = 'Tocca «Osservazioni».';
const String _observations =
    'Qui trovi le osservazioni che gli amministratori scrivono su di te, derivate sia dai feedback ricevuti da '
    'studenti e genitori sulle tue lezioni, sia da una valutazione del tuo operato in base ad alcuni criteri.';
const String _criteria = 'In $kMobileTourGlyph trovi i criteri su cui si basa questa valutazione: toccalo per leggerli.';
const String _studentStats =
    'Qui puoi vedere le presenze che hai fatto nel tempo, le materie su cui hai svolto più ore di lezione e i docenti '
    'con cui hai lavorato di più.';

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
    steps: [
      // About the whole page: nothing singled out.
      const MobileTourStep(text: _about, lightsAll: true),
      const MobileTourStep(text: _report, shown: [kOwnTourReport]),
      // Read only: its sheet would hide the page the next steps light.
      const MobileTourStep(text: _face, shown: [kOwnTourFace], reveal: kOwnTourFace),
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
    steps: [
      const MobileTourStep(text: _about, lightsAll: true),
      const MobileTourStep(text: _report, shown: [kOwnTourReport]),
      const MobileTourStep(text: _faceEdit, shown: [kOwnTourFace], reveal: kOwnTourFace),
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
    steps: const [
      MobileTourStep(text: _about, lightsAll: true),
      MobileTourStep(text: _report, shown: [kOwnTourReport]),
      MobileTourStep(text: _faceEdit, shown: [kOwnTourFace], reveal: kOwnTourFace),
    ],
  );
}

// Parents' "Figli" page: the page, the report, then the statistics of the child shown.
const String _childrenSlug = 'children';
const int _childrenVersion = 3;

const String _childrenTitle = 'Figli';

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
      ? (genders.every(_daughter) ? 'sulle tue figlie' : 'sui tuoi figli')
      : (genders.isNotEmpty && _daughter(genders.first) ? 'su tua figlia' : 'su tuo figlio');
  final String yours = _daughter(shown) ? 'tua figlia' : 'tuo figlio';

  return MobileTour(
    slug: _childrenSlug,
    title: _childrenTitle,
    version: _childrenVersion,
    steps: [
      // About the whole page: nothing singled out.
      MobileTourStep(text: 'In questo menù puoi consultare le informazioni personali $whom.', lightsAll: true),
      const MobileTourStep(text: _report, shown: [kChildrenTourReport]),
      if (stats >= 0 && pupil)
        ..._statsSteps(
          pages: pages,
          index: stats,
          back: 0,
          tab: childrenTourTab('stats'),
          stats: kChildrenTourStats,
          filters: kChildrenTourFilters,
          text: 'Qui puoi vedere le presenze che ha fatto $yours nel tempo, le materie su cui ha svolto più ore di '
              'lezione e i docenti con cui ha lavorato di più.',
        ),
    ],
  );
}
