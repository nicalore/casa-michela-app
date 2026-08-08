import 'package:flutter/material.dart';

import 'person_edit_form.dart';

// The steps of the edit dialog, as data rather than as a chain of ifs.
//
// The order used to live inside the forward button: eight blocks deciding which
// step came next, plus two counters for the cards inside two of them, plus a
// separate chain to know which was the last. Changing a role meant keeping three
// of those places in mind. Here the steps are a list computed from the roles,
// and moving is arithmetic on an index.

// What the dialog is for. The cards are the same; what changes is which
// questions make sense.
enum PersonEditPurpose
{
  // A person who already exists.
  edit,

  /// Una persona nuova, con tutte le sue domande.
  create,

  // A parent created on the fly while registering their child: the role is
  // already decided, and the ties are held by the dialog one arrived from.
  createParent,

  /// Un minore creato al volo mentre si registra il suo genitore.
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

// The cards inside a step. A simple step has just one.
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

  // The card's name, which sits above its controls. Null when the card is the
  // whole step and the question has already named it.
  final String? label;

  const PersonEditCard(this.id, {this.label});
}

class PersonEditStep
{
  final PersonEditStepId id;

  // The question the step answers, and the sentence saying how.
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

// The cards of the association step: which ones there are is told by the roles.
// The collaboration comes after the administrator details, because it is the
// administrative role that decides whether the collaboration may be paid.
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

  // Psychological support is asked of someone joining, not of the
  // psychologists, and only of members.
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

  // Last, because they are what one accepts after seeing everything else. On
  // creation there are five: three declarations to sign and two consents to give
  // or refuse. Afterwards the two remain, changeable at any time — a consent
  // that cannot be withdrawn is not a consent.
  if (!onlyParent)
  {
    cards.add(const PersonEditCard(PersonEditCardId.consents, label: 'Consensi'));
  }

  return cards;
}

// The personal details step: who this person is, where they live and how they
// are reached. The only one that does not speak of the association, which is why
// it survives a revocation on its own — see [buildEditSteps].
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

/// I passaggi da mostrare, nell'ordine.
List<PersonEditStep> buildEditSteps(
  PersonEditForm form, {
  PersonEditPurpose purpose = PersonEditPurpose.edit,
})
{
  // Expelled or resigned: the personal details remain and nothing else.
  //
  // Roles, memberships, payments, consents, subjects taught all hold for someone
  // who is part of the association, and this person no longer is — offering them
  // for editing would be offering to rewrite a relationship that has been
  // closed. The personal details, by contrast, are theirs and not the
  // association's, and have to stay right regardless: a wrong address is still
  // wrong after an expulsion.
  //
  // It does not touch creation: a person born here has no last membership to
  // revoke yet.
  if (form.person?.isMembershipRevoked ?? false)
  {
    return [_personalInfoStep(form, revoked: true)];
  }

  final List<PersonEditStep> steps = [];

  // Whoever arrives here to create a parent or a minor is not asked what their
  // relationship with the association is: the dialog they came from is already
  // saying it.
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

  // A parent or a minor created on the fly carry no ties of their own: what
  // counts is the tie to the person one started from, and they hold it.
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
      question: 'Quali discipline insegna?',
      hint: 'Spuntare una disciplina la assegna a tutti i percorsi in cui è insegnata; '
          'il riquadro a destra della riga restringe la scelta.',
      cards: [PersonEditCard(PersonEditCardId.subjects)],
    ));
  }

  return steps;
}

// Whether the step has had its answer.
//
// The three multiple-choice questions start without one: a new person is neither
// involved nor a member only, has no roles, and a parent has not said yet
// whether they join too. Until they answer, the forward arrow is off, instead of
// letting through an answer nobody gave — which is what the default ticks did.
//
// The other steps are fields to write: those are checked on pressing the arrow,
// which is the moment what is missing can be named.
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

// Where a step sits, kept by name and not by position: ticking a role slips a
// step into the middle, and a hand-kept index would slide out from under the
// finger.
int indexOfStep(List<PersonEditStep> steps, PersonEditStepId id)
{
  final int index = steps.indexWhere((step) => step.id == id);

  return index < 0 ? 0 : index;
}

@visibleForTesting
List<PersonEditStepId> stepIdsOf(List<PersonEditStep> steps) =>
    steps.map((step) => step.id).toList();
