import 'notification_item.dart';

const String kNotificationsEyebrow = 'Cose da fare';
const String kNotificationsTitle = 'Attività e notifiche';

String notificationsNewLabel(int count) => count == 1 ? '1 nuova' : '$count nuove';

const String kNotificationsEmpty = 'Nessuna notifica.';
const String kNotificationsUnavailable = 'Le notifiche non sono disponibili.';
const String kNotificationsYesterday = 'Ieri';

// The card's row while they are off.
const String kNotificationsOffTitle = 'Le notifiche sono spente';
const String kNotificationsOffDesktop = 'Attivale per ricevere gli avvisi.';
const String kNotificationsOffMobile = 'Attivale per ricevere gli avvisi.';
const String kNotificationsTurnOn = 'Attiva';
const String kNotificationsBlockedWeb = 'Il browser ha bloccato le notifiche.';
const String kNotificationsBlockedMobile = 'Puoi riattivarle dalle impostazioni del telefono.';

const String kNotificationsOfferEyebrow = 'Notifiche';
const String kNotificationsOfferTitle = 'Vuoi ricevere le notifiche?';
const String kNotificationsOfferMessage =
    'Ti avviseremo quando succede qualcosa di importante, come la pubblicazione delle lezioni '
    'o una variazione degli orari di apertura. Puoi cambiare idea in qualsiasi momento dalle impostazioni.';
const String kNotificationsNotNow = 'Non ora';

// Settings.
const String kNotificationsSettingTitle = 'Notifiche';
const String kNotificationsSettingHint = 'Gli avvisi di Casa Michela su questo dispositivo.';
const String kNotificationsOn = 'Attive';
const String kNotificationsOff = 'Disattive';
const String kNotificationsBlocked = 'Bloccate';
const String kNotificationsUnsupported = 'Questo browser non può ricevere notifiche.';

const String kNotificationKindsTitle = 'Tipi di notifica';
const String kNotificationKindsChoose = 'Scegli';
const String kNotificationKindsTurnOnFirst = 'Attiva le notifiche per scegliere quali visualizzare.';
const String kNotificationKindsHint = 'Scegli quali notifiche vuoi ricevere. Vale per tutti i tuoi dispositivi.';
const String kNotificationKindsConfirm = 'Conferma';

// Draft.
String notificationKindsCount(int on, int all) => on == 1 ? '1 attivo su $all' : '$on attivi su $all';

// Each kind's switch, title and line; every kind but the test one needs its own.
const Map<NotificationKind, (String, String)> kNotificationKindLabels = {
  NotificationKind.bookingsClosed: (
    'Chiusura delle prenotazioni',
    'Avvisa quando è possibile pubblicare il calendario delle lezioni.',
  ),
  NotificationKind.calendarPublished: (
    'Calendario delle lezioni',
    'Avvisa quando il calendario delle lezioni prenotate è disponibile.',
  ),
  NotificationKind.convocation: (
    'Convocazioni',
    'Avvisa se sei stato convocato quando viene pubblicato il calendario.',
  ),
  NotificationKind.arrivalReminder: (
    'Braccialetto e timbratura',
    "Ricorda il braccialetto e la timbratura mezz'ora prima della convocazione in presenza.",
  ),
  NotificationKind.availabilityOpened: (
    'Disponibilità della settimana',
    'Avvisa il venerdì alle 20 quando si possono inserire le disponibilità per la settimana prossima.',
  ),
  NotificationKind.bookingsOpened: (
    'Prenotazioni della settimana',
    'Avvisa il venerdì alle 20 quando si possono prenotare le lezioni per la settimana prossima.',
  ),
  NotificationKind.availabilityReminder: (
    'Promemoria delle disponibilità',
    'Avvisa alle 19 se non hai dato disponibilità per il giorno dopo.',
  ),
  NotificationKind.bookingReminder: (
    'Promemoria delle prenotazioni',
    'Avvisa alle 19 se non hai prenotato lezioni per il giorno dopo.',
  ),
  NotificationKind.openingHoursChanged: (
    'Orari di apertura',
    'Avvisa quando cambiano gli orari di apertura.',
  ),
  NotificationKind.noticeReceived: (
    'Comunicazioni',
    'Avvisa quando arriva una nuova comunicazione.',
  ),
  NotificationKind.bookingAdded: (
    'Nuove prenotazioni',
    'Avvisa quando qualcun altro prenota una nuova lezione.',
  ),
  NotificationKind.bookingCancelled: (
    'Prenotazioni cancellate',
    'Avvisa quando qualcun altro cancella una lezione prenotata.',
  ),
  NotificationKind.bookingChanged: (
    'Prenotazioni modificate',
    'Avvisa quando qualcun altro modifica una lezione prenotata.',
  ),
  NotificationKind.availabilityAdded: (
    'Nuove disponibilità',
    'Avvisa quando qualcun altro inserisce una tua disponibilità.',
  ),
  NotificationKind.availabilityChanged: (
    'Disponibilità modificate',
    'Avvisa quando qualcun altro modifica una tua disponibilità.',
  ),
  NotificationKind.availabilityCancelled: (
    'Disponibilità cancellate',
    'Avvisa quando qualcun altro cancella una tua disponibilità.',
  ),
  NotificationKind.newDevice: (
    'Nuovi accessi',
    'Avvisa quando qualcuno entra nel tuo account da un nuovo dispositivo.',
  ),
  NotificationKind.reportReceived: (
    'Segnalazioni',
    'Avvisa quando arriva una nuova segnalazione.',
  ),
  NotificationKind.ratingReminder: (
    'Valutazione docenti',
    'Avvisa di aggiornare la valutazione di un docente due settimane dopo la sua iscrizione.',
  ),
};
