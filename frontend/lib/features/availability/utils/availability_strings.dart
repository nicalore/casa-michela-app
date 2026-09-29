import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/opening_window.dart';

const String kAvailabilityDeadlines =
    'Per le lezioni del mattino, è possibile aggiungere o modificare '
    'le disponibilità fino alle 20:00 del giorno precedente; '
    'per quelle del pomeriggio, fino alle 11:00 dello stesso '
    'giorno; per quelle della sera, fino alle 18:00 dello stesso giorno.';

const String kNextWeekUnlockNotice = 'La settimana prossima si sblocca venerdì alle 20:00';

const String kAvailabilityDeleted = 'Disponibilità eliminata con successo!';

String availabilitySummary(int givenDays, {required bool thisWeek})
{
  final String week = thisWeek ? 'questa settimana' : 'la settimana prossima';

  if (givenDays == 0)
  {
    return 'Non hai ancora dato disponibilità $week';
  }

  return 'Hai dato disponibilità per $givenDays ${givenDays == 1 ? 'giorno' : 'giorni'} $week';
}

String _ofBand(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => 'della mattina',
    TimeBucket.afternoon => 'del pomeriggio',
    TimeBucket.evening => 'della sera',
  };
}

// One slot, or with [band] every slot the teacher holds in it.
String availabilityDeletionWarning(DateTime day, List<AvailabilityItem> slots, {TimeBucket? band})
{
  final String when = formatAvailableDayLabel(day).toLowerCase();

  if (band != null)
  {
    return 'La tua disponibilità ${_ofBand(band)} di $when verrà eliminata definitivamente.';
  }

  final AvailabilityItem slot = slots.single;

  return "L'orario ${formatTimeRange(slot.startTime, slot.endTime)} "
      '${slot.mode == kOnlineMode ? kOnScreen : kInBuilding} di $when '
      'verrà eliminato definitivamente.';
}

const String kNewAvailabilityTitle = 'Nuova disponibilità';
const String kEditAvailabilityTitle = 'Modifica disponibilità';

const String kNotAvailable = 'Non disponibile';
const String kAssociationShut = 'Associazione chiusa';
const String kAvailabilityShut = 'Disponibilità chiuse';

const String kPickADay = 'Scegli almeno una giornata per andare avanti.';

typedef AvailabilityGuide = ({String question, String hint});

const AvailabilityGuide kOwnDaysGuide = (
  question: 'Quando?',
  hint: 'Indica le giornate in cui sei disponibile. Puoi selezionarne anche più di una.',
);

const AvailabilityGuide kOwnPresenceGuide = (
  question: 'Quando sei disponibile in presenza?',
  hint: 'Indica gli orari in cui puoi essere in Associazione per le lezioni.',
);

const AvailabilityGuide kOwnOnlineGuide = (
  question: 'Quando sei disponibile online?',
  hint: 'Indica gli orari in cui puoi fare lezione a distanza.',
);

String availabilityDaysSummary(int count, {required bool split})
{
  return split
      ? 'Le giornate scelte hanno orari di apertura diversi: gli orari verranno chiesti separatamente.'
      : 'Gli orari scelti varranno su tutte e $count le giornate.';
}

String availabilityDayRefusal(DateTime day, {required bool shut, required bool closed})
{
  final String when = formatAvailableDayLabel(day).toLowerCase();

  if (shut)
  {
    return "L'Associazione è chiusa $when.";
  }

  if (closed)
  {
    return 'Le prenotazioni di $when sono chiuse.';
  }

  return 'Hai già una disponibilità $when: aprila per cambiarne gli orari.';
}

String availabilityTakenWarning(DateTime day, String mode)
{
  return 'Hai già una disponibilità ${modeLabel(mode).toLowerCase()} '
      '${formatAvailableDayLabel(day).toLowerCase()}: aprila per cambiarne gli orari.';
}

String availabilityMissingHours({required bool editing})
{
  return editing
      ? 'Indica almeno un orario di disponibilità, oppure elimina la disponibilità dalla sua scheda.'
      : 'Indica almeno un orario di disponibilità.';
}

String availabilitySaved({required bool clearing, required bool editing, required int days})
{
  if (clearing)
  {
    return kAvailabilityDeleted;
  }

  if (editing)
  {
    return 'Disponibilità modificata con successo!';
  }

  return days == 1 ? 'Disponibilità creata con successo!' : '$days disponibilità create con successo!';
}
