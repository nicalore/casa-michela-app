import '../../../core/language/app_language.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/opening_window.dart';

String get kAvailabilityDeadlines => tr(
  'Per le lezioni del mattino, è possibile aggiungere o modificare '
      'le disponibilità fino alle 20:00 del giorno precedente; '
      'per quelle del pomeriggio, fino alle 11:00 dello stesso '
      'giorno; per quelle della sera, fino alle 18:00 dello stesso giorno.',
  'For morning lessons, you can add or change your availability until 20:00 the day before; '
      'for afternoon ones, until 11:00 the same day; '
      'for evening ones, until 18:00 the same day.',
);

String get kNextWeekUnlockNotice => tr('La settimana prossima si sblocca venerdì alle 20:00', 'Next week unlocks on Friday at 20:00');

String get kAvailabilityDeleted => tr('Disponibilità eliminata con successo!', 'Availability deleted successfully!');

String _days(int count) => count == 1 ? tr('1 giorno', '1 day') : tr('$count giorni', '$count days');

// Presence days apart, as the home and the weekly rule count them; a day with both counts twice.
String availabilitySummary({required int presenceDays, required int onlineDays, required bool thisWeek})
{
  final String week = thisWeek ? tr('questa settimana', 'this week') : tr('la settimana prossima', 'next week');

  if (presenceDays == 0 && onlineDays == 0)
  {
    return tr('Non hai ancora dato disponibilità $week', "You haven't given any availability $week yet");
  }

  if (onlineDays == 0)
  {
    return tr(
      'Hai dato disponibilità in presenza per ${_days(presenceDays)} $week',
      "You've given in-person availability for ${_days(presenceDays)} $week",
    );
  }

  if (presenceDays == 0)
  {
    return tr(
      'Hai dato disponibilità solo online per ${_days(onlineDays)} $week',
      "You've given online-only availability for ${_days(onlineDays)} $week",
    );
  }

  return tr(
    'Hai dato disponibilità per ${_days(presenceDays)} in presenza e $onlineDays online $week',
    "You've given availability for ${_days(presenceDays)} in person and $onlineDays online $week",
  );
}

String _ofBand(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => tr('della mattina', 'morning'),
    TimeBucket.afternoon => tr('del pomeriggio', 'afternoon'),
    TimeBucket.evening => tr('della sera', 'evening'),
  };
}

// [band]: every slot the teacher holds in it; [wholeDay]: every slot of the day.
String availabilityDeletionWarning(DateTime day, List<AvailabilityItem> slots, {TimeBucket? band, bool wholeDay = false})
{
  final String when = formatAvailableDayLabel(day).toLowerCase();
  final String on = formatAvailableDayLabel(day);

  if (wholeDay)
  {
    return tr(
      'La tua disponibilità di $when verrà eliminata definitivamente.',
      'Your availability for $on will be permanently deleted.',
    );
  }

  if (band != null)
  {
    return tr(
      'La tua disponibilità ${_ofBand(band)} di $when verrà eliminata definitivamente.',
      'Your ${_ofBand(band)} availability for $on will be permanently deleted.',
    );
  }

  final AvailabilityItem slot = slots.single;
  final String hours = formatTimeRange(slot.startTime, slot.endTime);
  final bool online = slot.mode == kOnlineMode;

  return tr(
    "L'orario $hours ${online ? 'online' : 'in presenza'} di $when verrà eliminato definitivamente.",
    'The ${online ? 'online' : 'in-person'} hours $hours on $on will be permanently deleted.',
  );
}

String get kNewAvailabilityTitle => tr('Nuova disponibilità', 'New availability');
String get kEditAvailabilityTitle => tr('Modifica disponibilità', 'Edit availability');

String get kNotAvailable => tr('Non disponibile', 'Not available');
String get kAssociationShut => tr('Associazione chiusa', 'Association closed');
String get kAvailabilityShut => tr('Disponibilità chiuse', 'Availability closed');

String get kPickADay => tr('Scegli almeno una giornata per andare avanti.', 'Choose at least one day to go on.');

typedef AvailabilityGuide = ({String question, String hint});

AvailabilityGuide get kOwnDaysGuide => (
  question: tr('Quando?', 'When?'),
  hint: tr(
    'Indica le giornate in cui sei disponibile. Puoi selezionarne anche più di una.',
    "Choose the days you're available. You can pick more than one.",
  ),
);

AvailabilityGuide get kOwnPresenceGuide => (
  question: tr('Quando sei disponibile in presenza?', 'When are you available in person?'),
  hint: tr(
    'Indica gli orari in cui puoi essere in Associazione per le lezioni.',
    'Choose the hours when you can be at the Association for lessons.',
  ),
);

AvailabilityGuide get kOwnOnlineGuide => (
  question: tr('Quando sei disponibile online?', 'When are you available online?'),
  hint: tr('Indica gli orari in cui puoi fare lezione a distanza.', 'Choose the hours when you can teach remotely.'),
);

String availabilityDaysSummary(int count, {required bool split})
{
  return split
      ? tr(
          'Le giornate scelte hanno orari di apertura diversi: gli orari verranno chiesti separatamente.',
          'The chosen days have different opening hours: the hours will be asked for separately.',
        )
      : tr('Gli orari scelti varranno su tutte e $count le giornate.', 'The chosen hours will apply to all $count days.');
}

String availabilityDayRefusal(DateTime day, {required bool shut, required bool closed})
{
  final String when = formatAvailableDayLabel(day).toLowerCase();
  final String on = formatAvailableDayLabel(day);

  if (shut)
  {
    return tr("L'Associazione è chiusa $when.", 'The Association is closed on $on.');
  }

  if (closed)
  {
    return tr('Le prenotazioni di $when sono chiuse.', 'Bookings for $on are closed.');
  }

  return tr(
    'Hai già una disponibilità $when: aprila per cambiarne gli orari.',
    'You already have availability on $on: open it to change its hours.',
  );
}

String availabilityTakenWarning(DateTime day, String mode)
{
  final bool online = mode == kOnlineMode;

  return tr(
    'Hai già una disponibilità ${modeLabel(mode).toLowerCase()} '
        '${formatAvailableDayLabel(day).toLowerCase()}: aprila per cambiarne gli orari.',
    'You already have ${online ? 'online' : 'in-person'} availability on '
        '${formatAvailableDayLabel(day)}: open it to change its hours.',
  );
}

String availabilityMissingHours({required bool editing})
{
  return editing
      ? tr(
          'Indica almeno un orario di disponibilità, oppure elimina la disponibilità dalla sua scheda.',
          'Choose at least one available hour, or delete the availability from its card.',
        )
      : tr('Indica almeno un orario di disponibilità.', 'Choose at least one available hour.');
}

String availabilitySaved({required bool clearing, required bool editing, required int days})
{
  if (clearing)
  {
    return kAvailabilityDeleted;
  }

  if (editing)
  {
    return tr('Disponibilità modificata con successo!', 'Availability updated successfully!');
  }

  return days == 1
      ? tr('Disponibilità creata con successo!', 'Availability created successfully!')
      : tr('Disponibilità create con successo!', 'Availability created successfully!');
}
