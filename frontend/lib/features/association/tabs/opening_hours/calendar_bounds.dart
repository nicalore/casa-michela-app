// How far the opening-hours calendar reaches, in both directions.

/// The day the association was founded. Nothing in its calendar predates it,
/// so weeks before this cannot be browsed and hours cannot be dated earlier.
final DateTime kAssociationFoundedOn = DateTime(2023, 1, 9);

/// The month the yearly generation runs, producing the whole following year.
const int _generationMonth = DateTime.december;

/// The last date the calendar can reach.
///
/// Normally 31 December of the current year — beyond that the days simply do
/// not exist yet. From 1 December the next year opens up, because that is when
/// the generation script runs and materialises it.
DateTime calendarHorizon([DateTime? now])
{
  final today = now ?? DateTime.now();
  final year = today.month >= _generationMonth ? today.year + 1 : today.year;

  return DateTime(year, 12, 31);
}

const String kBeforeFoundationError =
    'La data non può essere precedente al 09/01/2023, data di nascita dell\'associazione.';

String beyondHorizonError(DateTime horizon) =>
    'La data non può essere successiva al 31/12/${horizon.year}: '
    'gli orari dell\'anno seguente si potranno impostare da dicembre.';
