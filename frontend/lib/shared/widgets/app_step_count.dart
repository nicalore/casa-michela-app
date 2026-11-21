import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// "1/2" in a tinted capsule, beside a heading.
class AppStepCount extends StatelessWidget
{
  final int index;
  final int count;
  final Color color;
  final double fontSize;

  const AppStepCount({
    super.key,
    required this.index,
    required this.count,
    required this.color,
    this.fontSize = 10.5,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.65, vertical: fontSize * 0.1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$index/$count',
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
