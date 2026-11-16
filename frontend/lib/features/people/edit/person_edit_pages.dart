import 'package:flutter/material.dart';

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

  if (!onlyParent)
  {
    cards.add(const PersonEditCard(PersonEditCardId.memberships, label: 'Iscrizioni'));
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
    // Leaving early is a minor's question only, so the tab goes with it.
    if (form.isMinor)
    {
      cards.add(const PersonEditCard(PersonEditCardId.earlyExit, label: 'Uscita anticipata'));
    }

    // Later they change only in the pupil's «Osservazioni».
    if (form.isCreation)
    {
      cards.add(const PersonEditCard(PersonEditCardId.certifications, label: 'Certificazioni'));
    }

    cards.add(const PersonEditCard(PersonEditCardId.schoolEnrollments, label: 'Anni scolastici'));
  }

  // After the administrative role: president, vice president and treasurer cannot be paid, which overrides this.
  final bool isStaff = roles.contains('AMMINISTRATORE') ||
      roles.contains('DOCENTE') ||
      roles.contains('PSICOLOGO');

  if (isStaff && !form.collaborationInCompensi)
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

// Drafts, not his: the questions of the re-enrollment steps.
List<PersonEditStep> _reEnrollmentSteps(PersonEditForm form)
{
  return [
    PersonEditStep(
      id: PersonEditStepId.reEnrollment,
      question: 'Da quando vale la nuova iscrizione?',
      hint: 'È l\'iscrizione del ${form.reEnrollYearCtrl.text}: indica il giorno da cui parte.',
      cards: const [PersonEditCard(PersonEditCardId.reEnrollment)],
    ),
    if (form.asksSchoolYear)
      const PersonEditStep(
        id: PersonEditStepId.schoolYear,
        question: 'Che classe frequenta quest\'anno?',
        hint: 'Aggiungi l\'anno scolastico in corso: la tariffa dipende dal livello.',
        cards: [PersonEditCard(PersonEditCardId.schoolEnrollments)],
      ),
    PersonEditStep(
      id: PersonEditStepId.payment,
      question: 'Come avvengono i pagamenti?',
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

  // Must follow the associative step: a pupil's rate depends on the school year filled in just before.
  if (form.showsPaymentStep)
  {
    steps.add(PersonEditStep(
      id: PersonEditStepId.payment,
      question: 'Come avvengono i pagamenti?',
      hint: _paymentHint(form),
      cards: const [PersonEditCard(PersonEditCardId.payment)],
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

  if (form.asksSubjects)
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

// Says only what the card asks: fees only of whoever is enrolled this year.
String _paymentHint(PersonEditForm form)
{
  // A member on file becoming a pupil: the method is already in the «Pagamenti» tab.
  if (!form.asksPaymentStep)
  {
    return 'Seleziona la tariffa scelta per il servizio di aiuto compiti.';
  }

  if (form.asksFees)
  {
    return form.asksTariff
        ? 'Seleziona la modalità di pagamento preferita e, per gli studenti, la tariffa scelta per il '
          'servizio di aiuto compiti, l’iscrizione e l’assicurazione.'
        : 'Seleziona la modalità di pagamento preferita, l’iscrizione e l’assicurazione.';
  }

  return form.asksTariff
      ? 'Seleziona la modalità di pagamento preferita e, per gli studenti, '
        'la tariffa scelta per il servizio di aiuto compiti.'
      : 'Seleziona la modalità di pagamento preferita.';
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
      'Scegli il rapporto con l\'Associazione per andare avanti.',
    PersonEditStepId.roles when form.activeRoles.isEmpty =>
      'Seleziona almeno un ruolo per andare avanti.',
    PersonEditStepId.association when form.parentIsMember == null =>
      'Indica se vuole iscriversi anche personalmente per andare avanti.',
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
