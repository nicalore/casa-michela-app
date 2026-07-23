import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

const Color _comingSoonColor = Color(0xA6003C82);

class DashboardPlaceholderCard extends StatelessWidget
{
  static const double _titleTop = 25;

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
        boxShadow: AppTheme.cardShadow,
      ),
      // The title is pinned near the top while the placeholder label stays
      // centred on the whole card, which a Column could not do.
      child: Stack(
        children: [
          Positioned(
            top: _titleTop,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              'In arrivo...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: _comingSoonColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}