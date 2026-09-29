const String kPickDayLabel = 'Scegli il giorno';

class DayMarks
{
  // Shut in both modes.
  final Set<DateTime> closed;

  // With a lesson of the viewer's.
  final Set<DateTime> busy;

  const DayMarks({this.closed = const {}, this.busy = const {}});

  static const DayMarks none = DayMarks();
}

// Called with the first and last day of the month shown.
typedef DayMarksLoader = Future<DayMarks> Function(DateTime from, DateTime to);
