import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class PersonEditGuide extends StatelessWidget
{
  final String question;
  final String hint;

  const PersonEditGuide({
    super.key,
    required this.question,
    required this.hint,
  });

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: AppTheme.trialOcean,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }
}
