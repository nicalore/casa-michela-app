const String kPickDayLabel = 'Scegli il giorno';
const String kTodayLabel = 'Oggi';

class DayMarks
{
  // Shut in both modes.
  final Set<DateTime> closed;

  // Dotted: a calendar published that day.
  final Set<DateTime> busy;

  const DayMarks({this.closed = const {}, this.busy = const {}});

  static const DayMarks none = DayMarks();
}

// Called with the first and last day of the month shown.
typedef DayMarksLoader = Future<DayMarks> Function(DateTime from, DateTime to);
