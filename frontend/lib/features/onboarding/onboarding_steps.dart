import '../people/models/child_item.dart';

enum OnboardingStepKind
{
  // One record, personal and association cards together, confirmed or
  // reported: nothing on it can be typed over except a teacher's studies.
  ownRecord,
  childRecord,

  // Screens that are filled in rather than confirmed.
  childSchool,
  ownSchool,
  teacherSubjects,
}

class OnboardingStep
{
  final OnboardingStepKind kind;

  // Set on the child screens; the tax code the screen is about.
  final String? childTaxCode;
  final String? childName;

  const OnboardingStep(this.kind, {this.childTaxCode, this.childName});

  bool get isAboutAChild => childTaxCode != null;
}

const String kAdminRole = 'ADMIN';
const String kTeacherRole = 'TEACHER';
const String kParentRole = 'PARENT';
const String kStudentRole = 'STUDENT';

// One flow per account, holding the blocks of every role the account has. The
// password change comes before this list, on its own page, and is not counted.
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
    // A child at a time, both of their screens before the next child's.
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

// A minor who is a student and nothing else is shown their personal cards
// only; anyone of age, and any minor with another role, is shown everything.
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

// The fields a correction request can name. Residence is on the personal list
// because the flow shows it without letting anyone change it; contacts are
// not, because they are typed over directly.
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

// Keyed on the codes /auth/me hands out for the account, or on the ones the
// register hands out for a child: the labels differ, the cards do not.
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
