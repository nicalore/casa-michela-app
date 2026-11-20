import '../../../../core/language/app_language.dart';
import '../../../../core/utils/money.dart';

String get kTariffsSection => tr('Tariffe', 'Rates');

String get kHomeworkCardTitle => tr('Aiuto Compiti', 'Homework Help');
String get kAnnualFeesCardTitle => tr('Quote annuali', 'Annual fees');

Map<String, String> get kTariffLevelLabels => {
  'PRIMARY_SCHOOL': tr('Elementari', 'Primary school'),
  'MIDDLE_SCHOOL': tr('Medie', 'Lower secondary'),
  'HIGH_SCHOOL': tr('Superiori', 'Upper secondary'),
};

String get kHourlyColumn => tr('A ore', 'Hourly');
String get kPackageColumn => tr('Pacchetto', 'Package');
String get kMonthlyColumn => tr('Quota mensile', 'Monthly fee');
String get kWeekendColumn => tr('Online nel weekend', 'Online at weekends');

String get kTariffOff => tr('Disattivata', 'Off');

String get kTariffOn => tr('Attiva', 'On');
String get kTariffOffChoice => tr('Disattiva', 'Off');

String get kMembershipFee => tr('Iscrizione', 'Enrolment');
String get kInsuranceFee => tr('Assicurazione', 'Insurance');

String hourlyPrice(int cents) => tr('${formatAmount(cents)} l’ora', '${formatAmount(cents)} per hour');

String packagePrice(int cents, int hours) => hours == 1
    ? tr('${formatAmount(cents)} per 1 ora', '${formatAmount(cents)} for 1 hour')
    : tr('${formatAmount(cents)} per $hours ore', '${formatAmount(cents)} for $hours hours');

String monthlyPrice(int cents) => tr('${formatAmount(cents)} al mese', '${formatAmount(cents)} per month');

String get kPerYear => tr('all’anno', 'per year');

// Windows.
String get kTariffsEyebrow => tr('Tariffe', 'Rates');
String get kAnnualFeesEyebrow => tr('Quote annuali', 'Annual fees');
String get kFeeFieldLabel => tr('Costo all’anno', 'Cost per year');

String get kPerHourSuffix => tr('l’ora', 'per hour');
String get kPackagePerSuffix => tr('per', 'for');
String get kPackageHoursSuffix => tr('ore', 'hours');
String get kPerMonthSuffix => tr('al mese', 'per month');

// Under the hourly tariff, on or off.
String get kHourlyRateNote => tr(
  'Viene utilizzata anche per calcolare le ore in eccedenza quando un pacchetto è terminato o la quota mensile '
      'non è stata pagata.',
  'It is also used to work out the extra hours when a package has run out or the monthly fee '
      'has not been paid.',
);

String get kSaveLabel => tr('SALVA', 'SAVE');

// Refusals of «SALVA».
String get kOneTariffOn => tr('Almeno una tariffa deve restare attiva.', 'At least one rate must stay on.');
String get kHourlyPriceMissing => tr('Manca il costo orario.', 'The hourly cost is missing.');
String get kPackagePriceMissing => tr('Mancano le ore o il costo del pacchetto.', "The package's hours or cost are missing.");
String get kMonthlyPriceMissing => tr('Manca la quota mensile.', 'The monthly fee is missing.');
String get kWeekendPriceMissing => tr('Manca il costo dell’online nel weekend.', 'The cost of online lessons at weekends is missing.');
String get kFeePriceMissing => tr('Manca l’importo.', 'The amount is missing.');

String get kTariffsLoadFailed => tr('Impossibile caricare le tariffe.', "Couldn't load the rates.");

// On a kind struck in the student's windows.
String tariffOffFor(String? level) => tr(
  'Disattivata per le ${(kTariffLevelLabels[level] ?? '').toLowerCase()}.',
  'Off for ${(kTariffLevelLabels[level] ?? '').toLowerCase()}.',
);
