import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../utils/student_notes_strings.dart';

const double _maxWidth = 640;
const double _criterionGap = 16;
const double _nameGap = 2;

const double _buttonSize = 40;
const double _buttonIconSize = 22;

Future<void> showCriteriaDialog(BuildContext context)
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: kCriteriaTitle,
    builder: (_) => const CriteriaDialog(),
  );
}

// The (i) that opens it: the dialogs' round close button, with the info icon.
class CriteriaButton extends StatelessWidget
{
  final VoidCallback onTap;

  const CriteriaButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: kCriteriaTitle,
      child: CarouselArrowButton(
        size: _buttonSize,
        iconSize: _buttonIconSize,
        icon: Icons.info_outline_rounded,
        hoverColor: AppTheme.trialGoldSurface,
        hoverIconColor: AppTheme.trialTealDeep,
        hoverBorderColor: AppTheme.trialGold,
        onTap: onTap,
      ),
    );
  }
}

// The criteria the administrators judge a teacher on.
class CriteriaDialog extends StatelessWidget
{
  const CriteriaDialog({super.key});

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Informazioni',
      title: kCriteriaTitle,
      maxWidth: _maxWidth,
      fillLast: true,
      children: [
        AppScrollingDialogPill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kCriteriaIntro,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: AppTheme.trialMutedText,
                ),
              ),
              for (final TeacherCriterion criterion in kCriteria) ...[
                const SizedBox(height: _criterionGap),
                Text(
                  criterion.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const SizedBox(height: _nameGap),
                Text(
                  criterion.own,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: AppTheme.trialInk,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
