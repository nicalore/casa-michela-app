const String kMethodologicalNotesTitle = 'Osservazioni metodologiche';
const String kTechnicalNotesTitle = 'Osservazioni tecniche';
const String kTeacherNotesTitle = 'Osservazioni dei docenti';

// An administrator's notes on a teacher, for the administrators and the teacher alike.
const String kObservationsTitle = 'Osservazioni';
const String kNoObservations = 'Nessuna osservazione';

// What the administrators judge a teacher on: key as the server has it, name, what it asks of the
// teacher, the same told to the administrators. Ordered in the pairs of the administrators' grid.
const String kCriteriaTitle = 'Criteri di valutazione';
const String kCriteriaIntro =
    'Oltre ai feedback di studenti e genitori, il tuo operato viene valutato in base a questi criteri:';

typedef TeacherCriterion = ({String key, String name, String own, String other});

const List<TeacherCriterion> kCriteria = [
  (
    key: 'competence',
    name: 'Competenza',
    own: 'Possiedi una solida conoscenza delle materie che insegni e sai applicarla efficacemente durante le lezioni.',
    other: 'Possiede una solida conoscenza delle materie che insegna e sa applicarla efficacemente durante le '
        'lezioni.',
  ),
  (
    key: 'clarity',
    name: 'Chiarezza',
    own: 'Sai spiegare gli argomenti in modo chiaro e comprensibile, adattando le spiegazioni alle conoscenze dello '
        'studente.',
    other: 'Sa spiegare gli argomenti in modo chiaro e comprensibile, adattando le spiegazioni alle conoscenze dello '
        'studente.',
  ),
  (
    key: 'empathy',
    name: 'Empatia',
    own: 'Sai riconoscere e comprendere le esigenze, le difficoltà e i punti di forza dello studente, adattando il '
        'tuo approccio alle sue caratteristiche.',
    other: 'Sa riconoscere e comprendere le esigenze, le difficoltà e i punti di forza dello studente, adattando il '
        'proprio approccio alle sue caratteristiche.',
  ),
  (
    key: 'motivation',
    name: 'Motivazione',
    own: "Sai incoraggiare lo studente, stimolarne la partecipazione e sostenerne l'impegno nello studio.",
    other: "Sa incoraggiare lo studente, stimolarne la partecipazione e sostenerne l'impegno nello studio.",
  ),
  (
    key: 'relationship',
    name: 'Relazione',
    own: 'Sai instaurare e mantenere una relazione positiva con lo studente, comunicando in modo rispettoso e '
        'adeguando il tuo stile comunicativo alla sua età e alle sue caratteristiche.',
    other: 'Sa instaurare e mantenere una relazione positiva con lo studente, comunicando in modo rispettoso e '
        'adeguando il proprio stile comunicativo alla sua età e alle sue caratteristiche.',
  ),
  (
    key: 'transparency',
    name: 'Trasparenza',
    own: 'Comunichi apertamente e tempestivamente eventuali problemi o difficoltà con le persone interessate, '
        'coinvolgendo il Direttivo quando necessario, anche in presenza di criticità nella relazione con gli '
        'studenti.',
    other: 'Comunica apertamente e tempestivamente eventuali problemi o difficoltà con le persone interessate, '
        'coinvolgendo il Direttivo quando necessario, anche in presenza di criticità nella relazione con gli '
        'studenti.',
  ),
  (
    key: 'flexibility',
    name: 'Flessibilità',
    own: 'Sai affrontare problemi e imprevisti con equilibrio, adattando il tuo approccio alle circostanze e alle '
        'esigenze che emergono durante le lezioni.',
    other: 'Sa affrontare problemi e imprevisti con equilibrio, adattando il proprio approccio alle circostanze e '
        'alle esigenze che emergono durante le lezioni.',
  ),
  (
    key: 'proactivity',
    name: 'Proattività',
    own: "Dimostri iniziativa e disponibilità a contribuire al miglioramento dell'Associazione, anche andando oltre i "
        'compiti strettamente assegnati.',
    other: "Dimostra iniziativa e disponibilità a contribuire al miglioramento dell'Associazione, anche andando oltre "
        'i compiti strettamente assegnati.',
  ),
  (
    key: 'reliability',
    name: 'Puntualità e affidabilità',
    own: 'Rispetti gli orari e gli impegni assunti, portando a termine i compiti assegnati con cura e responsabilità.',
    other: 'Rispetta gli orari e gli impegni assunti, portando a termine i compiti assegnati con cura e '
        'responsabilità.',
  ),
  (
    key: 'rules',
    name: 'Rispetto del regolamento',
    own: "Rispetti il regolamento dell'Associazione e contribuisci a farlo rispettare agli studenti, con costanza e "
        'attenzione.',
    other: "Rispetta il regolamento dell'Associazione e contribuisce a farlo rispettare agli studenti, con costanza e "
        'attenzione.',
  ),
];

// The administrators' evaluation card; [name] is the teacher's first name.
const String kEvaluationTitle = 'Valutazione';

String evaluationHint(String name) => 'Spunta i criteri che $name rispetta: ognuno vale mezzo punto.';

String evaluationLapsed(String name) =>
    '$name è non collaborante: la sua valutazione è 0 finché non torna a collaborare.';

String notesCountLabel(int count) => count == 1 ? '1 osservazione' : '$count osservazioni';

const String kNewNoteEyebrow = 'Nuova osservazione';
const String kEditNoteEyebrow = 'Modifica osservazione';
const String kNewTechnicalNoteEyebrow = 'Nuova osservazione tecnica';
const String kEditTechnicalNoteEyebrow = 'Modifica osservazione tecnica';

String notesReadersHint(String firstName) =>
    'Queste indicazioni saranno lette dai docenti che di volta in volta seguiranno $firstName.';

String administratorNoteHint(String fullName) =>
    "$fullName riceverà una notifica e potrà leggere l'osservazione nella sua pagina personale.";

const String kTeacherNoteHint = 'Questa osservazione sarà inviata agli amministratori.';
const String kTeacherNoteFieldLabel = 'Osservazione';

const String kAddLabel = 'AGGIUNGI';
const String kAddNoteLabel = 'AGGIUNGI OSSERVAZIONE';
const String kSendLabel = 'INVIA';
const String kSaveLabel = 'SALVA';
const String kSaveChangesLabel = 'SALVA MODIFICHE';
const String kCancelLabel = 'ANNULLA';
const String kDeleteLabel = 'ELIMINA';

const String kDeletionEyebrow = 'Eliminazione';
const String kConfirmTitle = 'Confermi?';

const String kNoteDeleted = "L'osservazione verrà eliminata definitivamente.";

const String kEmptyNote = 'Il contenuto non può essere vuoto.';
const String kNoteTooLong = "L'osservazione è troppo lunga.";
const String kImagesTooLarge = 'Le immagini superano i 15 MB totali.';

const String kNoteCreated = 'Osservazione creata con successo!';
const String kNoteSent = 'Osservazione inviata con successo!';
const String kNoteEdited = 'Osservazione modificata con successo!';
const String kNoteDeletedDone = 'Osservazione eliminata con successo!';
