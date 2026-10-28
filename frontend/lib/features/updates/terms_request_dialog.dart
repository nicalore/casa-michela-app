import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/dialog_components.dart';
import 'update_strings.dart';

const double _confirmWidth = 480;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;

Future<bool> showTermsRequestConfirmation(BuildContext context) async
{
  final bool? confirmed = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmTermsRequest',
    builder: (confirmContext) => AppDialogStack(
      eyebrow: kTermsRequestEyebrow,
      title: kUpdateConfirmTitle,
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: kUpdateCancel,
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => Navigator.pop(confirmContext, false),
        ),
        primary: AppGradientButton(
          label: kTermsRequestConfirm,
          icon: Icons.check_rounded,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => Navigator.pop(confirmContext, true),
        ),
      ),
      children: [
        AppDialogPill(
          child: Text(
            kTermsRequestQuestion,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: AppTheme.trialInk),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
