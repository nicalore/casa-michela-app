import '../../core/language/app_language.dart';
import '../settings/utils/settings_strings.dart';

String get kUpdatesEntry => tr('Aggiornamenti', 'Updates');
String get kUpdatesTitle => tr('Aggiornamenti', 'Updates');

// The x.y.z of the app in use, as an update is filed under.
final String kUpdateVersion = RegExp(r'\d+\.\d+\.\d+').firstMatch(kAppVersion)!.group(0)!;

String updateHeading(String version) => tr('Nuovo aggiornamento - Versione $version', 'New update - Version $version');

String updateVersionLabel(String version) => tr('Versione $version', 'Version $version');

String get kUpdateSingleTitle => tr('Nuovo aggiornamento', 'New update');
String get kUpdatesGroupTitle => tr('Nuovi aggiornamenti', 'New updates');

String updateCountLabel(int count) => count == 1
    ? tr('1 aggiornamento pubblicato', '1 update published')
    : tr('$count aggiornamenti pubblicati', '$count updates published');

String get kNoUpdates => tr('Nessun aggiornamento pubblicato', 'No updates published');

String updateEditedLabel(String day) => tr('(modificato il $day)', '(edited on $day)');

String get kUpdateSentLabel => tr('Data', 'Date');
String get kUpdateEditedLabel => tr('Modificato', 'Edited');
String get kUpdateAuthorLabel => tr('Inviato da', 'Sent by');
String get kUpdateRecipientsLabel => tr('Destinatari', 'Recipients');
String get kUpdateTitleLabel => tr('Titolo', 'Title');
String get kUpdateMessageLabel => tr('Contenuto', 'Content');

// Every role chosen.
String get kUpdateAllRoles => tr('Tutti gli iscritti', 'All members');

String get kUpdateEyebrow => tr('Aggiornamento', 'Update');
String get kNewUpdateTitle => tr('Nuovo aggiornamento', 'New update');
String get kEditUpdateTitle => tr('Modifica aggiornamento', 'Edit update');

String get kNewUpdateButton => tr('NUOVO AGGIORNAMENTO', 'NEW UPDATE');
String get kPublishUpdate => tr('PUBBLICA', 'PUBLISH');
String get kSaveUpdate => tr('SALVA', 'SAVE');
String get kUpdateCancel => tr('ANNULLA', 'CANCEL');
String get kUpdateDelete => tr('ELIMINA', 'DELETE');
String get kUpdateEdit => tr('MODIFICA', 'EDIT');

String updatePeopleLabel(int people) => people == 1 ? tr('1 persona', '1 person') : tr('$people persone', '$people people');

String get kNoUpdateRecipients => tr('Scegli almeno un destinatario.', 'Choose at least one recipient.');
String get kNoUpdateTitle => tr('Scrivi un titolo.', 'Write a title.');
String get kNoUpdateMessage => tr('Scrivi il contenuto.', 'Write the content.');
String get kUpdateMessageTooLong => tr('Il contenuto è troppo lungo.', 'The content is too long.');
String get kUpdateImagesTooLarge => tr('Le immagini superano i 15 MB totali.', 'The images exceed 15 MB in total.');

String get kPublishEyebrow => tr('Pubblicazione', 'Publishing');
String get kUpdateConfirmTitle => tr('Confermi?', 'Confirm?');

// The count is set in bold between the two parts.
String publishConfirmationOpening(int people) => people == 1
    ? tr("L'aggiornamento verrà mostrato a ", 'The update will be shown to ')
    : tr("L'aggiornamento verrà mostrato alle ", 'The update will be shown to ');

String publishConfirmationClosing(List<String> roles) => roles.length == 1
    ? tr(' con il seguente ruolo: ${roles.join(', ')}.', ' with the following role: ${roles.join(', ')}.')
    : tr(' con i seguenti ruoli: ${roles.join(', ')}.', ' with the following roles: ${roles.join(', ')}.');

String get kDeleteUpdateEyebrow => tr('Eliminazione', 'Deletion');

// The title is set in bold between the two parts.
String get kDeleteUpdateOpening => tr("L'aggiornamento ", 'The update ');
String get kDeleteUpdateClosing => tr(
  " verrà eliminato definitivamente e non sarà più mostrato a chi non l'ha ancora letto.",
  " will be deleted permanently and will no longer be shown to those who haven't read it yet.",
);

String get kUpdatePublished => tr('Aggiornamento pubblicato con successo!', 'Update published!');
String get kUpdateEdited => tr('Aggiornamento modificato con successo!', 'Update edited!');
String get kUpdateDeleted => tr('Aggiornamento eliminato con successo!', 'Update deleted!');

String get kTermsRequestButton => tr('RICHIEDI NUOVA ACCETTAZIONE', 'REQUEST NEW ACCEPTANCE');
String get kTermsRequestEyebrow => tr('Nuova accettazione', 'New acceptance');
String get kTermsRequestQuestion => tr(
  'Al prossimo accesso tutti gli utenti dovranno accettare nuovamente '
      'Termini e Condizioni, Privacy Policy e Cookie Policy.',
  'At their next sign-in, every user will have to accept the '
      'Terms and Conditions, Privacy Policy and Cookie Policy again.',
);
String get kTermsRequestConfirm => tr('CONFERMA', 'CONFIRM');
String get kTermsRequestSent => tr('Nuova accettazione richiesta con successo!', 'New acceptance requested!');
