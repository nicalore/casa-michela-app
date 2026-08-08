import '../../../core/utils/json_parsing.dart';
import '../../association/models/ministry_subject_item.dart';

// How an hour is asked for: a ministry subject with its disciplines, a
// discipline on its own, or a service.
//
// The three are not variants of the same question — what makes sense to ask
// changes — and whoever shows or edits them has to tell them apart without
// guessing from which field is filled.
enum BookingRequestKind
{
  ministrySubject,
  associationSubject,
  service,
}

// Reuses AssociationSubjectOption from the association feature rather than
// declaring a duplicate: same shape (id, name), same backend schema.
class BookingSummaryItem
{
  final int id;
  final int duration;

  // Filled according to the kind: the first two for a ministry subject, the
  // third for a lone discipline, the last for a service.
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

  /// The disciplines this hour is spent on, whichever way it was asked for. A
  /// service is spent on none: it is not a lesson about a subject.
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
      // A list of strings and not of objects: parseList casts every element to
      // a Map before even handing it over, which breaks on a tag. It went
      // unnoticed while no booking really carried tags.
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
