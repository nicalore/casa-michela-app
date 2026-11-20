import '../../../core/language/app_language.dart';

// Aiuto Compiti tariffs: what the creation wizard offers, with the enrolment form's figures written in.

String get kHourlyTariff => tr('A ore', 'Hourly');
String get kPackageTariff => tr('Pacchetto', 'Hours package');
String get kMonthlyTariff => tr('Quota mensile', 'Monthly fee');

List<String> get kTariffChoices => [kHourlyTariff, kPackageTariff, kMonthlyTariff];

Map<String, String> get kTariffKinds => {
  kHourlyTariff: 'HOURLY',
  kPackageTariff: 'PACKAGE',
  kMonthlyTariff: 'MONTHLY',
};

String get kTariffLabel => tr('Tariffa Aiuto Compiti', 'Homework Help rate');
String get kHourlyCostLabel => tr('Costo orario', 'Hourly cost');
String get kPackageHoursLabel => tr('Ore del pacchetto', 'Package hours');
String get kPackageCostLabel => tr('Costo del pacchetto', 'Package cost');
String get kMonthlyCostLabel => tr('Quota mensile', 'Monthly fee');

String get kPaidChoice => tr('Pagato', 'Paid');
String get kUnpaidChoice => tr('Non pagato', 'Not paid');
String get kPaidFeminineChoice => tr('Pagata', 'Paid');
String get kUnpaidFeminineChoice => tr('Non pagata', 'Not paid');

// Under the figures when they differ from the level's standard tariff.
String standardTariffNote(String levelLabel, String terms) =>
    tr('Tariffa standard delle ${levelLabel.toLowerCase()}: $terms', 'Standard rate for $levelLabel: $terms');

// The annual fees of the year the new member joins.
String membershipFeeLabel(int year) => tr('Iscrizione $year', 'Enrolment $year');
String insuranceFeeLabel(int year) => tr('Assicurazione $year', 'Insurance $year');
