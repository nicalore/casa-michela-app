import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/birthday.dart';

const int _morningStart = 6;
const int _afternoonStart = 13;
const int _eveningStart = 17;

String greetingLineFor({required String firstName, DateTime? birthDate, required DateTime now})
{
  if (isBirthdayToday(birthDate, now))
  {
    return 'Buon compleanno, $firstName!';
  }

  final hour = now.hour;

  if (hour < _morningStart)
  {
    return 'È tardi, $firstName. Non dimenticarti di riposare.';
  }

  if (hour < _afternoonStart)
  {
    return 'Buongiorno, $firstName';
  }

  if (hour < _eveningStart)
  {
    return 'Buon pomeriggio, $firstName';
  }

  return 'Buonasera, $firstName';
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

  String _greeting()
  {
    return greetingLineFor(firstName: firstName, birthDate: birthDate, now: DateTime.now());
  }

  @override
  Widget build(BuildContext context)
  {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // srcIn uses the text as a mask; a tightened line height shrinks the mask
        // box and erases descenders.
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => AppTheme.greetingGradient.createShader(bounds),
          child: Text(
            text ?? _greeting(),
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