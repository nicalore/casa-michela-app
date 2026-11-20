import '../../../core/language/app_language.dart';

// Confirming a discipline not taken yet with no programme ticked; desktop and mobile alike.
String get kPickProgramToAdd => tr(
  'Seleziona almeno un percorso per aggiungere la disciplina.',
  'Select at least one programme to add the discipline.',
);

// Giving up the last discipline or service: the server's own refusal, said before asking it.
String get kKeepOneCompetence => tr(
  'Un docente deve insegnare almeno una disciplina o un servizio.',
  'A teacher must teach at least one discipline or service.',
);
