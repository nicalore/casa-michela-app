import '../../../core/utils/money.dart';
import '../../../core/utils/time_bucket.dart';
import '../../people/models/person_face.dart';

const String kPaidCollaboration = 'PAID';
const String kVolunteerCollaboration = 'VOLUNTEER';
const String kOnline = 'online';
const String kPresence = 'presence';

// "15:00:00" or "15:00", in minutes from midnight.
int minutesOfClock(String text)
{
  return int.parse(text.substring(0, 2)) * 60 + int.parse(text.substring(3, 5));
}

// 900 as "15:00".
String clockOf(int minutes)
{
  return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

String apiDate(DateTime day)
{
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

String apiBand(TimeBucket band) => band.name.toUpperCase();

class HoursSpan
{
  final int start;
  final int end;

  const HoursSpan(this.start, this.end);

  int get minutes => end - start;

  factory HoursSpan.fromJson(Map<String, dynamic> json)
  {
    return HoursSpan(minutesOfClock(json['start_time'] as String), minutesOfClock(json['end_time'] as String));
  }

  Map<String, dynamic> toJson() => {'start_time': clockOf(start), 'end_time': clockOf(end)};

  @override
  bool operator ==(Object other) => other is HoursSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

HoursSpan? _span(Object? json) => json == null ? null : HoursSpan.fromJson(json as Map<String, dynamic>);

List<HoursSpan> _spans(Object? json)
{
  return [for (final span in json as List<dynamic>) HoursSpan.fromJson(span as Map<String, dynamic>)];
}

int? _cents(Object? json) => json == null ? null : parseAmountCents(json.toString());

int? _clock(Object? json) => json == null ? null : minutesOfClock(json as String);

class TeacherHoursRow implements PersonFace
{
  final String taxCode;

  @override
  final String firstName;

  @override
  final String lastName;

  final String mode;
  final String collaborationType;
  final bool absent;
  final bool added;

  // The calendar's hours; null for a row added by hand.
  final List<HoursSpan>? planned;

  final List<HoursSpan> work;
  final HoursSpan? volunteer;
  final HoursSpan? volunteerProposed;
  final bool volunteerSet;
  final int workedMinutes;
  final int volunteerMinutes;
  final int? gross;
  final int? net;

  const TeacherHoursRow({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    required this.mode,
    required this.collaborationType,
    required this.absent,
    required this.added,
    required this.planned,
    required this.work,
    required this.volunteer,
    required this.volunteerProposed,
    required this.volunteerSet,
    required this.workedMinutes,
    required this.volunteerMinutes,
    required this.gross,
    required this.net,
  });

  factory TeacherHoursRow.fromJson(Map<String, dynamic> json)
  {
    final Object? planned = json['planned'];

    return TeacherHoursRow(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      mode: json['mode'] as String,
      collaborationType: json['collaboration_type'] as String,
      absent: json['absent'] as bool,
      added: json['added'] as bool,
      planned: planned == null ? null : _spans(planned),
      work: _spans(json['work']),
      volunteer: _span(json['volunteer']),
      volunteerProposed: _span(json['volunteer_proposed']),
      volunteerSet: json['volunteer_set'] as bool,
      workedMinutes: json['worked_minutes'] as int,
      volunteerMinutes: json['volunteer_minutes'] as int,
      gross: _cents(json['gross']),
      net: _cents(json['net']),
    );
  }

  @override
  String? get profileImageUrl => null;

  String get fullName => '$firstName $lastName';

  bool get isOnline => mode == kOnline;

  // A volunteer's hours are all volunteering: no work columns, no pay.
  bool get isVolunteer => collaborationType == kVolunteerCollaboration;

  bool get isPaid => collaborationType == kPaidCollaboration;

  // Only paid teachers in person give the weekly hour.
  bool get mayVolunteer => isPaid && !isOnline && !absent;

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

  bool volunteerChanged({required bool end})
  {
    final HoursSpan? volunteer = this.volunteer;
    final HoursSpan? proposed = volunteerProposed;

    if (!volunteerSet || volunteer == null)
    {
      return false;
    }

    if (proposed == null)
    {
      return true;
    }

    return end ? volunteer.end != proposed.end : volunteer.start != proposed.start;
  }
}

enum TeacherHoursStatus { empty, waiting, live, ready, confirmed }

TeacherHoursStatus _status(String text)
{
  return TeacherHoursStatus.values.firstWhere((status) => status.name.toUpperCase() == text);
}

class TeacherHoursBand
{
  final DateTime date;
  final TeacherHoursStatus status;
  final List<TeacherHoursRow> rows;

  // Teachers whose last lesson is still to end.
  final List<String> waiting;
  final Set<String> waitingTaxCodes;

  final int? firstEnd;
  final int? lastEnd;

  // Today only: when the next row comes in.
  final int? nextArrival;

  final bool reopened;

  const TeacherHoursBand({
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

  factory TeacherHoursBand.fromJson(Map<String, dynamic> json)
  {
    return TeacherHoursBand(
      date: DateTime.parse(json['date'] as String),
      status: _status(json['status'] as String),
      rows: [
        for (final row in json['rows'] as List<dynamic>) TeacherHoursRow.fromJson(row as Map<String, dynamic>),
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

  bool get canConfirm => status == TeacherHoursStatus.ready;
}
