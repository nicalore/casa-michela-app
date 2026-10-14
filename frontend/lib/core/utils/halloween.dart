import 'birthday.dart';

// Kept on the last three days of October.
bool isHalloweenToday(DateTime today) => today.month == DateTime.october && today.day >= 29;

// A birthday on one of those days is celebrated instead.
bool isHalloweenFor(DateTime? birthDate, DateTime today) => isHalloweenToday(today) && !isBirthdayToday(birthDate, today);
