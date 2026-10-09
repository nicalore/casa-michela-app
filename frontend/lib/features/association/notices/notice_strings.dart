// Every word the notices pages show, in one place.
const String kNoticeEyebrow = 'Comunicazione';
const String kNewNoticeTitle = 'Nuova comunicazione';
const String kEditNoticeTitle = 'Modifica comunicazione';
const String kNewNoticeButton = 'NUOVA COMUNICAZIONE';
const String kSearchNoticeHint = 'Cerca comunicazione...';
const String kNoNotices = 'Nessuna comunicazione inviata.';
const String kNoReceivedNotices = 'Nessuna comunicazione ricevuta.';
const String kNoMatchingNotices = 'Nessuna comunicazione trovata.';
const String kOnlyMine = 'Scritte da me';

String noticeCountLabel(int count) => count == 1 ? '1 comunicazione trovata' : '$count comunicazioni trovate';

String noticeSentLabel(String day, String hour) => '$day – $hour';

String noticeEditedLabel(String day) => '(modificata il $day)';

const String kSentLabel = 'Data';
const String kEditedLabel = 'Modificata';
const String kAuthorLabel = 'Inviata da';
const String kRecipientsLabel = 'Destinatari';
const String kTitleLabel = 'Titolo';
const String kMessageLabel = 'Messaggio';
const String kAttachmentsLabel = 'Allegati';

String noticePeopleLabel(int people) => people == 1 ? '1 persona' : '$people persone';

String recipientHint(int people, int emails) =>
    '${noticePeopleLabel(people)}, ${emails == 1 ? '1 email' : '$emails email'}';

String attachmentsUsage(String used, String limit) => '$used di $limit';

const String kAddFile = 'AGGIUNGI FILE';
const String kOrDropHere = 'o trascinali qui';
const String kSend = 'INVIA';
const String kCancel = 'ANNULLA';
const String kDelete = 'ELIMINA';
const String kEdit = 'MODIFICA';

const String kTextStyle = 'Testo';
const String kHeadingStyle = 'Titolo';
const String kSubheadingStyle = 'Sottotitolo';

const String kBoldTip = 'Grassetto';
const String kItalicTip = 'Corsivo';
const String kStrikeTip = 'Barrato';
const String kBulletsTip = 'Elenco puntato';
const String kNumbersTip = 'Elenco numerato';
const String kQuoteTip = 'Citazione';
const String kLinkTip = 'Link';
const String kImageTip = 'Foto';
const String kDividerTip = 'Riga divisoria';
const String kUndoTip = 'Annulla';
const String kRedoTip = 'Ripeti';

const String kLinkEyebrow = 'Link';
const String kLinkTitle = 'Inserisci un link';
const String kLinkAddressLabel = 'Indirizzo';
const String kLinkAddressHint = 'https://...';
const String kLinkConfirm = 'INSERISCI';
const String kLinkInvalid = 'Scrivi l\'indirizzo del link.';

const String kNoRecipients = 'Scegli almeno un destinatario.';
const String kNoTitle = 'Scrivi un titolo.';
const String kNoMessage = 'Scrivi il messaggio.';
const String kTooLarge = 'Gli allegati superano i 15 MB totali.';
const String kFileUnreadable = 'Impossibile aggiungere il file.';
const String kMessageTooLong = 'Il messaggio è troppo lungo.';

const String kSendEyebrow = 'Invio';
const String kConfirmTitle = 'Confermi?';

// The count is set in bold between the two parts.
String sendConfirmationOpening(int people) => people == 1 ? 'Il messaggio verrà inviato a ' : 'Il messaggio verrà inviato alle ';

String sendConfirmationClosing(List<String> roles) =>
    '${roles.length == 1 ? ' con il seguente ruolo: ' : ' con i seguenti ruoli: '}${roles.join(', ')}.';

const String kDeleteEyebrow = 'Eliminazione';

// The title is set in bold between the two parts.
const String kDeleteOpening = 'La comunicazione ';
const String kDeleteClosing = ' verrà eliminata definitivamente.';

// Every role chosen.
const String kAllRoles = 'Tutti gli iscritti';

const String kNoticeSent = 'Comunicazione inviata con successo!';
const String kNoticeEdited = 'Comunicazione modificata con successo!';
const String kNoticeDeleted = 'Comunicazione eliminata con successo!';

const String kImageUnavailable = 'Immagine non disponibile';

const String kPinTip = 'Fissa in cima';
const String kUnpinTip = 'Togli dalla cima';

String pinnedUntilLabel(String day) => 'Fino al $day';

const String kPinEyebrow = 'Fissa in cima';
const String kPinForever = 'Per sempre';
const String kPinUntilDay = 'Fino a una data';
const String kPinUntilLabel = 'Fino al';
const String kPinConfirm = 'FISSA';

const String kNoticePinned = 'Comunicazione fissata in cima!';
const String kNoticeUnpinned = 'Comunicazione tolta dalla cima!';

const String kHomeNoticesEyebrow = 'Messaggi';
const String kHomeNoticesTitle = 'Comunicazioni e avvisi';
const String kHomeNoNotices = 'Nessuna comunicazione.';
const String kHomeNoticesUnavailable = 'Le comunicazioni non sono disponibili.';

const String kNoticesSortTitle = 'Ordina per';

String noticeAttachmentCountLabel(int count) => count == 1 ? '1 allegato' : '$count allegati';

const String kAttachmentSaved = "L'allegato è stato scaricato.";
const String kAttachmentSaveFailed = "Non è stato possibile salvare l'allegato.";
