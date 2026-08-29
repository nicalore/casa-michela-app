import 'package:flutter/material.dart';

import 'person_edit_form.dart';

enum PersonEditPurpose
{
  edit,

  create,

  createParent,

  createMinor,
}

enum PersonEditStepId
{
  type,
  roles,
  association,
  personalInfo,
  associativeInfo,
  parents,
  minors,
  subjects,
}

enum PersonEditCardId
{
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
  student,
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

  if (!onlyParent)
  {
    cards.add(const PersonEditCard(PersonEditCardId.memberships, label: 'Iscrizioni'));
  }

  if (!onlyParent && (roles.contains('STUDENTE') || roles.contains('CORSISTA')))
  {
    cards.add(const PersonEditCard(PersonEditCardId.payment, label: 'Pagamento'));
  }

  if (roles.contains('AMMINISTRATORE'))
  {
    cards.add(const PersonEditCard(PersonEditCardId.admin, label: 'Amministratore'));
  }

  if (roles.contains('DOCENTE'))
  {
    cards.add(const PersonEditCard(PersonEditCardId.teacher, label: 'Docente'));
  }

  if (roles.contains('CORSISTA'))
  {
    cards.add(const PersonEditCard(PersonEditCardId.courseParticipant, label: 'Corsista'));
  }

  if (roles.contains('STUDENTE'))
  {
    cards.add(const PersonEditCard(PersonEditCardId.student, label: 'Studente'));
    cards.add(const PersonEditCard(PersonEditCardId.schoolEnrollments, label: 'Anni scolastici'));
  }

  final bool isStaff = roles.contains('AMMINISTRATORE') ||
      roles.contains('DOCENTE') ||
      roles.contains('PSICOLOGO');

  if (isStaff)
  {
    cards.add(const PersonEditCard(PersonEditCardId.staff, label: 'Collaborazione'));
  }

  if (form.isCreation && !onlyParent && !roles.contains('PSICOLOGO'))
  {
    cards.add(const PersonEditCard(
      PersonEditCardId.psychologicalSupport,
      label: 'Sostegno psicologico',
    ));
  }

  if (!onlyParent && form.isMinor)
  {
    cards.add(const PersonEditCard(PersonEditCardId.minorSafety, label: 'Sicurezza del minore'));
  }

  if (!onlyParent)
  {
    cards.add(const PersonEditCard(PersonEditCardId.consents, label: 'Consensi'));
  }

  return cards;
}

PersonEditStep _personalInfoStep(PersonEditForm form, {required bool revoked})
{
  return PersonEditStep(
    id: PersonEditStepId.personalInfo,
    question: 'Chi è?',
    hint: form.isCreation
            ? 'Compila i dati anagrafici e di contatto della persona. Dopo la creazione, '
                'sarà possibile modificare solo la residenza e i contatti.'
            : 'Per motivi di sicurezza, le informazioni personali principali ' 
            'non possono essere modificate manualmente.\n'
            'Se hai riscontrato un errore, puoi richiederne la correzione utilizzando il pulsante in basso.',
    cards: const [
      PersonEditCard(PersonEditCardId.identity, label: 'Identità'),
      PersonEditCard(PersonEditCardId.birthData, label: 'Dati anagrafici'),
      PersonEditCard(PersonEditCardId.residence, label: 'Residenza'),
      PersonEditCard(PersonEditCardId.contacts, label: 'Contatti'),
    ],
  );
}

List<PersonEditStep> buildEditSteps(
  PersonEditForm form, {
  PersonEditPurpose purpose = PersonEditPurpose.edit,
})
{
  // Expelled or resigned: only the personal details remain editable.
  if (form.person?.isMembershipRevoked ?? false)
  {
    return [_personalInfoStep(form, revoked: true)];
  }

  final List<PersonEditStep> steps = [];

  final bool asksType = purpose == PersonEditPurpose.edit ||
      purpose == PersonEditPurpose.create;

  if (asksType)
  {
    steps.add(const PersonEditStep(
      id: PersonEditStepId.type,
      question: 'Qual è il rapporto di questa persona con l\'Associazione?',
      hint: 'Scegli la categoria che descrive meglio la sua posizione.',
      cards: [PersonEditCard(PersonEditCardId.involvement)],
    ));
  }

  if (form.involvementType == 0 && purpose != PersonEditPurpose.createParent)
  {
    steps.add(const PersonEditStep(
      id: PersonEditStepId.roles,
      question: 'Quali ruoli ricopre all\'interno dell\'Associazione?',
      hint: 'Puoi sceglierne più di uno.',
      cards: [PersonEditCard(PersonEditCardId.roleChoice)],
    ));
  }

  if (form.asksAssociationQuestion)
  {
    steps.add(const PersonEditStep(
      id: PersonEditStepId.association,
      question: 'Vuole iscriversi anche personalmente?',
      hint: 'Il genitore può iscrivere il proprio figlio senza diventare socio.',
      cards: [PersonEditCard(PersonEditCardId.associationChoice)],
    ));
  }

  steps.add(_personalInfoStep(form, revoked: false));

  final List<PersonEditCard> associative = associativeCardsFor(form);

  if (associative.isNotEmpty)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.associativeInfo,
      question: 'Che cosa serve sapere per i suoi ruoli?',
      hint: 'Compila i dati richiesti dai ruoli selezionati.',
      cards: associative,
    ));
  }

  final bool asksRelations = purpose == PersonEditPurpose.edit ||
      purpose == PersonEditPurpose.create;

  if (asksRelations && form.isMinor)
  {
    steps.add(const PersonEditStep(
      id: PersonEditStepId.parents,
      question: 'Chi sono i suoi genitori o tutori legali?',
      hint: 'Almeno uno, al massimo due.',
      cards: [PersonEditCard(PersonEditCardId.parents)],
    ));
  }

  if (asksRelations && form.selectedRoles.contains('GENITORE'))
  {
    steps.add(const PersonEditStep(
      id: PersonEditStepId.minors,
      question: 'Di quali minori è genitore o tutore?',
      hint: 'Seleziona le persone di cui è responsabile legale.',
      cards: [PersonEditCard(PersonEditCardId.minors)],
    ));
  }

  if (form.selectedRoles.contains('DOCENTE'))
  {
    steps.add(const PersonEditStep(
      id: PersonEditStepId.subjects,
      question: 'Cosa insegna?',
      hint: 'Seleziona le discipline in cui il docente è competente. Per ognuna '
            'di esse è possibile indicare i percorsi di studio in cui è disponibile a insegnare.\n'
            'È inoltre possibile selezionare i servizi offerti dall\'Associazione.',
      cards: [PersonEditCard(PersonEditCardId.subjects)],
    ));
  }

  return steps;
}

// Field steps answer true: they are validated when the forward arrow is pressed.
bool stepIsAnswered(PersonEditStepId id, PersonEditForm form)
{
  return switch (id)
  {
    PersonEditStepId.type => form.involvementType >= 0,
    PersonEditStepId.roles => form.activeRoles.isNotEmpty,
    PersonEditStepId.association => form.parentIsMember != null,
    _ => true,
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
