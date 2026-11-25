import '../../../core/language/app_language.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/word_lists.dart';
import '../../association/models/ministry_subject_item.dart';

enum BookingRequestKind
{
  ministrySubject,
  associationSubject,
  service,
}

String bookingTitle(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects)
{
  return switch (booking.kind)
  {
    BookingRequestKind.ministrySubject => _ministrySubjectName(
        ministrySubjects,
        booking.ministrySubjectId,
      ),
    BookingRequestKind.associationSubject => booking.associationSubject?.name ?? tr('Disciplina', 'Discipline'),
    BookingRequestKind.service => booking.serviceName ?? tr('Servizio', 'Service'),
  };
}

// A discipline booked on its own, outside the pupil's subjects, has no subject: empty.
String bookingSubject(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects)
{
  return booking.kind == BookingRequestKind.associationSubject ? '' : bookingTitle(booking, ministrySubjects);
}

// The discipline a subject is booked for, even its only one or one with the subject's own name.
String? subjectDisciplineName(List<MinistrySubjectItem> subjects, int? ministrySubjectId, Iterable<int> disciplineIds)
{
  if (disciplineIds.length != 1)
  {
    return null;
  }

  for (final subject in subjects)
  {
    if (subject.id == ministrySubjectId)
    {
      for (final discipline in subject.associationSubjects)
      {
        if (discipline.id == disciplineIds.single)
        {
          return discipline.name;
        }
      }
    }
  }

  return null;
}

bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

// The discipline leads and its subject always follows, even with the same name; a discipline booked
// alone or a service has no subject.
({String heading, String? subject}) bookingHeading(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects)
{
  final String title = bookingTitle(booking, ministrySubjects);

  if (booking.kind != BookingRequestKind.ministrySubject || booking.associationSubjects.isEmpty)
  {
    return (heading: title, subject: null);
  }

  return (heading: booking.associationSubjects.map((discipline) => discipline.name).join(', '), subject: title);
}

// From the booking itself, so a discipline later unlinked from its subject still shows; older bookings may
// hold several. A name that repeats the subject's is dropped: the subject already says it.
List<String> bookingDisciplineNames(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects)
{
  if (booking.kind != BookingRequestKind.ministrySubject)
  {
    return const [];
  }

  final String subject = bookingTitle(booking, ministrySubjects);

  return [
    for (final discipline in booking.associationSubjects)
      if (!_sameName(discipline.name, subject)) discipline.name,
  ];
}

// "Algebra - Matematica" when a booking is removed: the discipline first, as on the cards.
String disciplineFirstLabel(String subject, List<String> disciplines) =>
    disciplines.isEmpty ? subject : '${disciplines.join(', ')}$kShortSeparator$subject';

String bookingRemovalName(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects) =>
    disciplineFirstLabel(bookingTitle(booking, ministrySubjects), bookingDisciplineNames(booking, ministrySubjects));

String disciplineLabel(String subject, String discipline) =>
    _sameName(subject, discipline) ? subject : '$subject - $discipline';

String _ministrySubjectName(List<MinistrySubjectItem> subjects, int? id)
{
  for (final subject in subjects)
  {
    if (subject.id == id)
    {
      return subject.name;
    }
  }

  return tr('Materia', 'Subject');
}

class BookingSummaryItem
{
  final int id;
  final int duration;

  final int? ministrySubjectId;
  final List<AssociationSubjectOption> associationSubjects;
  final AssociationSubjectOption? associationSubject;
  final String? serviceName;

  final List<String> tags;
  final String? topic;
  final String? notes;

  final List<String> preferredTeacherTaxCodes;
  final List<String> notPreferredTeacherTaxCodes;

  final DateTime updatedAt;

  const BookingSummaryItem({
    required this.id,
    required this.duration,
    this.ministrySubjectId,
    this.associationSubjects = const [],
    this.associationSubject,
    this.serviceName,
    this.tags = const [],
    this.topic,
    this.notes,
    this.preferredTeacherTaxCodes = const [],
    this.notPreferredTeacherTaxCodes = const [],
    required this.updatedAt,
  });

  Set<int> get disciplineIds => switch (kind)
  {
    BookingRequestKind.ministrySubject =>
      associationSubjects.map((subject) => subject.id).toSet(),
    BookingRequestKind.associationSubject =>
      associationSubject == null ? const <int>{} : {associationSubject!.id},
    BookingRequestKind.service => const <int>{},
  };

  BookingRequestKind get kind
  {
    if (serviceName != null)
    {
      return BookingRequestKind.service;
    }

    if (associationSubject != null)
    {
      return BookingRequestKind.associationSubject;
    }

    return BookingRequestKind.ministrySubject;
  }

  factory BookingSummaryItem.fromJson(Map<String, dynamic> json)
  {
    AssociationSubjectOption? option(Object? raw)
    {
      if (raw is! Map)
      {
        return null;
      }

      return AssociationSubjectOption.fromJson(raw.cast<String, dynamic>());
    }

    return BookingSummaryItem(
      id: json['id'] as int,
      duration: json['duration'] as int,
      ministrySubjectId: json['ministry_subject_id'] as int?,
      associationSubjects: parseList(
        json['association_subjects'],
        (e) => AssociationSubjectOption.fromJson(e),
      ),
      associationSubject: option(json['association_subject']),
      serviceName: json['service_name'] as String?,
      tags: parseStringList(json['tags']),
      topic: json['topic'] as String?,
      notes: json['notes'] as String?,
      preferredTeacherTaxCodes: parseList(
        json['preferred_teachers'],
        (e) => e['tax_code'] as String,
      ),
      notPreferredTeacherTaxCodes: parseList(
        json['not_preferred_teachers'],
        (e) => e['tax_code'] as String,
      ),
      updatedAt: parseInstant(json['updated_at'])!,
    );
  }
}
