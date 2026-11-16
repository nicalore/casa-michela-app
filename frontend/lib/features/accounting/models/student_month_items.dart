import '../../people/models/person_face.dart';
import '../../people/utils/payments_strings.dart'
    show hoursLineUnit, hoursText, kAheadExhaustedBadge, kExhaustedBadge, leftLabel;
import '../utils/accounting_strings.dart';
import 'teacher_month_items.dart';

export 'teacher_month_items.dart' show PendingBand;

DateTime? _date(Object? json) => json == null ? null : DateTime.parse(json as String);

enum StudentStandingKind
{
  none,
  packageLeft,
  packageEnded,
  monthPaid,
  monthUnpaid,
  settle,
  settled,
  aheadLeft,
  aheadEnded,
}

StudentStandingKind _standingKind(String text)
{
  return switch (text)
  {
    'PACKAGE_LEFT' => StudentStandingKind.packageLeft,
    'PACKAGE_ENDED' => StudentStandingKind.packageEnded,
    'MONTH_PAID' => StudentStandingKind.monthPaid,
    'MONTH_UNPAID' => StudentStandingKind.monthUnpaid,
    'SETTLE' => StudentStandingKind.settle,
    'SETTLED' => StudentStandingKind.settled,
    'AHEAD_LEFT' => StudentStandingKind.aheadLeft,
    'AHEAD_ENDED' => StudentStandingKind.aheadEnded,
    _ => StudentStandingKind.none,
  };
}

// What a situation says: its line, the one under it, a badge, and whether something is owed.
typedef StandingWords = ({String text, String? below, String? badge, bool ahead, bool due});

// Where a pupil stands: today in the month under way, at its last day once it is past.
class StudentStanding
{
  final StudentStandingKind kind;

  // Left of the package or of the hours paid ahead; once they ran out, those not covered.
  final int minutes;

  // All that is left to settle.
  final int dueCents;

  // Another package already bought, waiting for this one to end.
  final bool renewal;

  const StudentStanding({required this.kind, required this.minutes, required this.dueCents, required this.renewal});

  factory StudentStanding.fromJson(Map<String, dynamic> json)
  {
    return StudentStanding(
      kind: _standingKind(json['kind'] as String),
      minutes: json['minutes'] as int,
      dueCents: json['due_cents'] as int,
      renewal: json['renewal'] as bool,
    );
  }

  // The daily summary's words; something left to settle comes first, the state under it.
  // [month]: the summary's, whose fee a monthly tariff speaks of.
  StandingWords? wordsIn(DateTime month)
  {
    final String left = leftLabel(minutes);

    final StandingWords? said = switch (kind)
    {
      StudentStandingKind.packageLeft => (
          text: left,
          below: null,
          badge: renewal ? kRenewalBadge : null,
          ahead: false,
          due: false,
        ),
      StudentStandingKind.packageEnded => (
          text: kExhaustedBadge,
          below: minutes == 0 ? null : '${hoursText(minutes)} ${hoursLineUnit('OVER_PACKAGE', minutes)}',
          badge: null,
          ahead: false,
          due: true,
        ),
      StudentStandingKind.monthPaid => (text: monthPaidSituation(month), below: null, badge: null, ahead: false, due: false),
      StudentStandingKind.monthUnpaid => (text: monthUnpaidSituation(month), below: null, badge: null, ahead: false, due: true),
      StudentStandingKind.settle => (text: toSettleAmount(dueCents), below: null, badge: null, ahead: false, due: true),
      StudentStandingKind.settled => (text: kNothingToSettle, below: null, badge: null, ahead: false, due: false),
      StudentStandingKind.aheadLeft => (text: left, below: null, badge: kAheadBadge, ahead: true, due: false),
      StudentStandingKind.aheadEnded => (
          text: kAheadExhaustedBadge,
          below: minutes == 0 ? null : '${hoursText(minutes)} ${kToSettleSituation.toLowerCase()}',
          badge: null,
          ahead: false,
          due: true,
        ),
      StudentStandingKind.none => null,
    };

    if (said == null || said.due || dueCents == 0)
    {
      return said;
    }

    // In order with the tariff, yet hours to settle (online at the weekend, say).
    return (text: toSettleAmount(dueCents), below: said.text, badge: said.badge, ahead: said.ahead, due: true);
  }
}

// Under one tariff, what the month holds.
class TariffPart
{
  // HOURLY, PACKAGE or MONTHLY; null for lessons before any tariff.
  final String? tariffKind;
  final int? amountCents;
  final int? packageHours;

  // Only when it took over after the month's first day, or ended before its last.
  final DateTime? startsOn;
  final DateTime? endsOn;

  final int days;
  final int presenceDays;
  final int onlineDays;
  final int minutes;
  final int presenceMinutes;
  final int onlineMinutes;

  const TariffPart({
    required this.tariffKind,
    required this.amountCents,
    required this.packageHours,
    required this.startsOn,
    required this.endsOn,
    required this.days,
    required this.presenceDays,
    required this.onlineDays,
    required this.minutes,
    required this.presenceMinutes,
    required this.onlineMinutes,
  });

  factory TariffPart.fromJson(Map<String, dynamic> json)
  {
    return TariffPart(
      tariffKind: json['tariff_kind'] as String?,
      amountCents: json['amount_cents'] as int?,
      packageHours: json['package_hours'] as int?,
      startsOn: _date(json['starts_on']),
      endsOn: _date(json['ends_on']),
      days: json['days'] as int,
      presenceDays: json['presence_days'] as int,
      onlineDays: json['online_days'] as int,
      minutes: json['minutes'] as int,
      presenceMinutes: json['presence_minutes'] as int,
      onlineMinutes: json['online_minutes'] as int,
    );
  }
}

class StudentMonthRow implements PersonFace
{
  final String taxCode;

  @override
  final String firstName;

  @override
  final String lastName;

  // One per tariff of the month, in order; more than one splits the row.
  final List<TariffPart> parts;

  // Null once a later month has a day confirmed: the situation is read there.
  final StudentStanding? situation;

  const StudentMonthRow({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    required this.parts,
    required this.situation,
  });

  factory StudentMonthRow.fromJson(Map<String, dynamic> json)
  {
    return StudentMonthRow(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      parts: [
        for (final part in json['parts'] as List<dynamic>) TariffPart.fromJson(part as Map<String, dynamic>),
      ],
      situation: switch (json['situation'])
      {
        final Map<String, dynamic> standing => StudentStanding.fromJson(standing),
        _ => null,
      },
    );
  }

  @override
  String? get profileImageUrl => null;

  String get fullName => '$firstName $lastName';

  // A tariff's dates show only beside another tariff.
  bool get split => parts.length > 1;
}

class StudentMonth
{
  final DateTime month;
  final List<StudentMonthRow> rows;

  // Over and still to confirm, in time order.
  final List<PendingBand> pending;

  final bool finished;

  // The month's last day once it is past; null for today's situations.
  final DateTime? situationOn;

  // False once a day of a later month is confirmed: no situation column any more.
  final bool situationShown;

  const StudentMonth({
    required this.month,
    required this.rows,
    required this.pending,
    required this.finished,
    required this.situationOn,
    required this.situationShown,
  });

  factory StudentMonth.fromJson(Map<String, dynamic> json)
  {
    return StudentMonth(
      month: DateTime.parse(json['month'] as String),
      rows: [
        for (final row in json['rows'] as List<dynamic>) StudentMonthRow.fromJson(row as Map<String, dynamic>),
      ],
      pending: [
        for (final band in json['pending'] as List<dynamic>) PendingBand.fromJson(band as Map<String, dynamic>),
      ],
      finished: json['finished'] as bool,
      situationOn: _date(json['situation_on']),
      situationShown: json['situation_shown'] as bool,
    );
  }
}
