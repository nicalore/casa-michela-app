import '../../../../core/utils/week_range.dart';

// The founding date; nothing in the calendar predates it.
final DateTime kAssociationFoundedOn = DateTime(2023, 1, 9);

// Older days are deleted, so no calendar reaches back further than a year.
DateTime oldestKeptDay([DateTime? now])
{
  final today = now ?? DateTime.now();
  final yearBack = DateTime(today.year - 1, today.month, today.day);

  return yearBack.isBefore(kAssociationFoundedOn) ? kAssociationFoundedOn : yearBack;
}

// The month the yearly generation runs, producing the whole following year.
const int _generationMonth = DateTime.december;

// Normally 31 December of the current year; from 1 December the next year
// opens up, when the generation script materialises it.
DateTime calendarHorizon([DateTime? now])
{
  final today = now ?? DateTime.now();
  final year = today.month >= _generationMonth ? today.year + 1 : today.year;

  return DateTime(year, 12, 31);
}

bool isOldestKeptWeek(DateTime weekStart, [DateTime? now])
{
  return !weekStart.isAfter(startOfWeek(oldestKeptDay(now)));
}

bool isLastCalendarWeek(DateTime weekStart, [DateTime? now])
{
  return addDays(weekStart, 7).isAfter(calendarHorizon(now));
}

const String kBeforeFoundationError =
    'La data non può essere precedente al 09/01/2023, data di nascita dell\'associazione.';

String beyondHorizonError(DateTime horizon) =>
    'La data non può essere successiva al 31/12/${horizon.year}: gli orari del prossimo anno si '
        'potranno impostare da dicembre.';
