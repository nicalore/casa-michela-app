// Section 4 of the enrolment form: the Aiuto Compiti rates in force from
// 1 September 2026 to the end of the 2026/2027 school year. Nothing here is
// stored: the wizard only shows what the family is signing up to.

const String kHourlyTariff = 'Tariffa oraria';
const String kPackageTariff = 'Pacchetto';

const List<String> kHomeworkTariffChoices = [kHourlyTariff, kPackageTariff];

// Primary school has nothing to choose: one flat fee, whatever the hours.
const String kPrimarySchoolTariff = 'Retta fissa mensile — € 170,00 al mese';

class HomeworkTariff
{
  final String hourlyRate;

  final String packageOffer;

  // What an hour costs once the package is bought: the form's 'Equivalente orario'.
  final String packageHourlyRate;

  const HomeworkTariff({
    required this.hourlyRate,
    required this.packageOffer,
    required this.packageHourlyRate,
  });

  String get summary =>
      '$kHourlyTariff $hourlyRate\n$kPackageTariff $packageOffer, '
      'equivalente a $packageHourlyRate.';
}

// What the enrolment form is told, so it can tick the right box in its rate
// table. Sent with the form request alone: nothing about it is ever stored.
const String kPrimaryTariffCode = 'PRIMARY_MONTHLY';

const Map<String, Map<String, String>> _tariffCodes = {
  'MIDDLE_SCHOOL': {
    kHourlyTariff: 'MIDDLE_HOURLY',
    kPackageTariff: 'MIDDLE_PACKAGE',
  },
  'HIGH_SCHOOL': {
    kHourlyTariff: 'HIGH_HOURLY',
    kPackageTariff: 'HIGH_PACKAGE',
  },
};

// Primary school has one rate and no question to answer, so it needs no choice.
String? homeworkTariffCodeOf({required String? level, required String? choice})
{
  if (level == 'PRIMARY_SCHOOL')
  {
    return kPrimaryTariffCode;
  }

  return _tariffCodes[level]?[choice];
}

// Keyed by the school level of the study programme, as SchoolLevel spells it.
const Map<String, HomeworkTariff> kHomeworkTariffs = {
  'MIDDLE_SCHOOL': HomeworkTariff(
    hourlyRate: '€ 13,00 / ora',
    packageOffer: '18 ore a € 215,00',
    packageHourlyRate: '€ 11,95 / ora',
  ),
  'HIGH_SCHOOL': HomeworkTariff(
    hourlyRate: '€ 14,00 / ora',
    packageOffer: '20 ore a € 260,00',
    packageHourlyRate: '€ 13,00 / ora',
  ),
};
