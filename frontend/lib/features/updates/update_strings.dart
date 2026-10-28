import '../settings/utils/settings_strings.dart';

const String kUpdatesEntry = 'Aggiornamenti';
const String kUpdatesTitle = 'Aggiornamenti';

// The x.y.z of the app in use, as an update is filed under.
final String kUpdateVersion = RegExp(r'\d+\.\d+\.\d+').firstMatch(kAppVersion)!.group(0)!;

String updateHeading(String version) => 'Nuovo aggiornamento - Versione $version';

String updateVersionLabel(String version) => 'Versione $version';

const String kUpdateSingleTitle = 'Nuovo aggiornamento';
const String kUpdatesGroupTitle = 'Nuovi aggiornamenti';

String updateCountLabel(int count) => count == 1 ? '1 aggiornamento pubblicato' : '$count aggiornamenti pubblicati';

const String kNoUpdates = 'Nessun aggiornamento pubblicato';

String updateEditedLabel(String day) => '(modificato il $day)';

const String kUpdateSentLabel = 'Data';
const String kUpdateEditedLabel = 'Modificato';
const String kUpdateAuthorLabel = 'Inviato da';
const String kUpdateRecipientsLabel = 'Destinatari';
const String kUpdateTitleLabel = 'Titolo';
const String kUpdateMessageLabel = 'Contenuto';

// Every role chosen.
const String kUpdateAllRoles = 'Tutti gli iscritti';

const String kUpdateEyebrow = 'Aggiornamento';
const String kNewUpdateTitle = 'Nuovo aggiornamento';
const String kEditUpdateTitle = 'Modifica aggiornamento';

const String kNewUpdateButton = 'NUOVO AGGIORNAMENTO';
const String kPublishUpdate = 'PUBBLICA';
const String kSaveUpdate = 'SALVA';
const String kUpdateCancel = 'ANNULLA';
const String kUpdateDelete = 'ELIMINA';
const String kUpdateEdit = 'MODIFICA';

String updatePeopleLabel(int people) => people == 1 ? '1 persona' : '$people persone';

const String kNoUpdateRecipients = 'Scegli almeno un destinatario.';
const String kNoUpdateTitle = 'Scrivi un titolo.';
const String kNoUpdateMessage = 'Scrivi il contenuto.';
const String kUpdateMessageTooLong = 'Il contenuto è troppo lungo.';
const String kUpdateImagesTooLarge = 'Le immagini superano i 15 MB totali.';

const String kPublishEyebrow = 'Pubblicazione';
const String kUpdateConfirmTitle = 'Confermi?';

// The count is set in bold between the two parts.
String publishConfirmationOpening(int people) =>
    people == 1 ? "L'aggiornamento verrà mostrato a " : "L'aggiornamento verrà mostrato alle ";

String publishConfirmationClosing(List<String> roles) =>
    '${roles.length == 1 ? ' con il seguente ruolo: ' : ' con i seguenti ruoli: '}${roles.join(', ')}.';

const String kDeleteUpdateEyebrow = 'Eliminazione';

// The title is set in bold between the two parts.
const String kDeleteUpdateOpening = "L'aggiornamento ";
const String kDeleteUpdateClosing = " verrà eliminato definitivamente e non sarà più mostrato a chi non l'ha ancora letto.";

const String kUpdatePublished = 'Aggiornamento pubblicato con successo!';
const String kUpdateEdited = 'Aggiornamento modificato con successo!';
const String kUpdateDeleted = 'Aggiornamento eliminato con successo!';

const String kTermsRequestButton = 'RICHIEDI NUOVA ACCETTAZIONE';
const String kTermsRequestEyebrow = 'Nuova accettazione';
const String kTermsRequestQuestion = 'Al prossimo accesso tutti gli utenti dovranno accettare nuovamente '
    'Termini e Condizioni, Privacy Policy e Cookie Policy.';
const String kTermsRequestConfirm = 'CONFERMA';
const String kTermsRequestSent = 'Nuova accettazione richiesta con successo!';
