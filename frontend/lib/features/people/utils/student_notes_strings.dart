import '../../../core/language/app_language.dart';

String get kMethodologicalNotesTitle => tr('Osservazioni metodologiche', 'Methodological observations');
String get kTechnicalNotesTitle => tr('Osservazioni tecniche', 'Technical observations');
String get kTeacherNotesTitle => tr('Osservazioni dei docenti', 'Teachers’ observations');

// The server's own refusal, for health data asked of a family that did not consent.
String get kHealthDataWithoutConsent => tr(
  'Senza il consenso ai dati particolari non si possono registrare allergie, '
  'farmaci, certificazioni e sostegno psicologico.',
  'Without consent to special category data, allergies, medication, '
  'certifications and psychological support cannot be recorded.',
);

// An administrator's notes on a teacher, for the administrators and the teacher alike.
String get kObservationsTitle => tr('Osservazioni', 'Observations');
String get kNoObservations => tr('Nessuna osservazione', 'No observations');

// What the administrators judge a teacher on: key as the server has it, name, what it asks of the
// teacher, the same told to the administrators. Ordered in the pairs of the administrators' grid.
String get kCriteriaTitle => tr('Criteri di valutazione', 'Evaluation criteria');
String get kCriteriaIntro => tr(
  'Oltre ai feedback di studenti e genitori, il tuo operato viene valutato in base a questi criteri:',
  'Besides feedback from students and parents, your work is evaluated on these criteria:',
);

typedef TeacherCriterion = ({String key, String name, String own, String other});

List<TeacherCriterion> get kCriteria => [
  (
    key: 'competence',
    name: tr('Competenza', 'Competence'),
    own: tr(
      'Possiedi una solida conoscenza delle materie che insegni e sai applicarla efficacemente durante le lezioni.',
      'You have a solid knowledge of the subjects you teach and can apply it effectively during lessons.',
    ),
    other: tr(
      'Possiede una solida conoscenza delle materie che insegna e sa applicarla efficacemente durante le '
      'lezioni.',
      'Has a solid knowledge of the subjects they teach and can apply it effectively during lessons.',
    ),
  ),
  (
    key: 'clarity',
    name: tr('Chiarezza', 'Clarity'),
    own: tr(
      'Sai spiegare gli argomenti in modo chiaro e comprensibile, adattando le spiegazioni alle conoscenze dello '
      'studente.',
      'You can explain topics clearly and understandably, adapting explanations to what the student knows.',
    ),
    other: tr(
      'Sa spiegare gli argomenti in modo chiaro e comprensibile, adattando le spiegazioni alle conoscenze dello '
      'studente.',
      'Can explain topics clearly and understandably, adapting explanations to what the student knows.',
    ),
  ),
  (
    key: 'empathy',
    name: tr('Empatia', 'Empathy'),
    own: tr(
      'Sai riconoscere e comprendere le esigenze, le difficoltà e i punti di forza dello studente, adattando il '
      'tuo approccio alle sue caratteristiche.',
      'You can recognise and understand the student’s needs, difficulties and strengths, adapting your '
      'approach to their characteristics.',
    ),
    other: tr(
      'Sa riconoscere e comprendere le esigenze, le difficoltà e i punti di forza dello studente, adattando il '
      'proprio approccio alle sue caratteristiche.',
      'Can recognise and understand the student’s needs, difficulties and strengths, adapting their '
      'approach to the student’s characteristics.',
    ),
  ),
  (
    key: 'motivation',
    name: tr('Motivazione', 'Motivation'),
    own: tr(
      "Sai incoraggiare lo studente, stimolarne la partecipazione e sostenerne l'impegno nello studio.",
      'You can encourage the student, spur their participation and support their commitment to study.',
    ),
    other: tr(
      "Sa incoraggiare lo studente, stimolarne la partecipazione e sostenerne l'impegno nello studio.",
      'Can encourage the student, spur their participation and support their commitment to study.',
    ),
  ),
  (
    key: 'relationship',
    name: tr('Relazione', 'Relationship'),
    own: tr(
      'Sai instaurare e mantenere una relazione positiva con lo studente, comunicando in modo rispettoso e '
      'adeguando il tuo stile comunicativo alla sua età e alle sue caratteristiche.',
      'You can build and keep a positive relationship with the student, communicating respectfully and '
      'adapting your communication style to their age and characteristics.',
    ),
    other: tr(
      'Sa instaurare e mantenere una relazione positiva con lo studente, comunicando in modo rispettoso e '
      'adeguando il proprio stile comunicativo alla sua età e alle sue caratteristiche.',
      'Can build and keep a positive relationship with the student, communicating respectfully and adapting '
      'their communication style to the student’s age and characteristics.',
    ),
  ),
  (
    key: 'transparency',
    name: tr('Trasparenza', 'Transparency'),
    own: tr(
      'Comunichi apertamente e tempestivamente eventuali problemi o difficoltà con le persone interessate, '
      'coinvolgendo il Direttivo quando necessario, anche in presenza di criticità nella relazione con gli '
      'studenti.',
      'You communicate any problems or difficulties openly and promptly to the people concerned, involving '
      'the Board when needed, including when there are issues in the relationship with students.',
    ),
    other: tr(
      'Comunica apertamente e tempestivamente eventuali problemi o difficoltà con le persone interessate, '
      'coinvolgendo il Direttivo quando necessario, anche in presenza di criticità nella relazione con gli '
      'studenti.',
      'Communicates any problems or difficulties openly and promptly to the people concerned, involving the '
      'Board when needed, including when there are issues in the relationship with students.',
    ),
  ),
  (
    key: 'flexibility',
    name: tr('Flessibilità', 'Flexibility'),
    own: tr(
      'Sai affrontare problemi e imprevisti con equilibrio, adattando il tuo approccio alle circostanze e alle '
      'esigenze che emergono durante le lezioni.',
      'You can face problems and the unexpected calmly, adapting your approach to the circumstances and '
      'needs that arise during lessons.',
    ),
    other: tr(
      'Sa affrontare problemi e imprevisti con equilibrio, adattando il proprio approccio alle circostanze e '
      'alle esigenze che emergono durante le lezioni.',
      'Can face problems and the unexpected calmly, adapting their approach to the circumstances and needs '
      'that arise during lessons.',
    ),
  ),
  (
    key: 'proactivity',
    name: tr('Proattività', 'Proactivity'),
    own: tr(
      "Dimostri iniziativa e disponibilità a contribuire al miglioramento dell'Associazione, anche andando oltre i "
      'compiti strettamente assegnati.',
      'You show initiative and willingness to help improve the Association, even going beyond the tasks '
      'strictly assigned.',
    ),
    other: tr(
      "Dimostra iniziativa e disponibilità a contribuire al miglioramento dell'Associazione, anche andando oltre "
      'i compiti strettamente assegnati.',
      'Shows initiative and willingness to help improve the Association, even going beyond the tasks '
      'strictly assigned.',
    ),
  ),
  (
    key: 'reliability',
    name: tr('Puntualità e affidabilità', 'Punctuality and reliability'),
    own: tr(
      'Rispetti gli orari e gli impegni assunti, portando a termine i compiti assegnati con cura e responsabilità.',
      'You respect schedules and commitments, completing assigned tasks with care and responsibility.',
    ),
    other: tr(
      'Rispetta gli orari e gli impegni assunti, portando a termine i compiti assegnati con cura e '
      'responsabilità.',
      'Respects schedules and commitments, completing assigned tasks with care and responsibility.',
    ),
  ),
  (
    key: 'rules',
    name: tr('Rispetto del regolamento', 'Respect for the rules'),
    own: tr(
      "Rispetti il regolamento dell'Associazione e contribuisci a farlo rispettare agli studenti, con costanza e "
      'attenzione.',
      'You respect the Association’s rules and help make students respect them, consistently and '
      'attentively.',
    ),
    other: tr(
      "Rispetta il regolamento dell'Associazione e contribuisce a farlo rispettare agli studenti, con costanza e "
      'attenzione.',
      'Respects the Association’s rules and helps make students respect them, consistently and attentively.',
    ),
  ),
];

// The administrators' evaluation card; [name] is the teacher's first name.
String get kEvaluationTitle => tr('Valutazione', 'Evaluation');

String evaluationHint(String name) => tr(
  'Spunta i criteri che $name rispetta: ognuno vale mezzo punto.',
  'Tick the criteria $name meets: each is worth half a point.',
);

String evaluationLapsed(String name) => tr(
  '$name è non collaborante: la sua valutazione è 0 finché non torna a collaborare.',
  '$name is non-collaborating: their evaluation is 0 until they collaborate again.',
);

String notesCountLabel(int count) =>
    count == 1 ? tr('1 osservazione', '1 observation') : tr('$count osservazioni', '$count observations');

String get kNewNoteEyebrow => tr('Nuova osservazione', 'New observation');
String get kEditNoteEyebrow => tr('Modifica osservazione', 'Edit observation');
String get kNewTechnicalNoteEyebrow => tr('Nuova osservazione tecnica', 'New technical observation');
String get kEditTechnicalNoteEyebrow => tr('Modifica osservazione tecnica', 'Edit technical observation');

String notesReadersHint(String firstName) => tr(
  'Queste indicazioni saranno lette dai docenti che di volta in volta seguiranno $firstName.',
  'These notes will be read by the teachers who work with $firstName from time to time.',
);

String administratorNoteHint(String fullName) => tr(
  "$fullName riceverà una notifica e potrà leggere l'osservazione nella sua pagina personale.",
  '$fullName will get a notification and can read the observation on their own page.',
);

String get kTeacherNoteHint => tr(
  'Questa osservazione sarà inviata agli amministratori.',
  'This observation will be sent to the administrators.',
);
String get kTeacherNoteFieldLabel => tr('Osservazione', 'Observation');

String get kAddLabel => tr('AGGIUNGI', 'ADD');
String get kAddNoteLabel => tr('AGGIUNGI OSSERVAZIONE', 'ADD OBSERVATION');
String get kSendLabel => tr('INVIA', 'SEND');
String get kSaveLabel => tr('SALVA', 'SAVE');
String get kSaveChangesLabel => tr('SALVA MODIFICHE', 'SAVE CHANGES');
String get kCancelLabel => tr('ANNULLA', 'CANCEL');
String get kDeleteLabel => tr('ELIMINA', 'DELETE');

String get kDeletionEyebrow => tr('Eliminazione', 'Deletion');
String get kConfirmTitle => tr('Confermi?', 'Confirm?');

String get kNoteDeleted =>
    tr("L'osservazione verrà eliminata definitivamente.", 'The observation will be permanently deleted.');

String get kEmptyNote => tr('Il contenuto non può essere vuoto.', 'The content cannot be empty.');
String get kNoteTooLong => tr("L'osservazione è troppo lunga.", 'The observation is too long.');
String get kImagesTooLarge => tr('Le immagini superano i 15 MB totali.', 'The images exceed 15 MB in total.');

String get kNoteCreated => tr('Osservazione creata con successo!', 'Observation created successfully!');
String get kNoteSent => tr('Osservazione inviata con successo!', 'Observation sent successfully!');
String get kNoteEdited => tr('Osservazione modificata con successo!', 'Observation edited successfully!');
String get kNoteDeletedDone => tr('Osservazione eliminata con successo!', 'Observation deleted successfully!');
