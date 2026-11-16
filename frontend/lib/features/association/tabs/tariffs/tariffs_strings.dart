import '../../../../core/utils/money.dart';

const String kTariffsSection = 'Tariffe';

const String kHomeworkCardTitle = 'Aiuto Compiti';
const String kAnnualFeesCardTitle = 'Quote annuali';

const Map<String, String> kTariffLevelLabels = {
  'PRIMARY_SCHOOL': 'Elementari',
  'MIDDLE_SCHOOL': 'Medie',
  'HIGH_SCHOOL': 'Superiori',
};

const String kHourlyColumn = 'A ore';
const String kPackageColumn = 'Pacchetto';
const String kMonthlyColumn = 'Quota mensile';
const String kWeekendColumn = 'Online nel weekend';

const String kTariffOff = 'Disattivata';

const String kTariffOn = 'Attiva';
const String kTariffOffChoice = 'Disattiva';

const String kMembershipFee = 'Iscrizione';
const String kInsuranceFee = 'Assicurazione';

String hourlyPrice(int cents) => '${formatAmount(cents)} l’ora';

String packagePrice(int cents, int hours) => '${formatAmount(cents)} per ${hours == 1 ? '1 ora' : '$hours ore'}';

String monthlyPrice(int cents) => '${formatAmount(cents)} al mese';

const String kPerYear = 'all’anno';

// Windows.
const String kTariffsEyebrow = 'Tariffe';
const String kAnnualFeesEyebrow = 'Quote annuali';
const String kFeeFieldLabel = 'Costo all’anno';

const String kPerHourSuffix = 'l’ora';
const String kPackagePerSuffix = 'per';
const String kPackageHoursSuffix = 'ore';
const String kPerMonthSuffix = 'al mese';

// Under the hourly tariff, on or off.
const String kHourlyRateNote =
    'Viene utilizzata anche per calcolare le ore in eccedenza quando un pacchetto è terminato o la quota mensile '
    'non è stata pagata.';

const String kSaveLabel = 'SALVA';

// Refusals of «SALVA».
const String kOneTariffOn = 'Almeno una tariffa deve restare attiva.';
const String kHourlyPriceMissing = 'Manca il costo orario.';
const String kPackagePriceMissing = 'Mancano le ore o il costo del pacchetto.';
const String kMonthlyPriceMissing = 'Manca la quota mensile.';
const String kWeekendPriceMissing = 'Manca il costo dell’online nel weekend.';
const String kFeePriceMissing = 'Manca l’importo.';

const String kTariffsLoadFailed = 'Impossibile caricare le tariffe.';

// On a kind struck in the student's windows.
String tariffOffFor(String? level) => 'Disattivata per le ${(kTariffLevelLabels[level] ?? '').toLowerCase()}.';
