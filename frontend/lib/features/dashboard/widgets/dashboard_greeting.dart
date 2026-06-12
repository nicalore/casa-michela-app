import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardGreeting extends StatelessWidget
{
  final String firstName;

  const DashboardGreeting({
    super.key,
    required this.firstName,
  });

  String _greeting()
  {
    final hour = DateTime.now().hour;

    //Determine appropriate greeting based on time
    if (hour >= 6 && hour < 13)
    {
      return 'Buongiorno, $firstName';
    }

    if (hour >= 13 && hour < 17)
    {
      return 'Buon pomeriggio, $firstName';
    }

    if (hour >= 17)
    {
      return 'Buonasera, $firstName';
    }

    return 'È tardi, $firstName. Non dimenticarti di riposare.';
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
              color: const Color(0xFF000000),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}