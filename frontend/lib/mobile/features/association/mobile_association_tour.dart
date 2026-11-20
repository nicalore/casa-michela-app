import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';

String get _title => tr('Associazione', 'Association');

// Bump a version on every change to that tour.
const String _slug = 'association.teacher';
const int _version = 6;
const String _parentSlug = 'association.parent';
const int _parentVersion = 4;
const String _studentSlug = 'association.student';
const int _studentVersion = 3;

// A teacher's sheet opened from "Docenti", the first time; a student's keeps the parents' slug.
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

String get _day => tr(
  "Qui puoi consultare gli orari di apertura dell'Associazione, giorno per giorno.",
  "Here you can see the Association's opening hours, day by day.",
);
String get _week => tr(
  'Puoi scorrere tra le settimane con le frecce, oppure toccare le date al centro per scegliere una settimana '
      'qualsiasi.',
  'You can move between weeks with the arrows, or tap the dates in the middle to choose any week.',
);
String get _days => tr(
  'Toccando un giorno ne visualizzi gli orari. I pallini indicano le modalità previste per le lezioni di quel '
      'giorno: verde per le lezioni in presenza, arancione per quelle online.',
  'Tap a day to see its hours. The dots show the modes planned for the lessons of that day: green for in-person '
      'lessons, orange for online ones.',
);
String get _standard => tr(
  "Questi sono gli orari di apertura ufficiali dell'Associazione, senza eventuali variazioni.",
  "These are the Association's official opening hours, without any schedule changes.",
);
String get _variations => tr(
  "Queste sono le prossime variazioni rispetto all'orario standard, previste in occasione di festività o per altre "
      'esigenze.',
  'These are the upcoming changes to the standard hours, planned for holidays or other needs.',
);
String get _toNotices => tr('Tocca «Comunicazioni e avvisi».', 'Tap “Announcements and notices”.');
String get _notices => tr(
  "Qui puoi leggere tutti i messaggi inviati dal Direttivo dell'Associazione.",
  "Here you can read all the messages sent by the Association's Board.",
);
String get _top => tr(
  'Puoi ordinare i messaggi dal più recente al meno recente o viceversa, filtrare gli avvisi per una data specifica '
      'oppure cercarli in base al titolo o al contenuto.',
  'You can sort the messages from newest to oldest or the other way round, filter the notices by a specific date '
      'or search them by title or content.',
);
String get _picker => tr(
  'Il pallino sotto una data indica la presenza di un messaggio inviato in quel giorno.',
  'The dot under a date means that a message was sent on that day.',
);
String get _toSubjects => tr('Tocca «Discipline».', 'Tap “Disciplines”.');
String get _subjects => tr(
  'In questa pagina trovi tutte le discipline che vengono insegnate in Associazione.',
  'On this page you will find all the disciplines taught at the Association.',
);
String get _report => tr(
  'Se manca una disciplina che ti interessa, puoi segnalarlo tramite questo bottone.',
  'If a discipline you are interested in is missing, you can let us know with this button.',
);
String get _toTeachers => tr('Tocca «Docenti».', 'Tap “Teachers”.');
String _teacherFacts(bool she) => tr(
  'Da qui puoi vedere la formazione ${she ? 'della docente' : 'del docente'} e le discipline che insegna in '
      'Associazione.',
  "From here you can see the teacher's education and the disciplines they teach at the Association.",
);

bool _daughter(String? gender) => gender == 'F';

// A parent reading subjects and teachers for their children, or a student for themselves.
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
  final String intro = tr(
    "In questa pagina trovi tutti i docenti che collaborano con l'Associazione. "
        'Toccando su ciascuno di essi puoi visualizzarne alcune informazioni',
    'On this page you will find all the teachers who work with the Association. Tap any of them to see some '
        'information about them',
  );

  final List<String?> opinions = reader.opinions;

  if (opinions.isEmpty)
  {
    return '$intro.';
  }

  if (isEnglish)
  {
    final String who = reader.self
        ? 'you'
        : opinions.length == 1
            ? (_daughter(opinions.single) ? 'your daughter' : 'your son')
            : (opinions.every(_daughter) ? 'your daughters' : 'your children');

    return '$intro and, if you wish, say whether $who did not get on well with them.';
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
    return tr(
      'Puoi ordinare i docenti per nome o cognome e filtrarli per disciplina insegnata.',
      'You can sort the teachers by first or last name and filter them by the discipline they teach.',
    );
  }

  if (isEnglish)
  {
    final String who = reader.self
        ? 'you'
        : opinions.length == 1
            ? (_daughter(opinions.single) ? 'your daughter' : 'your son')
            : (opinions.every(_daughter) ? 'your daughters' : 'your children');

    return 'You can sort the teachers by first or last name, filter them by the discipline they teach, or show only '
        'the ones $who would rather not have.';
  }

  final String whose = reader.self
      ? ''
      : opinions.length == 1
          ? (_daughter(opinions.single) ? ' da tua figlia' : ' da tuo figlio')
          : (opinions.every(_daughter) ? ' dalle tue figlie' : ' dai tuoi figli');

  return 'Puoi ordinare i docenti per nome o cognome, filtrarli per disciplina insegnata, o visualizzare solo quelli '
      'non graditi$whose.';
}

String _teacherOpinion(AssociationReader reader, {required bool she})
{
  final List<String?> opinions = reader.opinions;
  final String teacher = she ? 'la docente' : 'il docente';

  if (reader.self)
  {
    return tr(
      'Puoi segnalare se preferisci non fare lezione con $teacher.',
      'You can say if you would rather not have lessons with the teacher.',
    );
  }

  if (isEnglish)
  {
    final String who = opinions.length == 1
        ? (_daughter(opinions.single) ? 'your daughter would' : 'your son would')
        : (opinions.every(_daughter) ? 'your daughters would' : 'your children would');

    return 'You can say if $who rather not have lessons with the teacher.';
  }

  final String who = opinions.length == 1
      ? (_daughter(opinions.single) ? 'tua figlia preferisce' : 'tuo figlio preferisce')
      : (opinions.every(_daughter) ? 'le tue figlie preferiscono' : 'i tuoi figli preferiscono');

  return 'Puoi segnalare se $who non fare lezione con $teacher.';
}

Map<AssociationMark, String> get _markTexts => {
  AssociationMark.variation: tr(
    "Questo simbolo indica che l'orario per questo giorno è diverso rispetto all'orario standard.",
    'This symbol means that the hours for this day are different from the standard hours.',
  ),
  AssociationMark.pinned: tr(
    'I messaggi fissati in alto sono particolarmente importanti: ti preghiamo di leggerli con attenzione.',
    'The messages pinned at the top are particularly important: please read them carefully.',
  ),
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

// [tablet]: the week is a table, no row of days. [pinned]: the notices hold one, lit once shown.
// [reader]: a parent or a student, subjects and teachers before the notices; null for a teacher.
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
    prepare: () => turnMobileTourPages(pages, 0),
    steps: [
      MobileTourStep(text: _day, shown: const [kAssociationTourDay], reveal: kAssociationTourDay),
      MobileTourStep(
        text: _markTexts[AssociationMark.variation]!,
        shown: [associationTourMark(AssociationMark.variation)],
        reveal: associationTourMark(AssociationMark.variation),
        present: () => onPage(0) && isMobileTourTargetShown(associationTourMark(AssociationMark.variation)),
        seen: _markSeen(AssociationMark.variation),
      ),
      MobileTourStep(text: _week, shown: const [kAssociationTourWeek], reveal: kAssociationTourWeek),
      if (!tablet) MobileTourStep(text: _days, shown: const [kAssociationTourDays], reveal: kAssociationTourDays),
      // On the tablet its heading stands apart from the table: both lit as one.
      MobileTourStep(
        text: _standard,
        shown: const [kAssociationTourStandard],
        reveal: kAssociationTourStandard,
        joined: true,
      ),
      if (variations)
        MobileTourStep(text: _variations, shown: const [kAssociationTourVariations], reveal: kAssociationTourVariations),
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
    steps: [MobileTourStep(text: _picker, shown: const [kAssociationTourPickerDays])],
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}

// A parent's or a student's; with no opinions to give, no opinion card to light.
MobileTour associationTeacherSheetTour(AssociationReader reader, {String? teacherGender})
{
  final bool she = teacherGender == 'F';

  return MobileTour(
    slug: _teacherSheetSlug,
    title: _title,
    version: _teacherSheetVersion,
    steps: [
      MobileTourStep(
        text: _teacherFacts(she),
        shown: const [kAssociationTourTeacherProfile, kAssociationTourTeacherSubjects],
        joined: true,
      ),
      if (reader.opinions.isNotEmpty)
        MobileTourStep(
          text: _teacherOpinion(reader, she: she),
          shown: const [kAssociationTourTeacherOpinion],
          reveal: kAssociationTourTeacherOpinion,
        ),
    ],
    // The sheet closed under it: it comes back the next time.
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}
