import '../people/models/child_item.dart';

enum OnboardingStepKind
{
  ownRecord,
  childRecord,

  childSchool,
  ownSchool,
  teacherSubjects,
}

class OnboardingStep
{
  final OnboardingStepKind kind;

  final String? childTaxCode;
  final String? childName;

  const OnboardingStep(this.kind, {this.childTaxCode, this.childName});

  bool get isAboutAChild => childTaxCode != null;
}

const String kAdminRole = 'ADMIN';
const String kTeacherRole = 'TEACHER';
const String kParentRole = 'PARENT';
const String kStudentRole = 'STUDENT';

// The password change precedes this list on its own page and is not counted.
List<OnboardingStep> onboardingStepsFor({
  required List<String> roles,
  required List<ChildItem> children,
})
{
  final steps = <OnboardingStep>[
    const OnboardingStep(OnboardingStepKind.ownRecord),
  ];

  if (roles.contains(kParentRole))
  {
    for (final child in children)
    {
      for (final kind in const [
        OnboardingStepKind.childRecord,
        OnboardingStepKind.childSchool,
      ])
      {
        steps.add(OnboardingStep(
          kind,
          childTaxCode: child.fiscalCode,
          childName: child.firstName,
        ));
      }
    }
  }

  if (roles.contains(kTeacherRole))
  {
    steps.add(const OnboardingStep(OnboardingStepKind.teacherSubjects));
  }

  if (roles.contains(kStudentRole))
  {
    steps.add(const OnboardingStep(OnboardingStepKind.ownSchool));
  }

  return steps;
}

// 'M' and 'F' as the register stores them; anything else gets both endings.
String onboardingWelcome(String? gender)
{
  return switch (gender?.toUpperCase())
  {
    'M' => 'Benvenuto',
    'F' => 'Benvenuta',
    _ => 'Benvenuto/a',
  };
}

String onboardingStepTitle(OnboardingStep step)
{
  final String? name = step.childName;

  return switch (step.kind)
  {
    OnboardingStepKind.ownRecord => 'I tuoi dati',
    OnboardingStepKind.childRecord => 'I dati di $name',
    OnboardingStepKind.childSchool => 'Il percorso scolastico di $name',
    OnboardingStepKind.ownSchool => 'Il tuo percorso scolastico',
    OnboardingStepKind.teacherSubjects => 'Le tue discipline',
  };
}

String onboardingStepQuestion(OnboardingStep step, {bool arrows = true})
{
  final String? name = step.childName;
  final String scroll = arrows ? 'Scorri le schede con le frecce e verifica' : 'Scorri le schede e verifica';

  return switch (step.kind)
  {
    OnboardingStepKind.ownRecord =>
      '$scroll che le informazioni siano corrette. '
          'Se trovi un errore, ti preghiamo di segnalarlo utilizzando il bottone in fondo. Puoi modificare direttamente la foto profilo e i dati di contatto.',
    OnboardingStepKind.childRecord =>
      '$scroll che le informazioni di $name siano corrette. '
          'Se trovi un errore, ti preghiamo di segnalarlo utilizzando il bottone in fondo. Puoi modificare direttamente i dati di contatto.',
    OnboardingStepKind.childSchool =>
      'Verifica che il percorso scolastico di $name sia corretto e, se necessario, modificalo. '
          'Puoi anche aggiungere altri anni scolastici per fornirci maggiori informazioni sul suo percorso. Non sarà possibile modificare questi dati una volta confermati.',
    OnboardingStepKind.ownSchool =>
      'Verifica che il tuo percorso scolastico sia corretto e, se necessario, modificalo. '
          'Puoi anche aggiungere altri anni scolastici per fornirci maggiori informazioni sul tuo percorso. Non sarà possibile modificare questi dati una volta confermati.',
    OnboardingStepKind.teacherSubjects =>
      'Indica le discipline che desideri insegnare e, per ognuna, i percorsi di studio per cui sei disponibile. '
          'Ti consigliamo di prestare attenzione a questo passaggio, perché le informazioni inserite verranno utilizzate per assegnarti le lezioni. Potrai modificare questi dati anche in un secondo momento.',
  };
}

bool includesAssociationCards({
  required bool isAdult,
  required List<String> roles,
})
{
  if (isAdult)
  {
    return true;
  }

  return roles.any((role) => role != kStudentRole);
}

// Contacts are absent: they are edited directly, not reported.
const List<String> kPersonalReportableFields = [
  'Nome',
  'Cognome',
  'Sesso',
  'Codice fiscale',
  'Data di nascita',
  'Città di nascita',
  'Provincia di nascita',
  'Indirizzo',
  'Numero civico',
  'Città di residenza',
  'Provincia di residenza',
  'CAP',
];

// Accepts both /auth/me role codes and the register's Italian labels.
List<String> associationReportableFields(List<String> roles)
{
  final upper = roles.map((role) => role.toUpperCase()).toSet();

  bool has(String code, String label) => upper.contains(code) || upper.contains(label);

  final bool isStaff = has(kAdminRole, 'AMMINISTRATORE') ||
      has(kTeacherRole, 'DOCENTE') ||
      has('PSYCHOLOGIST', 'PSICOLOGO');

  return [
    'Modalità di pagamento',
    if (isStaff) ...['Tipo collaborazione', 'Compenso', 'IBAN'],
    if (has(kAdminRole, 'AMMINISTRATORE')) 'Ruolo amministratore',
    if (has(kStudentRole, 'STUDENTE')) ...[
      'Tariffa',
      'Certificazioni',
      'Uscita anticipata',
    ],
    if (has('COURSE_PARTICIPANT', 'CORSISTA'))
      ...['Tipo corso', 'Scadenza certificato medico'],
    'Contatto di emergenza',
    'Allergie e farmaci',
  ];
}
