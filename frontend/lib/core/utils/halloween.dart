import 'package:flutter/foundation.dart';

import 'birthday.dart';

// Switches the whole celebration (greeting, colours, bats) on or off.
const bool kHalloweenEnabled = false;

// Stands in for the switch in tests, which check the celebration while it is off.
@visibleForTesting
bool? debugHalloweenEnabled;

// Kept on the last three days of October.
bool isHalloweenToday(DateTime today) =>
    (debugHalloweenEnabled ?? kHalloweenEnabled) && today.month == DateTime.october && today.day >= 29;

// A birthday on one of those days is celebrated instead.
bool isHalloweenFor(DateTime? birthDate, DateTime today) => isHalloweenToday(today) && !isBirthdayToday(birthDate, today);
