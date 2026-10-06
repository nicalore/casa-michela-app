export '../people/utils/student_notes_strings.dart';

const String kStudentsModule = 'Studenti';

const String kStudentSearchHint = 'Cerca studente...';

String studentsCount(int count) => count == 1 ? '1 studente' : '$count studenti';

const String kBirthDateLabel = 'Data di nascita';
const String kAgeLabel = 'Età';

String ageValue(int age) => '$age anni';

const String kCertificationsTitle = 'Certificazioni';
const String kCertificationField = 'Certificazione';
const String kDsaDetailLabel = 'Tipo di DSA';
const String kOtherDetailLabel = 'Altra certificazione';

const String kSchoolTitle = 'Scuola';
const String kCurrentSchoolYear = 'Anno scolastico attuale';
const String kPastSchoolYears = 'Anni scolastici passati';
const String kNoSchoolYears = 'Nessun anno scolastico registrato.';

const String kSchoolYearLabel = 'Anno scolastico';
const String kSchoolLabel = 'Scuola';
const String kProgrammeLabel = 'Percorso';
const String kClassLabel = 'Classe';
const String kRepeatingLabel = 'Ripetente';

const String kOtherInformationTitle = 'Altre informazioni';

const String kEditLabel = 'MODIFICA';

const String kCertificationsSaved = 'Certificazioni aggiornate con successo!';
const String kOtherRequired = 'Specificare il tipo';
const String kDsaRequired = 'Specificare il disturbo';
const String kFormErrors = 'Ci sono errori nei dati inseriti. Correggi i campi.';

const String kLoadFailed = 'Impossibile caricare le anagrafiche dal server.';
