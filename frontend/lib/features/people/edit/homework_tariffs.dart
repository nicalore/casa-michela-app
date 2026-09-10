// Aiuto Compiti rates in force for the 2026/2027 school year; the choice itself lives on the student record.

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

// Codes stored on the pupil: the level plus the rate chosen.
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

// The choice buried in a stored code, so reopening a pupil restores the chips.
String? homeworkTariffChoiceOf(String? code)
{
  for (final Map<String, String> byChoice in _tariffCodes.values)
  {
    for (final MapEntry<String, String> entry in byChoice.entries)
    {
      if (entry.value == code)
      {
        return entry.key;
      }
    }
  }

  return null;
}

String? homeworkTariffLabel(String? code)
{
  if (code == null)
  {
    return null;
  }

  if (code == kPrimaryTariffCode)
  {
    return kPrimarySchoolTariff;
  }

  for (final MapEntry<String, Map<String, String>> level in _tariffCodes.entries)
  {
    for (final MapEntry<String, String> entry in level.value.entries)
    {
      if (entry.value != code)
      {
        continue;
      }

      final HomeworkTariff tariff = kHomeworkTariffs[level.key]!;
      final String figures =
          entry.key == kHourlyTariff ? tariff.hourlyRate : tariff.packageOffer;

      return '${entry.key} — $figures';
    }
  }

  return null;
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
