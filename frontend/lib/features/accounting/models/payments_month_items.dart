// Riepilogo mensile › «Pagamenti»: everything paid in a month by anyone, as GET /accounting/payments/{y}/{m} sends it.

class MonthPayment
{
  final DateTime paidOn;
  final String taxCode;
  final String firstName;
  final String lastName;

  // STUDENTE, DOCENTE, CORSISTA, GENITORE, AMMINISTRATORE, PSICOLOGO: what the filter reads.
  final List<String> roles;

  // PACKAGE, MONTH, AHEAD, WEEKEND_AHEAD, the hours settled (HOURLY, OVER_PACKAGE, OVER_FEE, WEEKEND_ONLINE),
  // or an annual fee (MEMBERSHIP_FEE, INSURANCE_FEE).
  final String kind;

  final int amountCents;
  final String? paymentMethod;
  final String? paymentMethodOther;
  final int? packageHours;

  // A month's fee; null while it waits for a package to end.
  final DateTime? month;

  final int? aheadMinutes;

  // Hours settled.
  final int? minutes;

  // Annual fees: the membership year.
  final int? year;

  const MonthPayment({
    required this.paidOn,
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.kind,
    required this.amountCents,
    this.paymentMethod,
    this.paymentMethodOther,
    this.packageHours,
    this.month,
    this.aheadMinutes,
    this.minutes,
    this.year,
  });

  String get fullName => '$firstName $lastName';

  bool get isFee => kind == 'MEMBERSHIP_FEE' || kind == 'INSURANCE_FEE';

  // The tariff it falls under, as the filter reads it: hours past a package or an unpaid
  // fee stay with that tariff; the weekend's online hours and the annual fees stand apart.
  String get tariff => switch (kind)
  {
    'PACKAGE' || 'OVER_PACKAGE' => 'PACKAGE',
    'MONTH' || 'OVER_FEE' => 'MONTHLY',
    'HOURLY' || 'AHEAD' => 'HOURLY',
    'WEEKEND_AHEAD' => 'WEEKEND_ONLINE',
    _ => kind,
  };

  factory MonthPayment.fromJson(Map<String, dynamic> json)
  {
    final String? month = json['month'] as String?;

    return MonthPayment(
      paidOn: DateTime.parse(json['paid_on'] as String),
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      roles: [for (final role in json['roles'] as List<dynamic>) role as String],
      kind: json['kind'] as String,
      amountCents: json['amount_cents'] as int,
      paymentMethod: json['payment_method'] as String?,
      paymentMethodOther: json['payment_method_other'] as String?,
      packageHours: json['package_hours'] as int?,
      month: month == null ? null : DateTime.parse(month),
      aheadMinutes: json['ahead_minutes'] as int?,
      minutes: json['minutes'] as int?,
      year: json['year'] as int?,
    );
  }
}

class PaymentsMonth
{
  final DateTime month;
  final int totalCents;

  // Newest first.
  final List<MonthPayment> rows;

  const PaymentsMonth({required this.month, required this.totalCents, required this.rows});

  factory PaymentsMonth.fromJson(Map<String, dynamic> json)
  {
    return PaymentsMonth(
      month: DateTime.parse(json['month'] as String),
      totalCents: json['total_cents'] as int,
      rows: [
        for (final row in json['rows'] as List<dynamic>) MonthPayment.fromJson(row as Map<String, dynamic>),
      ],
    );
  }
}
