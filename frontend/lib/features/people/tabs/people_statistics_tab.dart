import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PeopleStatisticsTab extends StatelessWidget 
{
  const PeopleStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return Center(
      child: Text(
        'Tab Statistiche in costruzione...',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          color: const Color(0xFF003C82),
        ),
      ),
    );
  }
}