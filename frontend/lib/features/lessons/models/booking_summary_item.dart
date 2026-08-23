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
