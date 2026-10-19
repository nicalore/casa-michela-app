import '../../../core/utils/json_parsing.dart';
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
    BookingRequestKind.associationSubject => booking.associationSubject?.name ?? 'Disciplina',
    BookingRequestKind.service => booking.serviceName ?? 'Servizio',
  };
}

// Subjects divided in disciplines are booked one discipline at a time: its name, else null.
String? dividedDisciplineName(List<MinistrySubjectItem> subjects, int? ministrySubjectId, Iterable<int> disciplineIds)
{
  if (disciplineIds.length != 1)
  {
    return null;
  }

  for (final subject in subjects)
  {
    if (subject.id == ministrySubjectId && subject.associationSubjects.length > 1)
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

String disciplineLabel(String subject, String discipline) => '$subject - $discipline';

// Names the discipline too when the subject has several, as in "Storia e geografia - Storia".
String? bookingDisciplineLabel(BookingSummaryItem booking, List<MinistrySubjectItem> ministrySubjects)
{
  if (booking.kind != BookingRequestKind.ministrySubject)
  {
    return null;
  }

  final String? discipline = dividedDisciplineName(
    ministrySubjects,
    booking.ministrySubjectId,
    booking.associationSubjects.map((subject) => subject.id),
  );

  return discipline == null ? null : disciplineLabel(bookingTitle(booking, ministrySubjects), discipline);
}

String _ministrySubjectName(List<MinistrySubjectItem> subjects, int? id)
{
  for (final subject in subjects)
  {
    if (subject.id == id)
    {
      return subject.name;
    }
  }

  return 'Materia';
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
