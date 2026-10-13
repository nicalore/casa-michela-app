import 'package:flutter/material.dart';

import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';

const String _title = 'Associazione';

// Bump a version on every change to that tour.
const String _slug = 'association.teacher';
const int _version = 4;
const String _parentSlug = 'association.parent';
const int _parentVersion = 2;
const String _studentSlug = 'association.student';
const int _studentVersion = 1;

// A teacher's sheet opened from «Docenti», the first time; a student's keeps the parents' slug.
const String _teacherSheetSlug = 'association.parent.teacher';
const int _teacherSheetVersion = 2;

// What shows only sometimes; each has a one-step tour for when the main one did not show it.
enum AssociationMark { variation, pinned }

const Map<AssociationMark, int> _markVersions = {
  AssociationMark.variation: 1,
  AssociationMark.pinned: 1,
};

// The day picker of the notices, the first time it opens.
const String _pickerSlug = 'association.picker';
const int _pickerVersion = 1;

String associationTourTab(int page) => 'association.tab.$page';

const String kAssociationTourDay = 'association.day';
const String kAssociationTourWeek = 'association.week';
const String kAssociationTourDays = 'association.days';
const String kAssociationTourStandard = 'association.standard';
const String kAssociationTourVariations = 'association.variations';
const String kAssociationTourNotices = 'association.notices';
const String kAssociationTourTop = 'association.top';
const String kAssociationTourPickerDays = 'association.picker.days';
const String kAssociationTourReport = 'association.report';
const String kAssociationTourTeachersTop = 'association.teachers.top';
const String kAssociationTourTeacherProfile = 'association.teacher.profile';
const String kAssociationTourTeacherSubjects = 'association.teacher.subjects';
const String kAssociationTourTeacherOpinion = 'association.teacher.opinion';

String associationTourMark(AssociationMark mark) => 'association.${mark.name}';

const String _day = "Qui puoi consultare gli orari di apertura dell'Associazione, giorno per giorno.";
const String _week =
    'Puoi scorrere tra le settimane con le frecce, oppure toccare le date al centro per scegliere una settimana '
    'qualsiasi.';
const String _days =
    'Toccando un giorno ne visualizzi gli orari. I pallini indicano le modalità previste per le lezioni di quel '
    'giorno: verde per le lezioni in presenza, arancione per quelle online.';
const String _standard = "Questi sono gli orari di apertura ufficiali dell'Associazione, senza eventuali variazioni.";
const String _variations =
    "Queste sono le prossime variazioni rispetto all'orario standard, previste in occasione di festività o per altre "
    'esigenze.';
const String _toNotices = 'Tocca «Comunicazioni e avvisi».';
const String _notices = "Qui puoi leggere tutti i messaggi inviati dal Direttivo dell'Associazione.";
const String _top =
    'Puoi ordinare i messaggi dal più recente al meno recente o viceversa, filtrare gli avvisi per una data specifica '
    'oppure cercarli in base al titolo o al contenuto.';
const String _picker = 'Il pallino sotto una data indica la presenza di un messaggio inviato in quella data.';
const String _toSubjects = 'Tocca «Discipline».';
const String _subjects = 'In questa pagina trovi tutte le discipline che vengono insegnate in Associazione.';
const String _report = 'Se manca una disciplina che ti interessa, puoi segnalarlo tramite questo bottone.';
const String _toTeachers = 'Tocca «Docenti».';
const String _teacherFacts =
    'Da qui puoi vedere la formazione del docente e le discipline che insegna in Associazione.';

bool _daughter(String? gender) => gender == 'F';

// Who reads the subjects and the teachers: a parent for their children, or a student for themselves.
// [opinions]: by gender, those whose opinions on the teachers are given; none, no opinions to give.
class AssociationReader
{
  final bool self;
  final List<String?> opinions;

  const AssociationReader.parent(this.opinions) : self = false;

  const AssociationReader.student(this.opinions) : self = true;
}

String _teachers(AssociationReader reader)
{
  const String intro = "In questa pagina trovi tutti i docenti che collaborano con l'Associazione. "
      'Toccando su ciascuno di essi puoi visualizzarne alcune informazioni';

  final List<String?> opinions = reader.opinions;

  if (opinions.isEmpty)
  {
    return '$intro.';
  }

  final String gotOn = reader.self
      ? 'non ti sei ${_daughter(opinions.first) ? 'trovata' : 'trovato'}'
      : opinions.length == 1
          ? (_daughter(opinions.single) ? 'tua figlia non si è trovata' : 'tuo figlio non si è trovato')
          : (opinions.every(_daughter) ? 'le tue figlie non si sono trovate' : 'i tuoi figli non si sono trovati');

  return '$intro e, se lo desideri, indicare se $gotOn bene.';
}

String _teachersTop(AssociationReader reader)
{
  final List<String?> opinions = reader.opinions;

  if (opinions.isEmpty)
  {
    return 'Puoi ordinare i docenti per nome o cognome e filtrarli per disciplina insegnata.';
  }

  final String whose = reader.self
      ? ''
      : opinions.length == 1
          ? (_daughter(opinions.single) ? ' da tua figlia' : ' da tuo figlio')
          : (opinions.every(_daughter) ? ' dalle tue figlie' : ' dai tuoi figli');

  return 'Puoi ordinare i docenti per nome o cognome, filtrarli per disciplina insegnata, o visualizzare solo quelli '
      'non graditi$whose.';
}

String _teacherOpinion(AssociationReader reader)
{
  final List<String?> opinions = reader.opinions;

  if (reader.self)
  {
    return 'Puoi segnalare se preferisci non fare lezione con il docente.';
  }

  final String who = opinions.length == 1
      ? (_daughter(opinions.single) ? 'tua figlia preferisce' : 'tuo figlio preferisce')
      : (opinions.every(_daughter) ? 'le tue figlie preferiscono' : 'i tuoi figli preferiscono');

  return 'Puoi segnalare se $who non fare lezione con il docente.';
}

const Map<AssociationMark, String> _markTexts = {
  AssociationMark.variation:
      "Questo simbolo indica che l'orario per questo giorno è diverso rispetto all'orario standard.",
  AssociationMark.pinned:
      'I messaggi fissati in alto sono particolarmente importanti: ti preghiamo di leggerli con attenzione.',
};

const Duration _pageBack = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

(String, int) _markSeen(AssociationMark mark) => ('association.${mark.name}', _markVersions[mark]!);

MobileTourStep _markStep(AssociationMark mark)
{
  final String target = associationTourMark(mark);

  return MobileTourStep(text: _markTexts[mark]!, shown: [target], reveal: target, seen: _markSeen(mark));
}

// [tablet]: the week is a table, without the row of days. [variations]: upcoming ones listed.
// [pinned]: the notices hold a pinned one, lit once its tab shows.
// [reader]: a parent or a student, whose subjects and teachers come before the notices; null for a teacher.
MobileTour associationTour({
  required PageController pages,
  required bool tablet,
  required bool variations,
  required bool Function() pinned,
  AssociationReader? reader,
})
{
  final int notices = reader != null ? 3 : 1;

  bool onPage(int index) => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  // Stepping back to it turns back to [from].
  MobileTourStep toTab(String text, int index, int from)
  {
    return MobileTourStep(
      text: text,
      touched: [associationTourTab(index)],
      reveal: associationTourTab(index),
      watch: pages,
      reached: () => onPage(index),
      undo: ()
      {
        if (pages.hasClients)
        {
          pages.animateToPage(from, duration: _pageBack, curve: Curves.easeInOutCubic);
        }
      },
    );
  }

  return MobileTour(
    slug: reader == null ? _slug : (reader.self ? _studentSlug : _parentSlug),
    title: _title,
    version: reader == null ? _version : (reader.self ? _studentVersion : _parentVersion),
    steps: [
      const MobileTourStep(text: _day, shown: [kAssociationTourDay], reveal: kAssociationTourDay),
      MobileTourStep(
        text: _markTexts[AssociationMark.variation]!,
        shown: [associationTourMark(AssociationMark.variation)],
        reveal: associationTourMark(AssociationMark.variation),
        present: () => onPage(0) && isMobileTourTargetShown(associationTourMark(AssociationMark.variation)),
        seen: _markSeen(AssociationMark.variation),
      ),
      const MobileTourStep(text: _week, shown: [kAssociationTourWeek], reveal: kAssociationTourWeek),
      if (!tablet) const MobileTourStep(text: _days, shown: [kAssociationTourDays], reveal: kAssociationTourDays),
      // On the tablet its heading stands apart from the table: both lit as one.
      const MobileTourStep(
        text: _standard,
        shown: [kAssociationTourStandard],
        reveal: kAssociationTourStandard,
        joined: true,
      ),
      if (variations)
        const MobileTourStep(text: _variations, shown: [kAssociationTourVariations], reveal: kAssociationTourVariations),
      if (reader != null) ...[
        toTab(_toSubjects, 1, 0),
        MobileTourStep(text: _subjects, lightsAll: true, present: () => onPage(1), coming: () => true),
        MobileTourStep(
          text: _report,
          shown: const [kAssociationTourReport],
          present: () => onPage(1),
          coming: () => true,
        ),
        toTab(_toTeachers, 2, 1),
        MobileTourStep(text: _teachers(reader), lightsAll: true, present: () => onPage(2), coming: () => true),
        MobileTourStep(
          text: _teachersTop(reader),
          shown: const [kAssociationTourTeachersTop],
          reveal: kAssociationTourTeachersTop,
          present: () => onPage(2),
          coming: () => true,
        ),
      ],
      // The page scrolled down by the steps before: the strip comes back in sight.
      toTab(_toNotices, notices, notices - 1),
      MobileTourStep(
        text: _notices,
        shown: const [kAssociationTourNotices],
        present: () => onPage(notices),
        coming: () => true,
      ),
      MobileTourStep(
        text: _markTexts[AssociationMark.pinned]!,
        shown: [associationTourMark(AssociationMark.pinned)],
        reveal: associationTourMark(AssociationMark.pinned),
        present: () => onPage(notices) && isMobileTourTargetShown(associationTourMark(AssociationMark.pinned)),
        coming: pinned,
        seen: _markSeen(AssociationMark.pinned),
      ),
      MobileTourStep(
        text: _top,
        shown: const [kAssociationTourTop],
        reveal: kAssociationTourTop,
        present: () => onPage(notices),
        coming: () => true,
      ),
    ],
    coversIfClosed: [for (final AssociationMark mark in AssociationMark.values) _markSeen(mark)],
  );
}

// Only to ask whether the main tour was seen: its steps do not matter there.
MobileTour associationMainTour(PageController pages, {AssociationReader? reader})
{
  return associationTour(pages: pages, tablet: false, variations: false, pinned: () => false, reader: reader);
}

MobileTour associationMarkTour(AssociationMark mark)
{
  final (String slug, int version) = _markSeen(mark);

  return MobileTour(slug: slug, title: _title, version: version, steps: [_markStep(mark)]);
}

// Over the picker's sheet; closed under it, it comes again the next time.
MobileTour associationPickerTour()
{
  return MobileTour(
    slug: _pickerSlug,
    title: _title,
    version: _pickerVersion,
    steps: const [MobileTourStep(text: _picker, shown: [kAssociationTourPickerDays])],
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}

// A parent's or a student's; with no opinions to give, no opinion card to light.
MobileTour associationTeacherSheetTour(AssociationReader reader)
{
  return MobileTour(
    slug: _teacherSheetSlug,
    title: _title,
    version: _teacherSheetVersion,
    steps: [
      const MobileTourStep(
        text: _teacherFacts,
        shown: [kAssociationTourTeacherProfile, kAssociationTourTeacherSubjects],
        joined: true,
      ),
      if (reader.opinions.isNotEmpty)
        MobileTourStep(
          text: _teacherOpinion(reader),
          shown: const [kAssociationTourTeacherOpinion],
          reveal: kAssociationTourTeacherOpinion,
        ),
    ],
    // The sheet closed under it: it comes back the next time.
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}
