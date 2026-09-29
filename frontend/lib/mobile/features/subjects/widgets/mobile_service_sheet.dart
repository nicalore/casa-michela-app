import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_sheet.dart';

// True when its one button (take the service on, or give it up) was pressed.
Future<bool?> showMobileServiceSheet({
  required BuildContext context,
  required String name,
  required String? description,
  required bool held,
})
{
  return showMobileSheet<bool>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: 'Servizio',
      title: name,
      body: [
        if (description != null) ...[
          const SizedBox(height: 12),
          MobileSheetText(description),
        ],
      ],
      footer: held
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(true),
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'Rimuovi servizio',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialDanger,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 24),
              child: MobileGoldButton(
                label: 'Conferma',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
    ),
  );
}
