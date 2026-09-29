import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_danger_button.dart';
import 'mobile_dismiss_button.dart';
import 'mobile_sheet.dart';

const double _pillRadius = 20;

// Resolves to false when dismissed.
Future<bool> showMobileConfirmSheet({
  required BuildContext context,
  required String eyebrow,
  required String title,
  required TextSpan message,
  required String confirmLabel,
  required IconData confirmIcon,
}) async
{
  final bool? confirmed = await showMobileSheet<bool>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: eyebrow,
      title: title,
      closable: false,
      body: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.08)),
          ),
          child: Text.rich(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Row(
          children: [
            Expanded(
              child: MobileDismissButton(
                label: 'Annulla',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MobileDangerButton(
                label: confirmLabel,
                icon: confirmIcon,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return confirmed ?? false;
}
