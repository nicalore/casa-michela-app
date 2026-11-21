import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/birthday.dart';
import '../../../core/utils/festivities.dart';
import '../../../core/utils/halloween.dart';
import '../../../core/utils/rome_clock.dart';

const int _morningStart = 6;
const int _afternoonStart = 13;
const int _eveningStart = 17;

String greetingLineFor({required String firstName, DateTime? birthDate, required DateTime now})
{
  if (isBirthdayToday(birthDate, now))
  {
    return tr('Buon compleanno, $firstName!', 'Happy birthday, $firstName!');
  }

  if (isHalloweenToday(now))
  {
    return tr('Dolcetto o scherzetto, $firstName?', 'Trick or treat, $firstName?');
  }

  switch (festivityOn(now))
  {
    case Festivity.holidays:
      return tr('Buone feste, $firstName!', 'Happy holidays, $firstName!');
    case Festivity.christmas:
      return tr('Buon Natale, $firstName!', 'Merry Christmas, $firstName!');
    case Festivity.newYear:
      return tr('Felice ${newYearOf(now)}, $firstName!', 'Happy ${newYearOf(now)}, $firstName!');
    case null:
      break;
  }

  final hour = now.hour;

  if (hour < _morningStart)
  {
    return tr('È tardi, $firstName. Non dimenticarti di riposare.', "It's late, $firstName. Don't forget to rest.");
  }

  if (hour < _afternoonStart)
  {
    return tr('Buongiorno, $firstName', 'Good morning, $firstName');
  }

  if (hour < _eveningStart)
  {
    return tr('Buon pomeriggio, $firstName', 'Good afternoon, $firstName');
  }

  return tr('Buonasera, $firstName', 'Good evening, $firstName');
}

class DashboardGreeting extends StatelessWidget
{
  final String firstName;

  // On the day itself the line wishes a happy birthday, whatever the hour.
  final DateTime? birthDate;

  final double fontSize;

  // Overrides the time-of-day line.
  final String? text;

  final Alignment alignment;

  const DashboardGreeting({
    super.key,
    required this.firstName,
    this.birthDate,
    this.fontSize = 50,
    this.text,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context)
  {
    final DateTime now = romeNow();
    final LinearGradient gradient = text == null && isHalloweenFor(birthDate, now)
        ? AppTheme.halloweenGreetingGradient
        : AppTheme.greetingGradient;

    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // srcIn masks with the text: a tighter line height shrinks the mask, cutting descenders.
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => gradient.createShader(bounds),
          child: Text(
            text ?? greetingLineFor(firstName: firstName, birthDate: birthDate, now: now),
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}