import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';

String get kBookingHistorySection => tr('Storico prenotazioni', 'Booking history');

String get kBookedDaysLabel => tr('Giorni prenotati', 'Days booked');
String get kBookedHoursLabel => tr('Ore prenotate', 'Hours booked');

String get kBookedByLabel => tr('Prenotata da', 'Booked by');
String get kAwaitingCalendar => tr('In attesa del calendario', 'Waiting for the calendar');
String get kServiceLabel => tr('Servizio', 'Service');

// "6 nov, 21:14", in Rome's time.
String bookedAtText(DateTime instant)
{
  final DateTime at = romeWallTime(instant);

  return '${formatDayMonthShort(at)}, ${formatTimeOfDayShort(TimeOfDay.fromDateTime(at))}';
}

// "ad agosto", "a ottobre".
String noBookingsMessage(DateTime month)
{
  final String name = formatMonthName(month);

  return tr('Nessuna prenotazione ${name.startsWith('a') ? 'ad' : 'a'} $name', 'No bookings in $name');
}
