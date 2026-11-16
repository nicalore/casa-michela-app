// What a pupil of a level is offered for Aiuto Compiti; a kind turned off keeps its prices.
// The hourly rate also prices hours over a package or a fee, even while the hourly tariff is off.
class StandardTariffItem
{
  final String level;
  final bool hourlyEnabled;
  final int hourlyCents;
  final bool packageEnabled;
  final int? packageCents;
  final int? packageHours;
  final bool monthlyEnabled;
  final int? monthlyCents;
  final int weekendOnlineCents;

  const StandardTariffItem({
    required this.level,
    required this.hourlyEnabled,
    required this.hourlyCents,
    required this.packageEnabled,
    this.packageCents,
    this.packageHours,
    required this.monthlyEnabled,
    this.monthlyCents,
    required this.weekendOnlineCents,
  });

  factory StandardTariffItem.fromJson(Map<String, dynamic> json)
  {
    return StandardTariffItem(
      level: json['level'] as String,
      hourlyEnabled: json['hourly_enabled'] as bool,
      hourlyCents: json['hourly_cents'] as int,
      packageEnabled: json['package_enabled'] as bool,
      packageCents: json['package_cents'] as int?,
      packageHours: json['package_hours'] as int?,
      monthlyEnabled: json['monthly_enabled'] as bool,
      monthlyCents: json['monthly_cents'] as int?,
      weekendOnlineCents: json['weekend_online_cents'] as int,
    );
  }

  Map<String, dynamic> toJson()
  {
    return {
      'hourly_enabled': hourlyEnabled,
      'hourly_cents': hourlyCents,
      'package_enabled': packageEnabled,
      'package_cents': packageCents,
      'package_hours': packageHours,
      'monthly_enabled': monthlyEnabled,
      'monthly_cents': monthlyCents,
      'weekend_online_cents': weekendOnlineCents,
    };
  }

  // HOURLY, PACKAGE or MONTHLY.
  bool enabled(String kind)
  {
    return switch (kind)
    {
      'HOURLY' => hourlyEnabled,
      'PACKAGE' => packageEnabled,
      'MONTHLY' => monthlyEnabled,
      _ => false,
    };
  }

  // The price proposed for a kind, null when it has none.
  int? centsOf(String kind)
  {
    return switch (kind)
    {
      'HOURLY' => hourlyCents,
      'PACKAGE' => packageCents,
      'MONTHLY' => monthlyCents,
      _ => null,
    };
  }
}

class AnnualFeesItem
{
  final int membershipCents;
  final int insuranceCents;

  const AnnualFeesItem({required this.membershipCents, required this.insuranceCents});

  factory AnnualFeesItem.fromJson(Map<String, dynamic> json)
  {
    return AnnualFeesItem(
      membershipCents: json['membership_cents'] as int,
      insuranceCents: json['insurance_cents'] as int,
    );
  }

  Map<String, dynamic> toJson() => {'membership_cents': membershipCents, 'insurance_cents': insuranceCents};
}

class StandardTariffsItem
{
  // Primary, middle and high school, in this order.
  final List<StandardTariffItem> levels;
  final AnnualFeesItem fees;

  const StandardTariffsItem({required this.levels, required this.fees});

  factory StandardTariffsItem.fromJson(Map<String, dynamic> json)
  {
    return StandardTariffsItem(
      levels: [
        for (final row in json['levels'] as List<dynamic>) StandardTariffItem.fromJson(row as Map<String, dynamic>),
      ],
      fees: AnnualFeesItem.fromJson(json['fees'] as Map<String, dynamic>),
    );
  }

  StandardTariffItem? of(String? level) => levels.where((row) => row.level == level).firstOrNull;
}
