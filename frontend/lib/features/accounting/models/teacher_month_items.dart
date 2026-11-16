import '../../../core/utils/money.dart';
import '../../../core/utils/time_bucket.dart';
import '../../people/models/person_face.dart';
import 'teacher_hours_items.dart';
import 'volunteering_rule.dart';

export 'volunteering_rule.dart';

int? _cents(Object? json) => json == null ? null : parseAmountCents(json.toString());

DateTime _date(Object? json) => DateTime.parse(json as String);

// The bank transfer receipt of a teacher's month, without its bytes.
class PaymentReceipt
{
  final String fileName;
  final String contentType;
  final int size;
  final DateTime uploadedAt;

  const PaymentReceipt({required this.fileName, required this.contentType, required this.size, required this.uploadedAt});

  factory PaymentReceipt.fromJson(Map<String, dynamic> json)
  {
    return PaymentReceipt(
      fileName: json['file_name'] as String,
      contentType: json['content_type'] as String,
      size: json['size'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String).toLocal(),
    );
  }

  bool get isPdf => contentType == 'application/pdf';
}

class TeacherMonthRow implements PersonFace
{
  final String taxCode;

  @override
  final String firstName;

  @override
  final String lastName;

  final String collaborationType;
  final int days;
  final int presenceDays;
  final int onlineDays;
  final int workedMinutes;
  final int volunteerMinutes;

  // Null where nothing is paid.
  final int? paidMinutes;
  final int? gross;
  final int? net;

  final int availabilities;
  final bool belowMonthly;
  final int shortWeeks;

  // How this month counts the unpaid hour, and what the teacher's Compensi say.
  final VolunteeringRule volunteering;
  final VolunteeringRule standingVolunteering;

  // Under each rule for this month alone: shown while one is picked and not saved.
  final Map<VolunteeringRule, RuleFigures>? ruleFigures;

  final PaymentReceipt? receipt;

  const TeacherMonthRow({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    required this.collaborationType,
    required this.days,
    required this.presenceDays,
    required this.onlineDays,
    required this.workedMinutes,
    required this.volunteerMinutes,
    required this.paidMinutes,
    required this.gross,
    required this.net,
    required this.availabilities,
    required this.belowMonthly,
    required this.shortWeeks,
    required this.volunteering,
    required this.standingVolunteering,
    required this.ruleFigures,
    this.receipt,
  });

  factory TeacherMonthRow.fromJson(Map<String, dynamic> json)
  {
    return TeacherMonthRow(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      collaborationType: json['collaboration_type'] as String,
      days: json['days'] as int,
      presenceDays: json['presence_days'] as int,
      onlineDays: json['online_days'] as int,
      workedMinutes: json['worked_minutes'] as int,
      volunteerMinutes: json['volunteer_minutes'] as int,
      paidMinutes: json['paid_minutes'] as int?,
      gross: _cents(json['gross']),
      net: _cents(json['net']),
      availabilities: json['availabilities'] as int,
      belowMonthly: json['below_monthly'] as bool,
      shortWeeks: json['short_weeks'] as int,
      volunteering: VolunteeringRule.fromJson(json['volunteering']),
      standingVolunteering: VolunteeringRule.fromJson(json['standing_volunteering']),
      ruleFigures: ruleFiguresOf(json['rule_figures']),
      receipt: json['receipt'] == null ? null : PaymentReceipt.fromJson(json['receipt'] as Map<String, dynamic>),
    );
  }

  // Under a rule picked and not saved yet.
  RuleFigures? figuresFor(VolunteeringRule rule) => ruleFigures?[rule];

  // Chosen in the monthly summary for this month alone, against the teacher's rule.
  bool get monthOnly => volunteering != standingVolunteering;

  @override
  String? get profileImageUrl => null;

  String get fullName => '$firstName $lastName';

  // Only a paid teacher owes the unpaid hour, so only they have a rule to choose.
  bool get isPaid => collaborationType == kPaidCollaboration;
}

class PendingBand
{
  final DateTime date;
  final TimeBucket band;

  const PendingBand(this.date, this.band);

  factory PendingBand.fromJson(Map<String, dynamic> json)
  {
    return PendingBand(_date(json['date']), TimeBucket.values.byName((json['band'] as String).toLowerCase()));
  }
}

class TeacherMonth
{
  final DateTime month;
  final List<TeacherMonthRow> rows;

  // Over and still to confirm, in time order.
  final List<PendingBand> pending;

  // Nothing left to confirm and nothing more to come before the month ends.
  final bool finished;

  const TeacherMonth({required this.month, required this.rows, required this.pending, required this.finished});

  factory TeacherMonth.fromJson(Map<String, dynamic> json)
  {
    return TeacherMonth(
      month: _date(json['month']),
      rows: [
        for (final row in json['rows'] as List<dynamic>) TeacherMonthRow.fromJson(row as Map<String, dynamic>),
      ]..sort(compareByName),
      pending: [
        for (final band in json['pending'] as List<dynamic>) PendingBand.fromJson(band as Map<String, dynamic>),
      ],
      finished: json['finished'] as bool,
    );
  }
}
