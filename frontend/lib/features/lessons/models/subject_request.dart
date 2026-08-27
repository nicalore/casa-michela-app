import 'booking_summary_item.dart';

class SubjectRequestDraft
{
  BookingRequestKind kind;

  // Ministry-subject kind only; empty for the other two kinds.
  int? ministrySubjectId;
  Set<int> associationSubjectIds;

  // Standalone-discipline kind only. Name kept beside the id: the card
  // showing it has no catalogue at hand.
  int? associationSubjectId;
  String? associationSubjectName;

  // Service kind only: the name is also the key.
  String? serviceName;

  int? duration;

  // Meaningless on a service.
  List<String> tags;

  // Preferences, not constraints: the timetable decides who actually teaches.
  List<String> preferredTeacherTaxCodes;

  // Also a preference (go-to-last), not a veto.
  List<String> excludedTeacherTaxCodes;

  // Meaningless on a service.
  String topic;

  String notes;

  // The stored row this is, where it is one already.
  BookingSummaryItem? existing;

  SubjectRequestDraft({
    this.kind = BookingRequestKind.ministrySubject,
    this.ministrySubjectId,
    Set<int>? associationSubjectIds,
    this.associationSubjectId,
    this.associationSubjectName,
    this.serviceName,
    this.duration,
    List<String>? tags,
    List<String>? preferredTeacherTaxCodes,
    List<String>? excludedTeacherTaxCodes,
    this.topic = '',
    this.notes = '',
    this.existing,
  })  : tags = tags ?? <String>[],
        associationSubjectIds = associationSubjectIds ?? <int>{},
        preferredTeacherTaxCodes = preferredTeacherTaxCodes ?? <String>[],
        excludedTeacherTaxCodes = excludedTeacherTaxCodes ?? <String>[];

  // Copies every stored field: edits write back what they were handed, so a
  // partial draft would lose the rest. [ministrySubjectName] is the caller's to resolve.
  factory SubjectRequestDraft.fromBooking(
    BookingSummaryItem booking, {
    String? ministrySubjectName,
  })
  {
    return SubjectRequestDraft(
      kind: booking.kind,
      ministrySubjectId: booking.ministrySubjectId,
      associationSubjectIds:
          booking.associationSubjects.map((subject) => subject.id).toSet(),
      associationSubjectId: booking.associationSubject?.id,
      associationSubjectName: booking.associationSubject?.name,
      serviceName: booking.serviceName,
      duration: booking.duration,
      tags: [...booking.tags],
      preferredTeacherTaxCodes: [...booking.preferredTeacherTaxCodes],
      excludedTeacherTaxCodes: [...booking.notPreferredTeacherTaxCodes],
      topic: booking.topic ?? '',
      notes: booking.notes ?? '',
      existing: booking,
    )..ministrySubjectName = ministrySubjectName;
  }

  // Max teachers a pupil may name on either side of one subject.
  static const int maxPreferredTeachers = 3;

  bool get asksForDisciplines => kind == BookingRequestKind.ministrySubject;
  bool get asksForTopicAndTag => kind != BookingRequestKind.service;

  // A service has no disciplines, so it counts against no daily ceiling.
  Set<int> get disciplineIds => switch (kind)
  {
    BookingRequestKind.ministrySubject => {...associationSubjectIds},
    BookingRequestKind.associationSubject =>
      associationSubjectId == null ? const <int>{} : {associationSubjectId!},
    BookingRequestKind.service => const <int>{},
  };

  bool get isComplete
  {
    if (duration == null)
    {
      return false;
    }

    return switch (kind)
    {
      BookingRequestKind.ministrySubject =>
        ministrySubjectId != null && associationSubjectIds.isNotEmpty,
      BookingRequestKind.associationSubject => associationSubjectId != null,
      BookingRequestKind.service => serviceName != null,
    };
  }

  // Only known if the builder provided it; used for display without a catalogue.
  String? ministrySubjectName;

  String get displayName => switch (kind)
  {
    BookingRequestKind.ministrySubject => ministrySubjectName ?? 'Materia',
    BookingRequestKind.associationSubject => associationSubjectName ?? 'Disciplina',
    BookingRequestKind.service => serviceName ?? 'Servizio',
  };

  SubjectRequestDraft copy()
  {
    return SubjectRequestDraft(
      kind: kind,
      ministrySubjectId: ministrySubjectId,
      associationSubjectIds: {...associationSubjectIds},
      associationSubjectId: associationSubjectId,
      associationSubjectName: associationSubjectName,
      serviceName: serviceName,
      duration: duration,
      tags: [...tags],
      preferredTeacherTaxCodes: [...preferredTeacherTaxCodes],
      excludedTeacherTaxCodes: [...excludedTeacherTaxCodes],
      topic: topic,
      notes: notes,
      existing: existing,
    )..ministrySubjectName = ministrySubjectName;
  }

  Map<String, dynamic> toJson()
  {
    return {
      'duration': duration,
      if (kind == BookingRequestKind.ministrySubject) ...{
        'ministry_subject_id': ministrySubjectId,
        'association_subject_ids': associationSubjectIds.toList(),
      },
      if (kind == BookingRequestKind.associationSubject)
        'association_subject_id': associationSubjectId,
      if (kind == BookingRequestKind.service) 'service_name': serviceName,
      if (asksForTopicAndTag) ...{
        'tags': tags,
        if (topic.isNotEmpty) 'topic': topic,
      },
      if (notes.isNotEmpty) 'notes': notes,
      'preferred_teacher_tax_codes': preferredTeacherTaxCodes,
      'not_preferred_teacher_tax_codes': excludedTeacherTaxCodes,
    };
  }
}
