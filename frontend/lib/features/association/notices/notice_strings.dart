import '../../../core/language/app_language.dart';

String get kNoticeEyebrow => tr('Comunicazione', 'Announcement');
String get kNewNoticeTitle => tr('Nuova comunicazione', 'New announcement');
String get kEditNoticeTitle => tr('Modifica comunicazione', 'Edit announcement');
String get kNewNoticeButton => tr('NUOVA COMUNICAZIONE', 'NEW ANNOUNCEMENT');
String get kSearchNoticeHint => tr('Cerca comunicazione...', 'Search announcements...');
String get kNoNotices => tr('Nessuna comunicazione inviata.', 'No announcements sent.');
String get kNoReceivedNotices => tr('Nessuna comunicazione ricevuta.', 'No announcements received.');
String get kNoMatchingNotices => tr('Nessuna comunicazione trovata.', 'No announcements found.');
String get kOnlyMine => tr('Scritte da me', 'Written by me');

String noticeCountLabel(int count) => count == 1
    ? tr('1 comunicazione trovata', '1 announcement found')
    : tr('$count comunicazioni trovate', '$count announcements found');

String noticeSentLabel(String day, String hour) => '$day – $hour';

String noticeEditedLabel(String day) => tr('(modificata il $day)', '(edited on $day)');

String get kSentLabel => tr('Data', 'Date');
String get kEditedLabel => tr('Modificata', 'Edited');
String get kAuthorLabel => tr('Inviata da', 'Sent by');
String get kRecipientsLabel => tr('Destinatari', 'Recipients');
String get kTitleLabel => tr('Titolo', 'Title');
String get kMessageLabel => tr('Messaggio', 'Message');
String get kAttachmentsLabel => tr('Allegati', 'Attachments');

String noticePeopleLabel(int people) => people == 1 ? tr('1 persona', '1 person') : tr('$people persone', '$people people');

String recipientHint(int people, int emails) =>
    '${noticePeopleLabel(people)}, ${emails == 1 ? tr('1 email', '1 email') : tr('$emails email', '$emails emails')}';

String attachmentsUsage(String used, String limit) => tr('$used di $limit', '$used of $limit');

String get kAddFile => tr('AGGIUNGI FILE', 'ADD FILES');
String get kOrDropHere => tr('o trascinali qui', 'or drag them here');
String get kSend => tr('INVIA', 'SEND');
String get kCancel => tr('ANNULLA', 'CANCEL');
String get kDelete => tr('ELIMINA', 'DELETE');
String get kEdit => tr('MODIFICA', 'EDIT');

String get kTextStyle => tr('Testo', 'Text');
String get kHeadingStyle => tr('Titolo', 'Heading');
String get kSubheadingStyle => tr('Sottotitolo', 'Subheading');

String get kBoldTip => tr('Grassetto', 'Bold');
String get kItalicTip => tr('Corsivo', 'Italic');
String get kStrikeTip => tr('Barrato', 'Strikethrough');
String get kBulletsTip => tr('Elenco puntato', 'Bulleted list');
String get kNumbersTip => tr('Elenco numerato', 'Numbered list');
String get kQuoteTip => tr('Citazione', 'Quote');
String get kLinkTip => tr('Link', 'Link');
String get kImageTip => tr('Foto', 'Photo');
String get kDividerTip => tr('Riga divisoria', 'Divider');
String get kUndoTip => tr('Annulla', 'Undo');
String get kRedoTip => tr('Ripeti', 'Redo');

String get kLinkEyebrow => tr('Link', 'Link');
String get kLinkTitle => tr('Inserisci un link', 'Insert a link');
String get kLinkAddressLabel => tr('Indirizzo', 'Address');
const String kLinkAddressHint = 'https://...';
String get kLinkConfirm => tr('INSERISCI', 'INSERT');
String get kLinkInvalid => tr('Scrivi l\'indirizzo del link.', "Write the link's address.");

String get kNoRecipients => tr('Scegli almeno un destinatario.', 'Choose at least one recipient.');
String get kNoTitle => tr('Scrivi un titolo.', 'Write a title.');
String get kNoMessage => tr('Scrivi il messaggio.', 'Write the message.');
String get kTooLarge => tr('Gli allegati superano i 15 MB totali.', 'The attachments exceed 15 MB in total.');
String get kFileUnreadable => tr('Impossibile aggiungere il file.', "Couldn't add the file.");
String get kMessageTooLong => tr('Il messaggio è troppo lungo.', 'The message is too long.');

String get kSendEyebrow => tr('Invio', 'Sending');
String get kConfirmTitle => tr('Confermi?', 'Confirm?');

// The count is set in bold between the two parts.
String sendConfirmationOpening(int people) => people == 1
    ? tr('Il messaggio verrà inviato a ', 'The message will be sent to ')
    : tr('Il messaggio verrà inviato alle ', 'The message will be sent to ');

String sendConfirmationClosing(List<String> roles) => roles.length == 1
    ? tr(' con il seguente ruolo: ${roles.join(', ')}.', ' with the following role: ${roles.join(', ')}.')
    : tr(' con i seguenti ruoli: ${roles.join(', ')}.', ' with the following roles: ${roles.join(', ')}.');

String get kDeleteEyebrow => tr('Eliminazione', 'Deletion');

// The title is set in bold between the two parts.
String get kDeleteOpening => tr('La comunicazione ', 'The announcement ');
String get kDeleteClosing => tr(' verrà eliminata definitivamente.', ' will be deleted permanently.');

// Every role chosen.
String get kAllRoles => tr('Tutti gli iscritti', 'All members');

String get kNoticeSent => tr('Comunicazione inviata con successo!', 'Announcement sent!');
String get kNoticeEdited => tr('Comunicazione modificata con successo!', 'Announcement edited!');
String get kNoticeDeleted => tr('Comunicazione eliminata con successo!', 'Announcement deleted!');

String get kImageUnavailable => tr('Immagine non disponibile', 'Image unavailable');

String get kPinTip => tr('Fissa in cima', 'Pin to top');
String get kUnpinTip => tr('Togli dalla cima', 'Unpin');

String pinnedUntilLabel(String day) => tr('Fino al $day', 'Until $day');

String get kPinEyebrow => tr('Fissa in cima', 'Pin to top');
String get kPinForever => tr('Per sempre', 'Forever');
String get kPinUntilDay => tr('Fino a una data', 'Until a date');
String get kPinUntilLabel => tr('Fino al', 'Until');
String get kPinConfirm => tr('FISSA', 'PIN');

String get kNoticePinned => tr('Comunicazione fissata in cima!', 'Announcement pinned to the top!');
String get kNoticeUnpinned => tr('Comunicazione tolta dalla cima!', 'Announcement unpinned!');

String get kHomeNoticesEyebrow => tr('Messaggi', 'Messages');
String get kHomeNoticesTitle => tr('Comunicazioni e avvisi', 'Announcements and notices');
String get kHomeNoNotices => tr('Nessuna comunicazione.', 'No announcements.');
String get kHomeNoticesUnavailable => tr('Le comunicazioni non sono disponibili.', 'Announcements are unavailable.');

String get kNoticesSortTitle => tr('Ordina per', 'Sort by');

String noticeAttachmentCountLabel(int count) => count == 1 ? tr('1 allegato', '1 attachment') : tr('$count allegati', '$count attachments');

String get kAttachmentSaved => tr("L'allegato è stato scaricato.", 'The attachment has been downloaded.');
String get kAttachmentSaveFailed => tr("Non è stato possibile salvare l'allegato.", "Couldn't save the attachment.");
