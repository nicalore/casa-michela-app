import '../../core/language/app_language.dart';

String get kPickDayLabel => tr('Scegli il giorno', 'Pick the day');
String get kTodayLabel => tr('Oggi', 'Today');

class DayMarks
{
  // Shut in both modes.
  final Set<DateTime> closed;

  // Dotted: a calendar published that day for the reader, or a notice sent.
  final Set<DateTime> busy;

  const DayMarks({this.closed = const {}, this.busy = const {}});

  static const DayMarks none = DayMarks();
}

// Called with the first and last day of the month shown.
typedef DayMarksLoader = Future<DayMarks> Function(DateTime from, DateTime to);
