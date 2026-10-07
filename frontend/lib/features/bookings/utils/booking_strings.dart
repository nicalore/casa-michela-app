import '../../../core/utils/time_bucket.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/opening_window.dart';

const String kBookingDeadlines =
    'Per le lezioni del mattino, è possibile prenotare o modificare '
    'le lezioni fino alle 20:00 del giorno precedente; '
    'per quelle del pomeriggio, fino alle 11:00 dello stesso '
    'giorno; per quelle della sera, fino alle 18:00 dello stesso giorno.';

const String kBookingsLoadFailed = 'Non è stato possibile caricare le prenotazioni.';
const String kNoPupils = 'Nessuno studente a tuo carico.';

const String kBookingDeleted = 'Prenotazione eliminata con successo!';
const String kLessonDeleted = 'Materia eliminata con successo!';
const String kLessonEdited = 'Materia modificata con successo!';
const String kLessonIncomplete = 'Servono la materia, almeno una disciplina e la durata.';

String _where(String mode) => mode == kOnlineMode ? kOnScreen : kInBuilding;

String _whereIn(String mode, TimeBucket? band) => band == null ? _where(mode) : '${_where(mode)} ${ofBandLabel(band)}';

String _week(bool thisWeek) => thisWeek ? 'questa settimana' : 'la settimana prossima';

String _days(int count) => '$count ${count == 1 ? 'giorno' : 'giorni'}';

String pupilBookedDays(String firstName, int booked, {required bool thisWeek})
{
  return booked == 0
      ? '$firstName non ha ancora prenotazioni ${_week(thisWeek)}.'
      : '$firstName ha ${_days(booked)} ${booked == 1 ? 'prenotato' : 'prenotati'} ${_week(thisWeek)}.';
}

String ownBookedDays(int booked, {required bool thisWeek})
{
  return booked == 0
      ? 'Non hai ancora prenotato ${_week(thisWeek)}.'
      : 'Hai prenotato ${_days(booked)} ${_week(thisWeek)}.';
}

String bookedForYouDays(int booked, {required bool thisWeek})
{
  return switch (booked)
  {
    0 => 'Non è stato prenotato nessun giorno ${_week(thisWeek)}.',
    1 => 'È stato prenotato 1 giorno ${_week(thisWeek)}.',
    _ => 'Sono stati prenotati ${_days(booked)} ${_week(thisWeek)}.',
  };
}

String modeBookingDeleted(String mode, {TimeBucket? band}) => 'Prenotazione ${_whereIn(mode, band)} eliminata con successo!';

String moveBandLessons(TimeBucket band) => 'Sposta le lezioni ${ofBandLabel(band)}';

String deleteBand(TimeBucket band) => 'Elimina ${theBandLabel(band)}';

String lessonsMoved(int count) => count == 1 ? 'Materia spostata con successo!' : 'Lezioni spostate con successo!';

String allLessonsTitle(String mode, {TimeBucket? band}) => 'Tutte le lezioni ${_whereIn(mode, band)}';

// [pupil] null: the reader's own booking.
String bookingDeletionWarning(DateTime day, {String? pupil, String? mode, TimeBucket? band})
{
  final String part = mode == null ? '' : ' ${_whereIn(mode, band)}';
  final String whose = pupil == null ? 'La tua prenotazione$part' : 'La prenotazione$part di $pupil';

  return '$whose di ${formatAvailableDayLabel(day).toLowerCase()} verrà eliminata definitivamente.';
}

// The last lesson of a band takes the band's hours with it.
String lessonDeletionWarning(String label, String mode, {required bool last, TimeBucket? band})
{
  final String where = _whereIn(mode, band);
  final String stay = '${mode == kOnlineMode ? kOnScreen : 'in Associazione'}${band == null ? '' : ' ${ofBandLabel(band)}'}';

  return last
      ? 'La materia $label verrà tolta dalla prenotazione. Era l\'unica lezione $where, '
          'quindi verrà eliminata anche la presenza $stay.'
      : 'La materia $label verrà tolta dalla prenotazione.';
}
