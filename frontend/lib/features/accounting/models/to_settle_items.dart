// Contabilità › «Da saldare»: whoever owes something today, as GET /accounting/to-settle/ sends it.

class OwedItem
{
  // HOURLY, OVER_PACKAGE, OVER_FEE, WEEKEND_ONLINE, or MEMBERSHIP_FEE, INSURANCE_FEE.
  final String kind;
  final int cents;

  // Hours only.
  final int? minutes;

  // Fees only: the membership year.
  final int? year;

  const OwedItem({required this.kind, required this.cents, this.minutes, this.year});

  bool get isFee => kind == 'MEMBERSHIP_FEE' || kind == 'INSURANCE_FEE';

  factory OwedItem.fromJson(Map<String, dynamic> json)
  {
    return OwedItem(
      kind: json['kind'] as String,
      cents: json['cents'] as int,
      minutes: json['minutes'] as int?,
      year: json['year'] as int?,
    );
  }
}

class Debtor
{
  final String taxCode;
  final String firstName;
  final String lastName;
  final bool student;
  final bool enrolled;

  // STUDENTE, DOCENTE, CORSISTA, GENITORE, AMMINISTRATORE, PSICOLOGO: what the filter reads.
  final List<String> roles;

  // The oldest lesson still to settle, or the day an owed fee was recorded.
  final DateTime since;

  final int totalCents;
  final List<OwedItem> items;

  const Debtor({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    required this.student,
    required this.enrolled,
    required this.roles,
    required this.since,
    required this.totalCents,
    required this.items,
  });

  String get fullName => '$firstName $lastName';

  factory Debtor.fromJson(Map<String, dynamic> json)
  {
    return Debtor(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      student: json['student'] as bool,
      enrolled: json['enrolled'] as bool,
      roles: [for (final role in json['roles'] as List<dynamic>) role as String],
      since: DateTime.parse(json['since'] as String),
      totalCents: json['total_cents'] as int,
      items: [
        for (final item in json['items'] as List<dynamic>) OwedItem.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class ToSettle
{
  final int totalCents;

  // By surname.
  final List<Debtor> rows;

  const ToSettle({required this.totalCents, required this.rows});

  factory ToSettle.fromJson(Map<String, dynamic> json)
  {
    return ToSettle(
      totalCents: json['total_cents'] as int,
      rows: [
        for (final row in json['rows'] as List<dynamic>) Debtor.fromJson(row as Map<String, dynamic>),
      ],
    );
  }
}
