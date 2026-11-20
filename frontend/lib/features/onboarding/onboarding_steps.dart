import '../../core/language/app_language.dart';
import '../people/models/child_item.dart';

enum OnboardingStepKind
{
  terms,

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
// [onboarding] false: only the terms, for an account already past the flow.
List<OnboardingStep> onboardingStepsFor({
  required List<String> roles,
  required List<ChildItem> children,
  bool terms = false,
  bool onboarding = true,
})
{
  final steps = <OnboardingStep>[
    if (terms) const OnboardingStep(OnboardingStepKind.terms),
  ];

  if (!onboarding)
  {
    return steps;
  }

  steps.add(const OnboardingStep(OnboardingStepKind.ownRecord));

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
    'M' => tr('Benvenuto', 'Welcome'),
    'F' => tr('Benvenuta', 'Welcome'),
    _ => tr('Benvenuto/a', 'Welcome'),
  };
}

// For whoever comes back to accept the changed documents.
String onboardingWelcomeBack(String? gender)
{
  return switch (gender?.toUpperCase())
  {
    'M' => tr('Bentornato', 'Welcome back'),
    'F' => tr('Bentornata', 'Welcome back'),
    _ => tr('Bentornato/a', 'Welcome back'),
  };
}

String onboardingStepTitle(OnboardingStep step)
{
  final String? name = step.childName;

  return switch (step.kind)
  {
    OnboardingStepKind.terms => tr('Termini e privacy', 'Terms and privacy'),
    OnboardingStepKind.ownRecord => tr('I tuoi dati', 'Your details'),
    OnboardingStepKind.childRecord => tr('I dati di $name', "$name's details"),
    OnboardingStepKind.childSchool => tr('Il percorso scolastico di $name', "$name's school history"),
    OnboardingStepKind.ownSchool => tr('Il tuo percorso scolastico', 'Your school history'),
    OnboardingStepKind.teacherSubjects => tr('Le tue discipline', 'Your disciplines'),
  };
}

String onboardingStepQuestion(OnboardingStep step, {bool arrows = true})
{
  final String? name = step.childName;
  final String scroll = arrows
      ? tr('Scorri le schede con le frecce e verifica', 'Scroll through the cards with the arrows and check')
      : tr('Scorri le schede e verifica', 'Scroll through the cards and check');

  return switch (step.kind)
  {
    OnboardingStepKind.terms => tr(
      "Prima di iniziare, leggi i documenti che regolano l'uso dell'applicazione e spiegano come trattiamo i tuoi dati. "
          'Per proseguire, conferma di averli letti e di accettarli.',
      'Before you start, read the documents that govern the use of the app and explain how we handle your data. '
          'To go on, confirm that you have read and accept them.',
    ),
    OnboardingStepKind.ownRecord => tr(
      '$scroll che le informazioni siano corrette. '
          'Se trovi un errore, ti preghiamo di segnalarlo utilizzando il bottone in fondo. Puoi modificare direttamente la foto profilo e i dati di contatto.',
      '$scroll that the information is correct. '
          'If you find a mistake, please report it with the button at the bottom. You can change your profile photo and contact details directly.',
    ),
    OnboardingStepKind.childRecord => tr(
      '$scroll che le informazioni di $name siano corrette. '
          'Se trovi un errore, ti preghiamo di segnalarlo utilizzando il bottone in fondo. Puoi modificare direttamente i dati di contatto.',
      "$scroll that $name's information is correct. "
          'If you find a mistake, please report it with the button at the bottom. You can change the contact details directly.',
    ),
    OnboardingStepKind.childSchool => tr(
      'Verifica che il percorso scolastico di $name sia corretto e, se necessario, modificalo. '
          'Puoi anche aggiungere altri anni scolastici per fornirci maggiori informazioni sul suo percorso. Non sarà possibile modificare questi dati una volta confermati.',
      "Check that $name's school history is correct and, if needed, change it. "
          "You can also add more school years to tell us more about their path. These details can't be changed once confirmed.",
    ),
    OnboardingStepKind.ownSchool => tr(
      'Verifica che il tuo percorso scolastico sia corretto e, se necessario, modificalo. '
          'Puoi anche aggiungere altri anni scolastici per fornirci maggiori informazioni sul tuo percorso. Non sarà possibile modificare questi dati una volta confermati.',
      'Check that your school history is correct and, if needed, change it. '
          "You can also add more school years to tell us more about your path. These details can't be changed once confirmed.",
    ),
    OnboardingStepKind.teacherSubjects => tr(
      'Indica le discipline che desideri insegnare e, per ognuna, i percorsi di studio per cui sei disponibile. '
          'Ti consigliamo di prestare attenzione a questo passaggio, perché le informazioni inserite verranno utilizzate per assegnarti le lezioni. Potrai modificare questi dati anche in un secondo momento.',
      'Choose the disciplines you want to teach and, for each one, the study programmes you are available for. '
          'Please pay attention to this step, because the information you enter will be used to assign you lessons. You can change these details later too.',
    ),
  };
}

String onboardingAtLeastOneSchoolYear(OnboardingStep step)
{
  return step.isAboutAChild
      ? tr('${step.childName} deve avere almeno un anno scolastico.', '${step.childName} must have at least one school year.')
      : tr('Devi avere almeno un anno scolastico.', 'You must have at least one school year.');
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
List<String> get kPersonalReportableFields => [
  tr('Nome', 'First name'),
  tr('Cognome', 'Last name'),
  tr('Sesso', 'Sex'),
  tr('Codice fiscale', 'Tax code'),
  tr('Data di nascita', 'Date of birth'),
  tr('Città di nascita', 'City of birth'),
  tr('Provincia di nascita', 'Province of birth'),
  tr('Indirizzo', 'Address'),
  tr('Numero civico', 'House number'),
  tr('Città di residenza', 'City of residence'),
  tr('Provincia di residenza', 'Province of residence'),
  tr('CAP', 'Postcode'),
];

// Accepts both /auth/me role codes and the register's Italian labels.
// [forOwner]: pupils are never shown their own certifications.
List<String> associationReportableFields(List<String> roles, {bool forOwner = false, bool feminine = false})
{
  final upper = roles.map((role) => role.toUpperCase()).toSet();

  bool has(String code, String label) => upper.contains(code) || upper.contains(label);

  final bool isStaff = has(kAdminRole, 'AMMINISTRATORE') ||
      has(kTeacherRole, 'DOCENTE') ||
      has('PSYCHOLOGIST', 'PSICOLOGO');

  return [
    tr('Modalità di pagamento', 'Payment method'),
    if (isStaff) ...[tr('Tipo collaborazione', 'Collaboration type'), tr('Compenso', 'Pay'), 'IBAN'],
    if (has(kAdminRole, 'AMMINISTRATORE'))
      feminine ? tr('Ruolo amministratrice', 'Administrator role') : tr('Ruolo amministratore', 'Administrator role'),
    if (has(kStudentRole, 'STUDENTE')) ...[
      tr('Tariffa', 'Rate'),
      if (!forOwner) tr('Certificazioni', 'Certifications'),
      tr('Uscita anticipata', 'Early departure'),
    ],
    if (has('COURSE_PARTICIPANT', 'CORSISTA'))
      ...[tr('Tipo corso', 'Course type'), tr('Scadenza certificato medico', 'Medical certificate expiry')],
    tr('Contatto di emergenza', 'Emergency contact'),
    tr('Allergie e farmaci', 'Allergies and medicines'),
  ];
}
