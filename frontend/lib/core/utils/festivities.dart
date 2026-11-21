import 'birthday.dart';

enum Festivity
{
  holidays,
  christmas,
  newYear,
}

// 20-23 and 26-30 December: holidays; 24-25: Christmas; 31 December - 2 January: the new year.
Festivity? festivityOn(DateTime today)
{
  if (today.month == DateTime.december)
  {
    if (today.day == 24 || today.day == 25)
    {
      return Festivity.christmas;
    }

    if (today.day == 31)
    {
      return Festivity.newYear;
    }

    return today.day >= 20 ? Festivity.holidays : null;
  }

  return today.month == DateTime.january && today.day <= 2 ? Festivity.newYear : null;
}

// 20 December - 2 January: lights on the bar and the menu, snow on the home's cards, under any other celebration.
bool isDecoratedDay(DateTime today) => festivityOn(today) != null;

// On 31 December the year about to start.
int newYearOf(DateTime today) => today.month == DateTime.december ? today.year + 1 : today.year;

// A birthday on one of those days is celebrated instead.
Festivity? festivityFor(DateTime? birthDate, DateTime today) => isBirthdayToday(birthDate, today) ? null : festivityOn(today);
