import '../../../core/language/app_language.dart';
import '../../../core/utils/time_bucket.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/opening_window.dart';

String get kBookingDeadlines => tr(
  'Per le lezioni del mattino, è possibile prenotare o modificare '
      'le lezioni fino alle 20:00 del giorno precedente; '
      'per quelle del pomeriggio, fino alle 11:00 dello stesso '
      'giorno; per quelle della sera, fino alle 18:00 dello stesso giorno.',
  'For morning lessons, you can book or change lessons until 20:00 the day before; '
      'for afternoon ones, until 11:00 the same day; '
      'for evening ones, until 18:00 the same day.',
);

String get kBookingsLoadFailed => tr('Non è stato possibile caricare le prenotazioni.', "Couldn't load the bookings.");
String get kNoPupils => tr('Nessuno studente a tuo carico.', 'No students in your care.');

String get kBookingDeleted => tr('Prenotazione eliminata con successo!', 'Booking deleted successfully!');
String get kLessonDeleted => tr('Materia eliminata con successo!', 'Subject deleted successfully!');
String get kLessonEdited => tr('Materia modificata con successo!', 'Subject updated successfully!');
String get kLessonIncomplete => tr('Servono la materia, almeno una disciplina e la durata.', 'You need the subject, at least one discipline and the duration.');

String _where(String mode) => mode == kOnlineMode ? kOnScreen : kInBuilding;

String _whereIn(String mode, TimeBucket? band) => band == null ? _where(mode) : '${_where(mode)} ${ofBandLabel(band)}';

String _week(bool thisWeek) => thisWeek ? tr('questa settimana', 'this week') : tr('la settimana prossima', 'next week');

String _days(int count) => count == 1 ? tr('1 giorno', '1 day') : tr('$count giorni', '$count days');

// "morning in-person", before a noun; English only.
String _enKind(String mode, TimeBucket? band)
{
  final String where = mode == kOnlineMode ? 'online' : 'in-person';

  return band == null ? where : '${_enBand(band)} $where';
}

String _enBand(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => 'morning',
    TimeBucket.afternoon => 'afternoon',
    TimeBucket.evening => 'evening',
  };
}

String _capitalised(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

String pupilBookedDays(String firstName, int booked, {required bool thisWeek})
{
  return booked == 0
      ? tr('$firstName non ha ancora prenotazioni ${_week(thisWeek)}.', '$firstName has no bookings ${_week(thisWeek)} yet.')
      : tr(
          '$firstName ha ${_days(booked)} ${booked == 1 ? 'prenotato' : 'prenotati'} ${_week(thisWeek)}.',
          '$firstName has ${_days(booked)} booked ${_week(thisWeek)}.',
        );
}

String ownBookedDays(int booked, {required bool thisWeek})
{
  return booked == 0
      ? tr('Non hai ancora prenotato ${_week(thisWeek)}.', "You haven't booked anything ${_week(thisWeek)} yet.")
      : tr('Hai prenotato ${_days(booked)} ${_week(thisWeek)}.', "You've booked ${_days(booked)} ${_week(thisWeek)}.");
}

String bookedForYouDays(int booked, {required bool thisWeek})
{
  return switch (booked)
  {
    0 => tr('Non è stato prenotato nessun giorno ${_week(thisWeek)}.', 'No days have been booked ${_week(thisWeek)}.'),
    1 => tr('È stato prenotato 1 giorno ${_week(thisWeek)}.', '1 day has been booked ${_week(thisWeek)}.'),
    _ => tr('Sono stati prenotati ${_days(booked)} ${_week(thisWeek)}.', '${_days(booked)} have been booked ${_week(thisWeek)}.'),
  };
}

String modeBookingDeleted(String mode, {TimeBucket? band})
{
  return tr(
    'Prenotazione ${_whereIn(mode, band)} eliminata con successo!',
    '${_capitalised(_enKind(mode, band))} booking deleted successfully!',
  );
}

String moveBandLessons(TimeBucket band) => tr('Sposta le lezioni ${ofBandLabel(band)}', 'Move the ${_enBand(band)} lessons');

String deleteBand(TimeBucket band) => tr('Elimina ${theBandLabel(band)}', 'Delete the ${_enBand(band)}');

String deleteModeBooking(String mode) => tr('Elimina la prenotazione ${_where(mode)}', 'Delete the ${_enKind(mode, null)} booking');

String addModeLabel(String mode)
{
  return mode == kOnlineMode ? tr('AGGIUNGI ONLINE', 'ADD ONLINE') : tr('AGGIUNGI IN PRESENZA', 'ADD IN PERSON');
}

String lessonsMoved(int count)
{
  return count == 1
      ? tr('Materia spostata con successo!', 'Subject moved successfully!')
      : tr('Lezioni spostate con successo!', 'Lessons moved successfully!');
}

String allLessonsTitle(String mode, {TimeBucket? band})
{
  return tr('Tutte le lezioni ${_whereIn(mode, band)}', 'All ${_enKind(mode, band)} lessons');
}

// [pupil] null: the reader's own booking.
String bookingDeletionWarning(DateTime day, {String? pupil, String? mode, TimeBucket? band})
{
  if (isEnglish)
  {
    final String kind = mode == null ? '' : '${_enKind(mode, band)} ';
    final String whose = pupil == null ? 'Your ${kind}booking' : "$pupil's ${kind}booking";

    return '$whose for ${formatAvailableDayLabel(day)} will be permanently deleted.';
  }

  final String part = mode == null ? '' : ' ${_whereIn(mode, band)}';
  final String whose = pupil == null ? 'La tua prenotazione$part' : 'La prenotazione$part di $pupil';

  return '$whose di ${formatAvailableDayLabel(day).toLowerCase()} verrà eliminata definitivamente.';
}

// [pupil] null: the reader's own booking.
String bandNoteDeletionWarning(DateTime day, {String? pupil})
{
  if (isEnglish)
  {
    final String whose = pupil == null ? 'The note on your booking' : "The note on $pupil's booking";

    return '$whose for ${formatAvailableDayLabel(day)} will be permanently deleted.';
  }

  final String whose = pupil == null ? 'La nota sulla tua prenotazione' : 'La nota sulla prenotazione di $pupil';

  return '$whose di ${formatAvailableDayLabel(day).toLowerCase()} verrà eliminata definitivamente.';
}

String lastLessonNote(String mode, {TimeBucket? band})
{
  if (isEnglish)
  {
    final String when = band == null ? '' : '${_enBand(band)} ';
    final String stay = mode == kOnlineMode ? '${when}online attendance' : '${when}attendance at the Association';

    return ' It was the only ${_enKind(mode, band)} lesson, so the $stay will be deleted too.';
  }

  final String stay = '${mode == kOnlineMode ? kOnScreen : 'in Associazione'}${band == null ? '' : ' ${ofBandLabel(band)}'}';

  return ' Era l\'unica lezione ${_whereIn(mode, band)}, quindi verrà eliminata anche la presenza $stay.';
}

// Last lesson of a band takes its hours. [divided]: [label] is "Materia - Disciplina", bold.
({String? bold, String text}) lessonDeletionWarning(String label, String mode, {required bool last, bool divided = false, TimeBucket? band})
{
  final String also = last ? lastLessonNote(mode, band: band) : '';

  return divided
      ? (bold: label, text: tr(' verrà rimossa dalla prenotazione.$also', ' will be removed from the booking.$also'))
      : (bold: null, text: tr('La materia $label verrà tolta dalla prenotazione.$also', 'The subject $label will be removed from the booking.$also'));
}
