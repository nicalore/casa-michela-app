import '../../core/language/app_language.dart';

export '../people/utils/student_notes_strings.dart';

String get kStudentsModule => tr('Studenti', 'Students');

String get kStudentSearchHint => tr('Cerca studente...', 'Search students...');

String studentsCount(int count) => count == 1 ? tr('1 studente', '1 student') : tr('$count studenti', '$count students');

String get kBirthDateLabel => tr('Data di nascita', 'Date of birth');
String get kAgeLabel => tr('Età', 'Age');

String ageValue(int age) => tr('$age anni', '$age years old');

String get kCertificationsTitle => tr('Certificazioni', 'Certifications');
String get kCertificationField => tr('Certificazione', 'Certification');
String get kDsaDetailLabel => tr('Tipo di DSA', 'Type of SLD');
String get kOtherDetailLabel => tr('Altra certificazione', 'Other certification');

String get kSchoolTitle => tr('Scuola', 'School');
String get kCurrentSchoolYear => tr('Anno scolastico attuale', 'Current school year');
String get kPastSchoolYears => tr('Anni scolastici passati', 'Past school years');
String get kNoStudents => tr('Nessuno studente registrato', 'No students recorded');
String get kNoSchoolYears => tr('Nessun anno scolastico registrato.', 'No school years recorded.');

String get kSchoolYearLabel => tr('Anno scolastico', 'School year');
String get kSchoolLabel => tr('Scuola', 'School');
String get kProgrammeLabel => tr('Percorso', 'Programme');
String get kClassLabel => tr('Classe', 'Class');
String get kRepeatingLabel => tr('Ripetente', 'Repeating the year');

String get kOtherInformationTitle => tr('Altre informazioni', 'Other information');

String get kEditLabel => tr('MODIFICA', 'EDIT');

String get kCertificationsSaved => tr('Certificazioni aggiornate con successo!', 'Certifications updated!');
String get kOtherRequired => tr('Specificare il tipo', 'Specify the type');
String get kDsaRequired => tr('Specificare il disturbo', 'Specify the disorder');
String get kFormErrors => tr('Ci sono errori nei dati inseriti. Correggi i campi.', 'There are errors in the data entered. Correct the fields.');

String get kLoadFailed => tr('Impossibile caricare le anagrafiche dal server.', "Couldn't load the personal details from the server.");
