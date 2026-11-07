import '../../../core/utils/alphabetical_order.dart';
import '../../association/models/ministry_subject_item.dart';
import '../models/activity_item.dart';
import '../models/booking_summary_item.dart';
import '../models/lesson_item.dart';
import '../models/person_option_item.dart';
import '../models/schedulable_booking.dart';

// The calendar's search: every word typed is found among the pupils, the teacher, the
// materie and the disciplines of one lesson or request; case, accents and spaces do not count.
class CalendarSearch
{
  final List<String> _terms;

  final Map<int, String> _subjectNames;

  const CalendarSearch._(this._terms, this._subjectNames);

  // Null while nothing is typed: the calendar is drawn as usual.
  static CalendarSearch? of(String query, List<MinistrySubjectItem> ministrySubjects)
  {
    final terms = [
      for (final word in query.split(RegExp(r'\s+')))
        if (plainForSearch(word) case final plain when plain.isNotEmpty) plain,
    ];

    if (terms.isEmpty)
    {
      return null;
    }

    return CalendarSearch._(terms, {for (final subject in ministrySubjects) subject.id: subject.name});
  }

  bool _finds(Iterable<String> names)
  {
    final plain = [for (final name in names) plainForSearch(name)];

    return _terms.every((term) => plain.any((name) => name.contains(term)));
  }

  List<String> _bookingNames(BookingSummaryItem booking)
  {
    return [
      ?_subjectNames[booking.ministrySubjectId],
      ?booking.serviceName,
      ?booking.associationSubject?.name,
      for (final discipline in booking.associationSubjects) discipline.name,
    ];
  }

  bool findsPerson(PersonOptionItem person) => _finds([person.fullName]);

  bool findsLesson(LessonItem lesson)
  {
    return _finds([
      lesson.teacher.fullName,
      ...lesson.disciplineNames,
      for (final entry in lesson.bookings) ...[
        entry.presence.student.fullName,
        ..._bookingNames(entry.booking),
      ],
    ]);
  }

  bool findsBooking(SchedulableBooking entry)
  {
    return _finds([entry.presence.student.fullName, ..._bookingNames(entry.booking)]);
  }

  bool findsActivity(ScheduledActivity scheduled) => findsPerson(scheduled.placement.teacher);
}
