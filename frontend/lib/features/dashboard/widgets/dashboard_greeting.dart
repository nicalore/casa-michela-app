import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardGreeting extends StatelessWidget
{
  static const int _morningStart = 6;
  static const int _afternoonStart = 13;
  static const int _eveningStart = 17;

  final String firstName;

  const DashboardGreeting({
    super.key,
    required this.firstName,
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
    return Positioned(
      left: 40,
      right: 40,
      top: 150,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _greeting(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 50,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}