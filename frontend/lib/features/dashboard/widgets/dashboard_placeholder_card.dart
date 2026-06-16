import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPlaceholderCard extends StatelessWidget
{
  final String title;
  final double width;
  final double height;

  const DashboardPlaceholderCard({
    super.key,
    required this.title,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          //TitleSection
          Positioned(
            top: 25,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF003C82),
                ),
              ),
            ),
          ),

          //WIPLabel
          Center(
            child: Text(
              'In arrivo...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: const Color(0xA6003C82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}