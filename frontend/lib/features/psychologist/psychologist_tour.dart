import '../../core/language/app_language.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../home/home_tour.dart';
import 'widgets/student_list_panel.dart';
import 'widgets/student_sheet.dart';

const List<DesktopTourSide> _beside = [DesktopTourSide.right, DesktopTourSide.below];
const List<DesktopTourSide> _leftOf = [
  DesktopTourSide.left,
  DesktopTourSide.right,
  DesktopTourSide.above,
  DesktopTourSide.below,
];

// The pupil's cards are there only with a pupil open.
bool _sheetShown() => isDesktopTourTargetShown(kTourStudentSchool);

DesktopTour psychologistHomeTour({required bool manyRoles})
{
  return DesktopTour(
    slug: 'home.psychologist',
    title: 'Home',
    version: 4,
    steps: homeBarTourSteps(manyRoles: manyRoles),
  );
}

// [studentGender]: of the pupil open beside the list.
DesktopTour psychologistStudentsTour({String? studentGender})
{
  final bool she = studentGender == 'F';
  final String them = switch (studentGender) { 'F' => 'her', 'M' => 'him', _ => 'them' };
  final String their = switch (studentGender) { 'F' => 'her', 'M' => 'his', _ => 'their' };

  return DesktopTour(
    slug: 'students.psychologist',
    title: tr('Studenti', 'Students'),
    version: 3,
    steps: [
      DesktopTourStep(
        text: tr(
          'Da qui puoi visualizzare e gestire alcune informazioni relative agli studenti.',
          'From here you can view and manage some information about the students.',
        ),
      ),
      DesktopTourStep(
        targets: const [kTourStudentList],
        text: tr(
          "L'elenco mostra tutti gli studenti attualmente iscritti in Associazione.",
          'The list shows all the students currently enrolled in the Association.',
        ),
        sides: _beside,
        pad: 6,
        radius: 32,
      ),
      DesktopTourStep(
        targets: const [kTourStudentSearch],
        text: tr(
          'Puoi cercare direttamente uno studente tramite nome e cognome.',
          'You can search for a student directly by first name and surname.',
        ),
        sides: _beside,
        pad: 6,
        radius: 28,
      ),
      DesktopTourStep(
        targets: const [kTourStudentFilters],
        text: tr(
          "Puoi filtrare l'elenco attraverso diversi criteri, come l'età, la classe frequentata o il tipo di "
              'certificazione.',
          'You can filter the list by several criteria, such as age, the class attended or the type of '
              'certification.',
        ),
        sides: _beside,
        pad: 6,
        radius: 26,
      ),
      DesktopTourStep(
        targets: const [kTourStudentRows],
        text: tr(
          'Cliccando su uno studente puoi visualizzarne le informazioni.',
          'Click a student to view their information.',
        ),
        sides: _beside,
        // The list runs to the panel's bottom edge: a margin would leave it.
        pad: 0,
        radius: 20,
      ),
      DesktopTourStep(
        targets: const [kTourStudentSchool],
        text: tr(
          'Qui trovi informazioni sul percorso scolastico ${she ? 'della studentessa' : 'dello studente'}.',
          "Here you'll find information about the student's schooling.",
        ),
        sides: _leftOf,
        pad: 6,
        radius: 34,
        reveal: true,
        present: _sheetShown,
      ),
      DesktopTourStep(
        targets: const [kTourStudentCertifications],
        text: tr(
          'Sotto, puoi leggere e modificare le certificazioni ufficiali possedute '
              "${she ? 'dalla studentessa' : 'dallo studente'}.",
          'Below, you can read and edit the official certifications the student holds.',
        ),
        sides: _leftOf,
        pad: 6,
        radius: 34,
        reveal: true,
        present: _sheetShown,
      ),
      DesktopTourStep(
        targets: const [kTourStudentNotes],
        text: tr(
          'Da qui puoi inserire le osservazioni metodologiche relative '
              "${she ? 'alla studentessa' : 'allo studente'}: indicazioni operative che possano aiutare i docenti a "
              'impostare le lezioni nel modo più efficace e adeguato alle esigenze '
              "${she ? 'della studentessa' : 'dello studente'}, sulla base delle informazioni che conosci su "
              "${she ? 'di lei' : 'di lui'} e sulla sua situazione.",
          'From here you can add methodological observations about the student: practical guidance that can '
              "help teachers set up lessons in the most effective way, suited to the student's needs, based on "
              'what you know about $them and $their situation.',
        ),
        sides: _leftOf,
        pad: 6,
        radius: 34,
        reveal: true,
        present: _sheetShown,
      ),
    ],
  );
}

// After the first note the psychologist writes, on [studentGender]'s pupil.
DesktopTour psychologistNoteTour({String? studentGender})
{
  final String whose = studentGender == 'F' ? 'della studentessa' : 'dello studente';

  return DesktopTour(
    slug: 'students.psychologist.note',
    title: tr('Studenti', 'Students'),
    version: 4,
    steps: [
      // Only on a student showing a note: never a step lighting nothing.
      DesktopTourStep(
        targets: const [kTourStudentNoteDate],
        text: tr(
          'Le osservazioni sono organizzate in ordine cronologico, come in un diario, per documentare '
              "l'evoluzione $whose nel tempo. Puoi inserirne più di una, aggiungendo nuove osservazioni man mano "
              'che emergono nuove informazioni utili.',
          "The observations are arranged in chronological order, like a diary, to record the student's "
              'progress over time. You can add more than one, adding new observations as new useful '
              'information comes up.',
        ),
        sides: _leftOf,
        radius: 12,
        reveal: true,
        revealing: kTourStudentNotes,
        present: () => isDesktopTourTargetShown(kTourStudentNoteDate),
      ),
      DesktopTourStep(
        targets: const [kTourStudentNoteTools],
        text: tr(
          "Puoi modificare o eliminare in ogni momento un'osservazione che hai inserito.",
          "You can edit or delete an observation you've added at any time.",
        ),
        sides: const [DesktopTourSide.above, DesktopTourSide.left],
        pad: 6,
        radius: 16,
        present: () => isDesktopTourTargetShown(kTourStudentNoteTools),
      ),
    ],
  );
}
