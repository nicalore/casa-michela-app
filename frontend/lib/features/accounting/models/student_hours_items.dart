import '../../people/models/person_face.dart';
import 'teacher_hours_items.dart';

enum StudentSituationKind { none, packageLeft, packageEnded, monthPaid, monthUnpaid, settle, aheadLeft, aheadEnded, pending }

StudentSituationKind _situationKind(String text)
{
  return switch (text)
  {
    'PACKAGE_LEFT' => StudentSituationKind.packageLeft,
    'PACKAGE_ENDED' => StudentSituationKind.packageEnded,
    'MONTH_PAID' => StudentSituationKind.monthPaid,
    'MONTH_UNPAID' => StudentSituationKind.monthUnpaid,
    'SETTLE' => StudentSituationKind.settle,
    'AHEAD_LEFT' => StudentSituationKind.aheadLeft,
    'AHEAD_ENDED' => StudentSituationKind.aheadEnded,
    'PENDING' => StudentSituationKind.pending,
    _ => StudentSituationKind.none,
  };
}

// Where a pupil stands right after the band, with its hours.
class StudentSituation
{
  final StudentSituationKind kind;

  // HOURLY, PACKAGE or MONTHLY; null without a tariff.
  final String? tariffKind;

  // By the hour, the package or the month, as the tariff is paid.
  final int? tariffCents;
  final int? packageHours;

  // Left of the package or of the hours paid ahead; once they ran out, those not covered.
  final int minutes;

  // The package running from this band is a renewal, already paid.
  final bool renewed;

  // What the band's hours add to what is left to settle.
  final int costCents;

  const StudentSituation({
    required this.kind,
    required this.tariffKind,
    required this.tariffCents,
    required this.packageHours,
    required this.minutes,
    required this.renewed,
    required this.costCents,
  });

  factory StudentSituation.fromJson(Map<String, dynamic> json)
  {
    return StudentSituation(
      kind: _situationKind(json['kind'] as String),
      tariffKind: json['tariff_kind'] as String?,
      tariffCents: json['tariff_cents'] as int?,
      packageHours: json['package_hours'] as int?,
      minutes: json['minutes'] as int,
      renewed: json['renewed'] as bool,
      costCents: json['cost_cents'] as int,
    );
  }

  // Teal in order, gold for what is to pay or renew.
  bool get isDue => switch (kind)
  {
    StudentSituationKind.packageEnded ||
    StudentSituationKind.monthUnpaid ||
    StudentSituationKind.settle ||
    StudentSituationKind.aheadEnded => true,
    _ => false,
  };
}

class StudentHoursRow implements PersonFace
{
  final String taxCode;

  @override
  final String firstName;

  @override
  final String lastName;

  final String mode;
  final bool absent;
  final bool added;

  // The calendar's hours; null for a row added by hand.
  final List<HoursSpan>? planned;

  final List<HoursSpan> work;
  final int minutes;
  final StudentSituation situation;

  const StudentHoursRow({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    required this.mode,
    required this.absent,
    required this.added,
    required this.planned,
    required this.work,
    required this.minutes,
    required this.situation,
  });

  factory StudentHoursRow.fromJson(Map<String, dynamic> json)
  {
    final Object? planned = json['planned'];

    return StudentHoursRow(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      mode: json['mode'] as String,
      absent: json['absent'] as bool,
      added: json['added'] as bool,
      planned: planned == null ? null : _spans(planned),
      work: _spans(json['work']),
      minutes: json['minutes'] as int,
      situation: StudentSituation.fromJson(json['situation'] as Map<String, dynamic>),
    );
  }

  @override
  String? get profileImageUrl => null;

  String get fullName => '$firstName $lastName';

  bool get isOnline => mode == kOnline;

  // Differs from the calendar's stretch at that place.
  bool changedAt(int index, {required bool end})
  {
    final List<HoursSpan>? planned = this.planned;

    if (planned == null || index >= planned.length || index >= work.length)
    {
      return false;
    }

    return end ? planned[index].end != work[index].end : planned[index].start != work[index].start;
  }

  bool get corrected
  {
    final List<HoursSpan>? planned = this.planned;

    if (absent || planned == null || planned.length != work.length)
    {
      return true;
    }

    for (var index = 0; index < planned.length; index++)
    {
      if (planned[index] != work[index])
      {
        return true;
      }
    }

    return false;
  }
}

List<HoursSpan> _spans(Object? json)
{
  return [for (final span in json as List<dynamic>) HoursSpan.fromJson(span as Map<String, dynamic>)];
}

int? _clock(Object? json) => json == null ? null : minutesOfClock(json as String);

TeacherHoursStatus _status(String text)
{
  return TeacherHoursStatus.values.firstWhere((status) => status.name.toUpperCase() == text);
}

class StudentHoursBand
{
  final DateTime date;
  final TeacherHoursStatus status;
  final List<StudentHoursRow> rows;

  // Pupils whose last lesson is still to end.
  final List<String> waiting;
  final Set<String> waitingTaxCodes;

  final int? firstEnd;
  final int? lastEnd;

  // Today only: when the next row comes in.
  final int? nextArrival;

  final bool reopened;

  const StudentHoursBand({
    required this.date,
    required this.status,
    required this.rows,
    required this.waiting,
    this.waitingTaxCodes = const {},
    required this.firstEnd,
    required this.lastEnd,
    required this.nextArrival,
    required this.reopened,
  });

  factory StudentHoursBand.fromJson(Map<String, dynamic> json)
  {
    return StudentHoursBand(
      date: DateTime.parse(json['date'] as String),
      status: _status(json['status'] as String),
      rows: [
        for (final row in json['rows'] as List<dynamic>) StudentHoursRow.fromJson(row as Map<String, dynamic>),
      ]..sort(compareByName),
      waiting: [for (final name in json['waiting'] as List<dynamic>) name as String],
      waitingTaxCodes: {for (final code in json['waiting_tax_codes'] as List<dynamic>? ?? const []) code as String},
      firstEnd: _clock(json['first_end']),
      lastEnd: _clock(json['last_end']),
      nextArrival: _clock(json['next_arrival']),
      reopened: json['reopened'] as bool,
    );
  }

  bool get isConfirmed => status == TeacherHoursStatus.confirmed;
}
