import 'booking_summary_item.dart';

/// One thing a pupil asks for: what, how long, and — where it makes sense —
/// who they would like to be taught it by, what it is about and anything the
/// teacher should know before the lesson.
///
/// It is a booking before it has been written, and the shape the window that
/// asks for one works on. The wizard holds a list of these per way of being
/// there; the card that opens off a day edits one at a time.
///
/// Three kinds live in here, and what is worth asking changes with the kind: a
/// ministry subject has disciplines under it, a discipline asked on its own has
/// none, and a service has neither those nor a topic nor a tag — "metodo di
/// studio" is the thing itself, not a lesson about something.
class SubjectRequestDraft
{
  BookingRequestKind kind;

  // For a ministry subject: the subject and the disciplines chosen under it.
  // Empty for the other two kinds.
  int? ministrySubjectId;
  Set<int> associationSubjectIds;

  // For a discipline asked for on its own: which one. The name is kept next to
  // the id because the card showing it has no catalogue at hand.
  int? associationSubjectId;
  String? associationSubjectName;

  // For a service: its name, which is also its key.
  String? serviceName;

  int? duration;

  // The kind of hour — oral test, homework, study. More than one, or none: an
  // hour is often two things at once. Meaningless on a service.
  List<String> tags;

  /// Who the pupil would rather be taught by, at most three. A preference and
  /// not a booking: who actually teaches the hour is decided when the timetable
  /// is put together, out of the teachers who offered that day.
  List<String> preferredTeacherTaxCodes;

  /// And who they would rather not. Also at most three, and also a preference:
  /// it says who the hour should go to last, not who is forbidden it — an
  /// association with two teachers of a subject cannot honour a veto.
  List<String> excludedTeacherTaxCodes;

  // What the lesson is about, in the pupil's own words. Optional, and
  // meaningless on a service.
  String topic;

  /// Anything else the teacher should know before the hour starts. Optional.
  String notes;

  /// The stored row this is, where it is one already.
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

  /// Everything a stored row holds, and not only what a summary shows.
  ///
  /// Whoever edits a booking writes back whatever they were handed, so a draft
  /// built out of half a booking is a booking about to lose the other half —
  /// its kind, the hours it is made of, what it is about, who was asked for.
  /// [ministrySubjectName] is the caller's to resolve: the catalogue is theirs.
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

  /// The most teachers a pupil may name on either side of one subject. More
  /// than three is not a preference any more, it is the whole staff in order.
  static const int maxPreferredTeachers = 3;

  // A service has neither topic nor tags, and no kind other than the ministry
  // subject has disciplines to list.
  bool get asksForDisciplines => kind == BookingRequestKind.ministrySubject;
  bool get asksForTopicAndTag => kind != BookingRequestKind.service;

  /// The disciplines this hour is spent on, whichever way it was asked for: the
  /// ones chosen under a ministry subject, or the single one asked on its own. A
  /// service is spent on none — it is not a lesson about a subject — so it
  /// counts against no discipline's daily ceiling.
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

  // The ministry subject's name, which the draft only knows if whoever built it
  // said so: it is what calls it by name in a list, with no catalogue at hand.
  String? ministrySubjectName;

  // What to call it in a list, whichever of the three kinds it is.
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

  // What the backend expects for this request, inside its mode's block.
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
