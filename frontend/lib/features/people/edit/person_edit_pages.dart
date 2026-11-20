import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import 'person_edit_form.dart';

enum PersonEditPurpose
{
  edit,

  create,

  createParent,

  createMinor,

  // The year in course for someone on file: start, school year, payments.
  reEnroll,
}

enum PersonEditStepId
{
  reEnrollment,
  schoolYear,
  type,
  roles,
  association,
  personalInfo,
  associativeInfo,
  payment,
  parents,
  minors,
  subjects,
}

enum PersonEditCardId
{
  reEnrollment,
  involvement,
  roleChoice,
  associationChoice,
  identity,
  birthData,
  consents,
  psychologicalSupport,
  residence,
  contacts,
  memberships,
  payment,
  admin,
  teacher,
  courseParticipant,
  earlyExit,
  certifications,
  schoolEnrollments,
  staff,
  minorSafety,
  parents,
  minors,
  subjects,
}

class PersonEditCard
{
  final PersonEditCardId id;

  // Null when the card is the whole step.
  final String? label;

  const PersonEditCard(this.id, {this.label});
}

class PersonEditStep
{
  final PersonEditStepId id;

  final String question;
  final String hint;

  final List<PersonEditCard> cards;

  const PersonEditStep({
    required this.id,
    required this.question,
    required this.hint,
    required this.cards,
  });
}

List<PersonEditCard> associativeCardsFor(PersonEditForm form)
{
  final List<PersonEditCard> cards = [];
  final List<String> roles = form.activeRoles;
  final bool onlyParent = form.isOnlyParentNotMember;
  final bool feminine = form.genderValue == 'F';

  if (!onlyParent)
  {
    cards.add(PersonEditCard(PersonEditCardId.memberships, label: tr('Iscrizioni', 'Enrolments')));
  }

  if (roles.contains('AMMINISTRATORE'))
  {
    cards.add(PersonEditCard(
      PersonEditCardId.admin,
      label: feminine ? tr('Amministratrice', 'Administrator') : tr('Amministratore', 'Administrator'),
    ));
  }

  if (roles.contains('DOCENTE'))
  {
    cards.add(PersonEditCard(PersonEditCardId.teacher, label: tr('Docente', 'Teacher')));
  }

  if (roles.contains('CORSISTA'))
  {
    cards.add(PersonEditCard(PersonEditCardId.courseParticipant, label: tr('Corsista', 'Course participant')));
  }

  if (roles.contains('STUDENTE'))
  {
    // Leaving early is a minor's question only, so the tab goes with it.
    if (form.isMinor)
    {
      cards.add(PersonEditCard(PersonEditCardId.earlyExit, label: tr('Uscita anticipata', 'Early departure')));
    }

    // Later they change only in the pupil's «Osservazioni».
    if (form.isCreation)
    {
      cards.add(PersonEditCard(PersonEditCardId.certifications, label: tr('Certificazioni', 'Certifications')));
    }

    cards.add(PersonEditCard(PersonEditCardId.schoolEnrollments, label: tr('Anni scolastici', 'School years')));
  }

  // After the administrative role: president, vice president and treasurer cannot be paid, which overrides this.
  final bool isStaff = roles.contains('AMMINISTRATORE') ||
      roles.contains('DOCENTE') ||
      roles.contains('PSICOLOGO');

  if (isStaff && !form.collaborationInCompensi)
  {
    cards.add(PersonEditCard(PersonEditCardId.staff, label: tr('Collaborazione', 'Collaboration')));
  }

  if (form.isCreation && !onlyParent && !roles.contains('PSICOLOGO'))
  {
    cards.add(PersonEditCard(
      PersonEditCardId.psychologicalSupport,
      label: tr('Sostegno psicologico', 'Psychological support'),
    ));
  }

  if (!onlyParent && form.isMinor)
  {
    cards.add(PersonEditCard(
      PersonEditCardId.minorSafety,
      label: feminine ? tr('Sicurezza della minore', 'Minor’s safety') : tr('Sicurezza del minore', 'Minor’s safety'),
    ));
  }

  if (!onlyParent)
  {
    cards.add(PersonEditCard(PersonEditCardId.consents, label: tr('Consensi', 'Consents')));
  }

  return cards;
}

PersonEditStep _personalInfoStep(PersonEditForm form, {required bool revoked})
{
  return PersonEditStep(
    id: PersonEditStepId.personalInfo,
    question: tr('Chi è?', 'Who is this person?'),
    hint: form.isCreation
            ? tr(
                'Compila i dati anagrafici e di contatto della persona. Dopo la creazione, '
                'sarà possibile modificare solo la residenza e i contatti.',
                'Fill in the person’s personal and contact details. After creation, '
                'only the residence and the contacts can be changed.',
              )
            : tr(
                'Per motivi di sicurezza, le informazioni personali principali '
                'non possono essere modificate manualmente.\n'
                'Se hai riscontrato un errore, puoi richiederne la correzione utilizzando il pulsante in basso.',
                'For security reasons, the main personal details cannot be changed by hand.\n'
                'If you have found an error, you can ask for it to be corrected with the button below.',
              ),
    cards: [
      PersonEditCard(PersonEditCardId.identity, label: tr('Identità', 'Identity')),
      PersonEditCard(PersonEditCardId.birthData, label: tr('Dati anagrafici', 'Personal details')),
      PersonEditCard(PersonEditCardId.residence, label: tr('Residenza', 'Residence')),
      PersonEditCard(PersonEditCardId.contacts, label: tr('Contatti', 'Contacts')),
    ],
  );
}

// Drafts, not his: the questions of the re-enrollment steps.
List<PersonEditStep> _reEnrollmentSteps(PersonEditForm form)
{
  return [
    PersonEditStep(
      id: PersonEditStepId.reEnrollment,
      question: tr('Da quando vale la nuova iscrizione?', 'When does the new enrolment start?'),
      hint: tr(
        'È l\'iscrizione del ${form.reEnrollYearCtrl.text}: indica il giorno da cui parte.',
        'This is the ${form.reEnrollYearCtrl.text} enrolment: set the day it starts.',
      ),
      cards: const [PersonEditCard(PersonEditCardId.reEnrollment)],
    ),
    if (form.asksSchoolYear)
      PersonEditStep(
        id: PersonEditStepId.schoolYear,
        question: tr('Che classe frequenta quest\'anno?', 'Which class are they in this year?'),
        hint: tr(
          'Aggiungi l\'anno scolastico in corso: la tariffa dipende dal livello.',
          'Add the current school year: the rate depends on the level.',
        ),
        cards: const [PersonEditCard(PersonEditCardId.schoolEnrollments)],
      ),
    PersonEditStep(
      id: PersonEditStepId.payment,
      question: tr('Come avvengono i pagamenti?', 'How are payments made?'),
      hint: _paymentHint(form),
      cards: const [PersonEditCard(PersonEditCardId.payment)],
    ),
  ];
}

List<PersonEditStep> buildEditSteps(
  PersonEditForm form, {
  PersonEditPurpose purpose = PersonEditPurpose.edit,
})
{
  if (purpose == PersonEditPurpose.reEnroll)
  {
    return _reEnrollmentSteps(form);
  }

  // No longer a member: only the personal details remain editable.
  if (form.isPersonalDataOnly)
  {
    return [_personalInfoStep(form, revoked: true)];
  }

  final List<PersonEditStep> steps = [];
  final bool feminine = form.genderValue == 'F';

  final bool asksType = purpose == PersonEditPurpose.edit ||
      purpose == PersonEditPurpose.create;

  if (asksType)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.type,
      question: tr(
        'Qual è il rapporto di questa persona con l\'Associazione?',
        'What is this person’s relationship with the Association?',
      ),
      hint: tr(
        'Scegli la categoria che descrive meglio la sua posizione.',
        'Choose the category that best describes their position.',
      ),
      cards: const [PersonEditCard(PersonEditCardId.involvement)],
    ));
  }

  if (form.involvementType == 0 && purpose != PersonEditPurpose.createParent)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.roles,
      question: tr(
        'Quali ruoli ricopre all\'interno dell\'Associazione?',
        'Which roles do they hold in the Association?',
      ),
      hint: tr('Puoi sceglierne più di uno.', 'You can choose more than one.'),
      cards: const [PersonEditCard(PersonEditCardId.roleChoice)],
    ));
  }

  if (form.asksAssociationQuestion)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.association,
      question: tr('Vuole iscriversi anche personalmente?', 'Do they also want to enrol themselves?'),
      hint: feminine
          ? tr(
              'Il genitore può iscrivere il proprio figlio senza diventare socia.',
              'A parent can enrol their child without becoming a member.',
            )
          : tr(
              'Il genitore può iscrivere il proprio figlio senza diventare socio.',
              'A parent can enrol their child without becoming a member.',
            ),
      cards: const [PersonEditCard(PersonEditCardId.associationChoice)],
    ));
  }

  steps.add(_personalInfoStep(form, revoked: false));

  final List<PersonEditCard> associative = associativeCardsFor(form);

  if (associative.isNotEmpty)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.associativeInfo,
      question: tr('Che cosa serve sapere per i suoi ruoli?', 'What do we need to know for their roles?'),
      hint: tr('Compila i dati richiesti dai ruoli selezionati.', 'Fill in the details the selected roles require.'),
      cards: associative,
    ));
  }

  // Must follow the associative step: a pupil's rate depends on the school year filled in just before.
  if (form.showsPaymentStep)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.payment,
      question: tr('Come avvengono i pagamenti?', 'How are payments made?'),
      hint: _paymentHint(form),
      cards: const [PersonEditCard(PersonEditCardId.payment)],
    ));
  }

  final bool asksRelations = purpose == PersonEditPurpose.edit ||
      purpose == PersonEditPurpose.create;

  if (asksRelations && form.isMinor)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.parents,
      question: tr('Chi sono i suoi genitori o tutori legali?', 'Who are their parents or legal guardians?'),
      hint: tr('Almeno uno, al massimo due.', 'At least one, at most two.'),
      cards: const [PersonEditCard(PersonEditCardId.parents)],
    ));
  }

  if (asksRelations && form.selectedRoles.contains('GENITORE'))
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.minors,
      question: feminine
          ? tr('Di quali minori è genitore o tutrice?', 'Which minors are they the parent or guardian of?')
          : tr('Di quali minori è genitore o tutore?', 'Which minors are they the parent or guardian of?'),
      hint: tr(
        'Seleziona le persone di cui è responsabile legale.',
        'Select the people they are legally responsible for.',
      ),
      cards: const [PersonEditCard(PersonEditCardId.minors)],
    ));
  }

  if (form.asksSubjects)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.subjects,
      question: tr('Cosa insegna?', 'What do they teach?'),
      hint: tr(
        'Seleziona le discipline in cui ${feminine ? 'la' : 'il'} docente è competente. Per ognuna '
        'di esse è possibile indicare i percorsi di studio in cui è disponibile a insegnare.\n'
        'È inoltre possibile selezionare i servizi offerti dall\'Associazione.',
        'Select the disciplines the teacher is competent in. For each one you can set '
        'the study programmes they are available to teach.\n'
        'You can also select the services the Association offers.',
      ),
      cards: const [PersonEditCard(PersonEditCardId.subjects)],
    ));
  }

  return steps;
}

// Says only what the card asks: fees only of whoever is enrolled this year.
String _paymentHint(PersonEditForm form)
{
  // A member on file becoming a pupil: the method is already in the «Pagamenti» tab.
  if (!form.asksPaymentStep)
  {
    return tr(
      'Seleziona la tariffa scelta per il servizio di aiuto compiti.',
      'Select the rate chosen for the Homework Help service.',
    );
  }

  if (form.asksFees)
  {
    return form.asksTariff
        ? tr(
            'Seleziona la modalità di pagamento preferita e, per gli studenti, la tariffa scelta per il '
            'servizio di aiuto compiti, l’iscrizione e l’assicurazione.',
            'Select the preferred payment method and, for students, the rate chosen for the '
            'Homework Help service, the enrolment and the insurance.',
          )
        : tr(
            'Seleziona la modalità di pagamento preferita, l’iscrizione e l’assicurazione.',
            'Select the preferred payment method, the enrolment and the insurance.',
          );
  }

  return form.asksTariff
      ? tr(
          'Seleziona la modalità di pagamento preferita e, per gli studenti, '
          'la tariffa scelta per il servizio di aiuto compiti.',
          'Select the preferred payment method and, for students, '
          'the rate chosen for the Homework Help service.',
        )
      : tr('Seleziona la modalità di pagamento preferita.', 'Select the preferred payment method.');
}

// Field steps answer true: they are validated when the forward arrow is pressed.
bool stepIsAnswered(PersonEditStepId id, PersonEditForm form)
{
  return stepBlockedReason(id, form) == null;
}

String? stepBlockedReason(PersonEditStepId id, PersonEditForm form)
{
  return switch (id)
  {
    PersonEditStepId.type when form.involvementType < 0 =>
      tr(
        'Scegli il rapporto con l\'Associazione per andare avanti.',
        'Choose the relationship with the Association to go on.',
      ),
    PersonEditStepId.roles when form.activeRoles.isEmpty =>
      tr('Seleziona almeno un ruolo per andare avanti.', 'Select at least one role to go on.'),
    PersonEditStepId.association when form.parentIsMember == null =>
      tr(
        'Indica se vuole iscriversi anche personalmente per andare avanti.',
        'Say whether they also want to enrol themselves to go on.',
      ),
    _ => null,
  };
}

int indexOfStep(List<PersonEditStep> steps, PersonEditStepId id)
{
  final int index = steps.indexWhere((step) => step.id == id);

  return index < 0 ? 0 : index;
}

@visibleForTesting
List<PersonEditStepId> stepIdsOf(List<PersonEditStep> steps) =>
    steps.map((step) => step.id).toList();
