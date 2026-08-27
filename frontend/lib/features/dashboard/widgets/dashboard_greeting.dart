import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

class DashboardGreeting extends StatelessWidget
{
  static const int _morningStart = 6;
  static const int _afternoonStart = 13;
  static const int _eveningStart = 17;

  final String firstName;

  final double fontSize;

  const DashboardGreeting({
    super.key,
    required this.firstName,
    this.fontSize = 50,
  });

  String _greeting()
  {
    final hour = DateTime.now().hour;

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
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // srcIn uses the white text only as a mask. Keep the font's default
        // line height: a tightened height shrinks the mask box and erases
        // descenders.
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => AppTheme.greetingGradient.createShader(bounds),
          child: Text(
            _greeting(),
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