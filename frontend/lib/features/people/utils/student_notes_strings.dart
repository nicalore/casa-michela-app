const String kMethodologicalNotesTitle = 'Osservazioni metodologiche';
const String kTechnicalNotesTitle = 'Osservazioni tecniche';
const String kTeacherNotesTitle = 'Osservazioni dei docenti';

String notesCountLabel(int count) => count == 1 ? '1 osservazione' : '$count osservazioni';

const String kNewNoteEyebrow = 'Nuova osservazione';
const String kEditNoteEyebrow = 'Modifica osservazione';
const String kNewTechnicalNoteEyebrow = 'Nuova osservazione tecnica';
const String kEditTechnicalNoteEyebrow = 'Modifica osservazione tecnica';

String notesReadersHint(String firstName) =>
    'Queste indicazioni saranno lette dai docenti che di volta in volta seguiranno $firstName.';

const String kTeacherNoteHint = 'Questa osservazione sarà inviata agli amministratori.';
const String kSubjectLabel = 'Materia';

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

const String kNoteCreated = 'Osservazione creata con successo!';
const String kNoteSent = 'Osservazione inviata con successo!';
const String kNoteEdited = 'Osservazione modificata con successo!';
const String kNoteDeletedDone = 'Osservazione eliminata con successo!';
