import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/show_more_button.dart';
import 'notification_item.dart';

String get kNotificationsEyebrow => tr('Cose da fare', 'To do');
String get kNotificationsTitle => tr('Attività e notifiche', 'Activity & notifications');

String notificationsNewLabel(int count) => count == 1 ? tr('1 nuova', '1 new') : tr('$count nuove', '$count new');

String get kNotificationsEmpty => tr('Nessuna notifica.', 'No notifications.');

// Where the page scrolls the card shows the newest few and lengthens in place.
String get kNotificationsShowAll => kShowAllLabel;
String get kNotificationsShowFewer => kShowFewerLabel;
String get kNotificationsUnavailable => tr('Le notifiche non sono disponibili.', 'Notifications are unavailable.');
String get kNotificationsYesterday => tr('Ieri', 'Yesterday');

// The two buttons of each notification.
String get kNotificationMarkRead => tr('Segna come letta', 'Mark as read');
String get kNotificationMarkUnread => tr('Segna come da leggere', 'Mark as unread');
String get kNotificationDelete => tr('Elimina', 'Delete');

// The card's row while they are off.
String get kNotificationsOffTitle => tr('Le notifiche sono spente', 'Notifications are off');
String get kNotificationsOffDesktop => tr('Attivale per ricevere gli avvisi.', 'Turn them on to get alerts.');
String get kNotificationsOffMobile => tr('Attivale per ricevere gli avvisi.', 'Turn them on to get alerts.');
String get kNotificationsTurnOn => tr('Attiva', 'Turn on');
String get kNotificationsBlockedWeb => tr('Il browser ha bloccato le notifiche.', 'The browser has blocked notifications.');
String get kNotificationsBlockedMobile => tr('Puoi riattivarle dalle impostazioni del telefono.', 'You can turn them back on in your phone settings.');

String get kNotificationsOfferEyebrow => tr('Notifiche', 'Notifications');
String get kNotificationsOfferTitle => tr('Vuoi ricevere le notifiche?', 'Would you like to get notifications?');
String get kNotificationsOfferMessage => tr(
    'Ti avviseremo quando succede qualcosa di importante, come la pubblicazione delle lezioni '
    'o una variazione degli orari di apertura. Puoi cambiare idea in qualsiasi momento dalle impostazioni.',
    "We'll let you know when something important happens, such as lessons being published "
    'or a change to the opening hours. You can change your mind at any time in the settings.',
);
String get kNotificationsNotNow => tr('Non ora', 'Not now');

String get kNotificationsSettingTitle => tr('Notifiche', 'Notifications');
String get kNotificationsSettingHint => tr('Gli avvisi di Casa Michela su questo dispositivo.', 'Casa Michela alerts on this device.');
String get kNotificationsOn => tr('Attive', 'On');
String get kNotificationsOff => tr('Disattive', 'Off');
String get kNotificationsBlocked => tr('Bloccate', 'Blocked');
String get kNotificationsUnsupported => tr('Questo browser non può ricevere notifiche.', "This browser can't receive notifications.");

String get kNotificationKindsTitle => tr('Tipi di notifica', 'Notification types');
String get kNotificationKindsChoose => tr('Scegli', 'Choose');
String get kNotificationKindsTurnOnFirst => tr('Attiva le notifiche per scegliere quali visualizzare.', 'Turn on notifications to choose which ones to see.');
String get kNotificationKindsHint => tr('Scegli quali notifiche vuoi ricevere. Vale per tutti i tuoi dispositivi.', 'Choose which notifications you want to get. This applies to all your devices.');
String get kNotificationKindsConfirm => tr('Conferma', 'Confirm');

String notificationKindsCount(int on, int all) => on == 1 ? tr('1 attivo su $all', '1 of $all on') : tr('$on attivi su $all', '$on of $all on');

// Each kind's switch, title and line; every kind but the test one needs its own.
Map<NotificationKind, (String, String)> get kNotificationKindLabels => {
  NotificationKind.bookingsClosed: (
    tr('Chiusura delle prenotazioni', 'Bookings closed'),
    tr('Avvisa quando è possibile pubblicare il calendario delle lezioni.', 'Alerts you when the lesson calendar can be published.'),
  ),
  NotificationKind.calendarPublished: (
    tr('Calendario delle lezioni', 'Lesson calendar'),
    tr('Avvisa quando il calendario delle lezioni prenotate è disponibile.', 'Alerts you when the calendar of booked lessons is available.'),
  ),
  NotificationKind.convocation: (
    tr('Convocazioni', 'Call-ins'),
    tr('Avvisa se sei stato convocato quando viene pubblicato il calendario.', 'Alerts you if you have been called in when the calendar is published.'),
  ),
  NotificationKind.arrivalReminder: (
    tr('Braccialetto e timbratura', 'Wristband and clock-in'),
    tr("Ricorda il braccialetto e la timbratura mezz'ora prima della convocazione in presenza.", 'Reminds you about the wristband and clocking in half an hour before an in-person call-in.'),
  ),
  NotificationKind.availabilityOpened: (
    tr('Disponibilità della settimana', 'Weekly availability'),
    tr('Avvisa il venerdì alle 20:00 quando si possono inserire le disponibilità per la settimana successiva.', 'Alerts you on Friday at 20:00 when availability for the following week can be entered.'),
  ),
  NotificationKind.bookingsOpened: (
    tr('Prenotazioni della settimana', 'Weekly bookings'),
    tr('Avvisa il venerdì alle 20:00 quando si possono prenotare le lezioni per la settimana successiva.', 'Alerts you on Friday at 20:00 when lessons for the following week can be booked.'),
  ),
  NotificationKind.availabilityReminder: (
    tr('Promemoria delle disponibilità', 'Availability reminder'),
    tr('Avvisa alle 19:00 se non hai dato disponibilità per il giorno dopo.', "Alerts you at 19:00 if you haven't given availability for the next day."),
  ),
  NotificationKind.bookingReminder: (
    tr('Promemoria delle prenotazioni', 'Booking reminder'),
    tr('Avvisa alle 19:00 se non hai prenotato lezioni per il giorno dopo.', "Alerts you at 19:00 if you haven't booked lessons for the next day."),
  ),
  NotificationKind.openingHoursChanged: (
    tr('Orari di apertura', 'Opening hours'),
    tr('Avvisa quando cambiano gli orari di apertura.', 'Alerts you when the opening hours change.'),
  ),
  NotificationKind.noticeReceived: (
    tr('Comunicazioni', 'Announcements'),
    tr('Avvisa quando arriva una nuova comunicazione.', 'Alerts you when a new announcement arrives.'),
  ),
  NotificationKind.bookingAdded: (
    tr('Nuove prenotazioni', 'New bookings'),
    tr('Avvisa quando qualcun altro prenota una nuova lezione.', 'Alerts you when someone else books a new lesson.'),
  ),
  NotificationKind.bookingCancelled: (
    tr('Prenotazioni cancellate', 'Cancelled bookings'),
    tr('Avvisa quando qualcun altro cancella una lezione prenotata.', 'Alerts you when someone else cancels a booked lesson.'),
  ),
  NotificationKind.bookingChanged: (
    tr('Prenotazioni modificate', 'Changed bookings'),
    tr('Avvisa quando qualcun altro modifica una lezione prenotata.', 'Alerts you when someone else changes a booked lesson.'),
  ),
  NotificationKind.availabilityAdded: (
    tr('Nuove disponibilità', 'New availability'),
    tr('Avvisa quando qualcun altro inserisce una tua disponibilità.', 'Alerts you when someone else enters availability for you.'),
  ),
  NotificationKind.availabilityChanged: (
    tr('Disponibilità modificate', 'Changed availability'),
    tr('Avvisa quando qualcun altro modifica una tua disponibilità.', 'Alerts you when someone else changes your availability.'),
  ),
  NotificationKind.availabilityCancelled: (
    tr('Disponibilità cancellate', 'Cancelled availability'),
    tr('Avvisa quando qualcun altro cancella una tua disponibilità.', 'Alerts you when someone else cancels your availability.'),
  ),
  NotificationKind.newDevice: (
    tr('Nuovi accessi', 'New sign-ins'),
    tr('Avvisa quando un nuovo dispositivo effettua l\'accesso al tuo account.', 'Alerts you when a new device signs in to your account.'),
  ),
  NotificationKind.reportReceived: (
    tr('Segnalazioni', 'Reports'),
    tr('Avvisa quando arriva una nuova segnalazione.', 'Alerts you when a new report arrives.'),
  ),
  NotificationKind.ratingReminder: (
    tr('Valutazione docenti', 'Teacher rating'),
    tr('Avvisa di aggiornare la valutazione di un docente due settimane dopo la sua iscrizione.', "Reminds you to update a teacher's rating two weeks after they enrol."),
  ),
  NotificationKind.teacherNoteAdded: (
    tr('Osservazioni dei docenti', "Teachers' observations"),
    tr('Avvisa quando un docente inserisce una nuova osservazione per uno studente.', 'Alerts you when a teacher adds a new observation about a student.'),
  ),
  NotificationKind.administratorNoteAdded: (
    tr('Osservazioni degli amministratori', "Administrators' observations"),
    tr('Avvisa quando un amministratore inserisce una nuova osservazione che ti riguarda.', 'Alerts you when an administrator adds a new observation about you.'),
  ),
  NotificationKind.volunteeringChanged: (
    tr('Volontariato', 'Volunteering'),
    tr('Avvisa quando cambia il numero di ore di volontariato che ti sono state assegnate.', 'Alerts you when the number of volunteering hours assigned to you changes.'),
  ),
  NotificationKind.paymentReceiptAvailable: (
    tr('Ricevuta bonifico', 'Transfer receipt'),
    tr('Avvisa quando è disponibile la ricevuta di un pagamento.', 'Alerts you when a payment receipt is available.'),
  ),
};

// The convocation line agrees with the reader.
(String, String)? notificationKindLabel(NotificationKind kind)
{
  final (String, String)? labels = kNotificationKindLabels[kind];

  if (labels != null && kind == NotificationKind.convocation && ApiService().lastKnownIdentity?.gender == 'F')
  {
    return (
      labels.$1,
      tr(
        'Avvisa se sei stata convocata quando viene pubblicato il calendario.',
        'Alerts you if you have been called in when the calendar is published.',
      ),
    );
  }

  return labels;
}
