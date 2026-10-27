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

DesktopTour psychologistStudentsTour()
{
  return const DesktopTour(
    slug: 'students.psychologist',
    title: 'Studenti',
    version: 3,
    steps: [
      DesktopTourStep(text: 'Da qui puoi visualizzare e gestire alcune informazioni relative agli studenti.'),
      DesktopTourStep(
        targets: [kTourStudentList],
        text: "L'elenco mostra tutti gli studenti attualmente iscritti in Associazione.",
        sides: _beside,
        pad: 6,
        radius: 32,
      ),
      DesktopTourStep(
        targets: [kTourStudentSearch],
        text: 'Puoi cercare direttamente uno studente tramite nome e cognome.',
        sides: _beside,
        pad: 6,
        radius: 28,
      ),
      DesktopTourStep(
        targets: [kTourStudentFilters],
        text: "Puoi filtrare l'elenco attraverso diversi criteri, come l'età, la classe frequentata o il tipo di "
            'certificazione.',
        sides: _beside,
        pad: 6,
        radius: 26,
      ),
      DesktopTourStep(
        targets: [kTourStudentRows],
        text: 'Cliccando su uno studente puoi visualizzarne le informazioni.',
        sides: _beside,
        // The list runs to the panel's bottom edge: a margin would leave it.
        pad: 0,
        radius: 20,
      ),
      DesktopTourStep(
        targets: [kTourStudentSchool],
        text: 'Qui trovi informazioni sul percorso scolastico dello studente.',
        sides: _leftOf,
        pad: 6,
        radius: 34,
        reveal: true,
        present: _sheetShown,
      ),
      DesktopTourStep(
        targets: [kTourStudentCertifications],
        text: 'Sotto, puoi leggere e modificare le certificazioni ufficiali possedute dallo studente.',
        sides: _leftOf,
        pad: 6,
        radius: 34,
        reveal: true,
        present: _sheetShown,
      ),
      DesktopTourStep(
        targets: [kTourStudentNotes],
        text: 'Da qui puoi inserire le osservazioni metodologiche relative allo studente: indicazioni operative che '
            'possano aiutare i docenti a impostare le lezioni nel modo più efficace e adeguato alle esigenze dello '
            'studente, sulla base delle informazioni che conosci su di lui e sulla sua situazione.',
        sides: _leftOf,
        pad: 6,
        radius: 34,
        reveal: true,
        present: _sheetShown,
      ),
    ],
  );
}

// After the first note the psychologist writes.
DesktopTour psychologistNoteTour()
{
  return DesktopTour(
    slug: 'students.psychologist.note',
    title: 'Studenti',
    version: 4,
    steps: [
      // Only on a student showing a note: never a step lighting nothing.
      DesktopTourStep(
        targets: const [kTourStudentNoteDate],
        text: 'Le osservazioni sono organizzate in ordine cronologico, come in un diario, per documentare '
            "l'evoluzione dello studente nel tempo. Puoi inserirne più di una, aggiungendo nuove osservazioni man mano "
            'che emergono nuove informazioni utili.',
        sides: _leftOf,
        radius: 12,
        reveal: true,
        revealing: kTourStudentNotes,
        present: () => isDesktopTourTargetShown(kTourStudentNoteDate),
      ),
      DesktopTourStep(
        targets: const [kTourStudentNoteTools],
        text: "Puoi modificare o eliminare in ogni momento un'osservazione che hai inserito.",
        sides: const [DesktopTourSide.above, DesktopTourSide.left],
        pad: 6,
        radius: 16,
        present: () => isDesktopTourTargetShown(kTourStudentNoteTools),
      ),
    ],
  );
}
