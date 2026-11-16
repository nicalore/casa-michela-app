import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/money.dart';

// Contabilità › «Configurazione iniziale», as GET /accounting/opening/ sends it.

int? _cents(Object? json) => json == null ? null : parseAmountCents(json.toString());

class OpeningPayment
{
  final DateTime paidOn;

  // CASH, BANK_TRANSFER or OTHER.
  final String method;
  final String? methodOther;

  const OpeningPayment({required this.paidOn, required this.method, this.methodOther});

  factory OpeningPayment.fromJson(Map<String, dynamic> json)
  {
    return OpeningPayment(
      paidOn: parseDate(json['paid_on'])!,
      method: json['payment_method'] as String,
      methodOther: json['payment_method_other'] as String?,
    );
  }
}

class OpeningTeacher
{
  final String taxCode;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? profileImageUrl;
  final bool confirmed;

  // VOLUNTEER, PAID, PCTO or UNPAID, in the month the app's accounts begin.
  final String collaborationType;
  final int? grossRateCents;

  // A board member stays unpaid: nothing to choose.
  final bool canEdit;

  // The pay before the app's accounts, once confirmed.
  final int? grossCents;

  const OpeningTeacher({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.profileImageUrl,
    required this.confirmed,
    required this.collaborationType,
    this.grossRateCents,
    required this.canEdit,
    this.grossCents,
  });

  String get fullName => '$firstName $lastName';

  bool get isPaid => collaborationType == 'PAID';

  // Paid with no rate on file.
  bool get missing => isPaid && grossRateCents == null;

  factory OpeningTeacher.fromJson(Map<String, dynamic> json)
  {
    return OpeningTeacher(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      confirmed: json['confirmed'] as bool,
      collaborationType: json['collaboration_type'] as String,
      grossRateCents: _cents(json['gross_rate']),
      canEdit: json['can_edit'] as bool,
      grossCents: _cents(json['gross']),
    );
  }
}

class OpeningTariff
{
  // HOURLY, PACKAGE or MONTHLY.
  final String kind;
  final int amountCents;
  final int? packageHours;

  const OpeningTariff({required this.kind, required this.amountCents, this.packageHours});

  factory OpeningTariff.fromJson(Map<String, dynamic> json)
  {
    return OpeningTariff(
      kind: json['kind'] as String,
      amountCents: json['amount_cents'] as int,
      packageHours: json['package_hours'] as int?,
    );
  }
}

class OpeningAhead
{
  final int minutes;
  final int centsPerHour;
  final OpeningPayment payment;

  const OpeningAhead({required this.minutes, required this.centsPerHour, required this.payment});

  factory OpeningAhead.fromJson(Map<String, dynamic> json)
  {
    return OpeningAhead(
      minutes: json['minutes'] as int,
      centsPerHour: json['cents_per_hour'] as int,
      payment: OpeningPayment.fromJson(json['payment'] as Map<String, dynamic>),
    );
  }
}

class LevelStandard
{
  final int hourlyCents;
  final int? packageCents;
  final int? packageHours;
  final int? monthlyCents;

  const LevelStandard({required this.hourlyCents, this.packageCents, this.packageHours, this.monthlyCents});

  factory LevelStandard.fromJson(Map<String, dynamic> json)
  {
    return LevelStandard(
      hourlyCents: json['hourly_cents'] as int,
      packageCents: json['package_cents'] as int?,
      packageHours: json['package_hours'] as int?,
      monthlyCents: json['monthly_cents'] as int?,
    );
  }
}

class OpeningPupil
{
  final String taxCode;
  final String firstName;
  final String lastName;
  final String? gender;
  final String? profileImageUrl;
  final bool confirmed;
  final String? schoolLevel;
  final Set<String> enabledKinds;
  final LevelStandard? standard;

  // Hours beyond a package, and online at the weekend.
  final int settleCents;
  final int weekendOnlineCents;

  // In force the day before the app's accounts.
  final OpeningTariff? tariff;

  // What the confirmed set-up said.
  final OpeningPayment? payment;
  final bool packageEnded;
  final int leftMinutes;
  final int dueMinutes;
  final OpeningAhead? ahead;
  final int weekendMinutes;

  const OpeningPupil({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.profileImageUrl,
    required this.confirmed,
    this.schoolLevel,
    required this.enabledKinds,
    this.standard,
    required this.settleCents,
    required this.weekendOnlineCents,
    this.tariff,
    this.payment,
    required this.packageEnded,
    required this.leftMinutes,
    required this.dueMinutes,
    this.ahead,
    required this.weekendMinutes,
  });

  String get fullName => '$firstName $lastName';

  factory OpeningPupil.fromJson(Map<String, dynamic> json)
  {
    final Object? tariff = json['tariff'];
    final Object? payment = json['payment'];
    final Object? ahead = json['ahead'];
    final Object? standard = json['standard'];

    return OpeningPupil(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      confirmed: json['confirmed'] as bool,
      schoolLevel: json['school_level'] as String?,
      enabledKinds: {for (final kind in json['enabled_kinds'] as List<dynamic>) kind as String},
      standard: standard == null ? null : LevelStandard.fromJson(standard as Map<String, dynamic>),
      settleCents: json['settle_cents'] as int,
      weekendOnlineCents: json['weekend_online_cents'] as int,
      tariff: tariff == null ? null : OpeningTariff.fromJson(tariff as Map<String, dynamic>),
      payment: payment == null ? null : OpeningPayment.fromJson(payment as Map<String, dynamic>),
      packageEnded: json['package_ended'] as bool,
      leftMinutes: json['left_minutes'] as int,
      dueMinutes: json['due_minutes'] as int,
      ahead: ahead == null ? null : OpeningAhead.fromJson(ahead as Map<String, dynamic>),
      weekendMinutes: json['weekend_minutes'] as int,
    );
  }
}

class AccountingOpening
{
  // The first day the app works the money out.
  final DateTime moneyFrom;
  final bool closed;
  final List<OpeningTeacher> teachers;
  final List<OpeningPupil> pupils;

  const AccountingOpening({
    required this.moneyFrom,
    required this.closed,
    required this.teachers,
    required this.pupils,
  });

  // The day the set-up describes.
  DateTime get lastDay => moneyFrom.subtract(const Duration(days: 1));

  int get teachersLeft => teachers.where((row) => !row.confirmed).length;

  int get pupilsLeft => pupils.where((row) => !row.confirmed).length;

  bool get done => teachersLeft == 0 && pupilsLeft == 0;

  AccountingOpening withTeacher(OpeningTeacher teacher)
  {
    return AccountingOpening(
      moneyFrom: moneyFrom,
      closed: closed,
      teachers: [for (final row in teachers) row.taxCode == teacher.taxCode ? teacher : row],
      pupils: pupils,
    );
  }

  AccountingOpening withPupil(OpeningPupil pupil)
  {
    return AccountingOpening(
      moneyFrom: moneyFrom,
      closed: closed,
      teachers: teachers,
      pupils: [for (final row in pupils) row.taxCode == pupil.taxCode ? pupil : row],
    );
  }

  factory AccountingOpening.fromJson(Map<String, dynamic> json)
  {
    return AccountingOpening(
      moneyFrom: parseDate(json['money_from'])!,
      closed: json['closed'] as bool,
      teachers: parseList(json['teachers'], OpeningTeacher.fromJson),
      pupils: parseList(json['pupils'], OpeningPupil.fromJson),
    );
  }
}
