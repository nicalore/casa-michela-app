// Aiuto Compiti tariffs: what the creation wizard offers, with the enrolment form's figures written in.

const String kHourlyTariff = 'A ore';
const String kPackageTariff = 'Pacchetto';
const String kMonthlyTariff = 'Quota mensile';

const List<String> kTariffChoices = [kHourlyTariff, kPackageTariff, kMonthlyTariff];

const Map<String, String> kTariffKinds = {
  kHourlyTariff: 'HOURLY',
  kPackageTariff: 'PACKAGE',
  kMonthlyTariff: 'MONTHLY',
};

const String kTariffLabel = 'Tariffa Aiuto Compiti';
const String kHourlyCostLabel = 'Costo orario';
const String kPackageHoursLabel = 'Ore del pacchetto';
const String kPackageCostLabel = 'Costo del pacchetto';
const String kMonthlyCostLabel = 'Quota mensile';

const String kPaidChoice = 'Pagato';
const String kUnpaidChoice = 'Non pagato';
const String kPaidFeminineChoice = 'Pagata';
const String kUnpaidFeminineChoice = 'Non pagata';

// Under the figures when they differ from the level's standard tariff.
String standardTariffNote(String levelLabel, String terms) => 'Tariffa standard delle ${levelLabel.toLowerCase()}: $terms';

// The annual fees of the year the new member joins.
String membershipFeeLabel(int year) => 'Iscrizione $year';
String insuranceFeeLabel(int year) => 'Assicurazione $year';
