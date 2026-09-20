import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/birthday.dart';

class DashboardGreeting extends StatelessWidget
{
  static const int _morningStart = 6;
  static const int _afternoonStart = 13;
  static const int _eveningStart = 17;

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
    final DateTime now = DateTime.now();

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