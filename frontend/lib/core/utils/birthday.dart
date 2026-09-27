bool isLeapYear(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

// Feb 29 falls on the 28th in non-leap years; DateTime would roll it to 1 March.
DateTime birthdayIn(int year, DateTime birth)
{
  final bool leapDay = birth.month == DateTime.february && birth.day == 29;

  return DateTime(year, birth.month, leapDay && !isLeapYear(year) ? 28 : birth.day);
}

bool isBirthdayToday(DateTime? birth, DateTime today)
{
  if (birth == null)
  {
    return false;
  }

  final DateTime when = birthdayIn(today.year, birth);

  return when.month == today.month && when.day == today.day;
}

int? ageToday(DateTime? birth)
{
  if (birth == null)
  {
    return null;
  }

  final DateTime today = DateTime.now();
  var years = today.year - birth.year;

  if (today.month < birth.month || (today.month == birth.month && today.day < birth.day))
  {
    years--;
  }

  return years;
}
