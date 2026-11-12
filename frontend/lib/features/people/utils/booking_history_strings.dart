import 'package:flutter/material.dart';

import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';

const String kBookingHistorySection = 'Storico prenotazioni';

const String kBookedDaysLabel = 'Giorni prenotati';
const String kBookedHoursLabel = 'Ore prenotate';

const String kBookedByLabel = 'Prenotata da';
const String kAwaitingCalendar = 'In attesa del calendario';
const String kServiceLabel = 'Servizio';

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

  return 'Nessuna prenotazione ${name.startsWith('a') ? 'ad' : 'a'} $name';
}
