import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/people/utils/student_notes_strings.dart';
import '../../../shared/widgets/mobile_sheet.dart';

const double _criterionGap = 14;
const double _nameGap = 2;

// The criteria the administrators judge a teacher on, behind the Osservazioni's (i).
Future<void> showMobileCriteriaSheet(BuildContext context)
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: 'Informazioni',
      title: kCriteriaTitle,
      body: [
        const SizedBox(height: 12),
        const MobileSheetText(kCriteriaIntro),
        for (final TeacherCriterion criterion in kCriteria) ...[
          const SizedBox(height: _criterionGap),
          Text(
            criterion.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppTheme.trialOcean,
            ),
          ),
          const SizedBox(height: _nameGap),
          MobileSheetText(criterion.own),
        ],
        const SizedBox(height: 8),
      ],
    ),
  );
}
