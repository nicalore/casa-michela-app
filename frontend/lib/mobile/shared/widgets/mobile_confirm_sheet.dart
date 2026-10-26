import 'package:flutter/material.dart';

import 'mobile_danger_button.dart';
import 'mobile_sheet.dart';

// Once confirmed, the caller closes the sheet; resolves to false when left or dismissed.
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
      body: [
        const SizedBox(height: 16),
        MobileSheetMessage(message),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: MobileBackRow(
          child: MobileDangerButton(
            label: confirmLabel,
            icon: confirmIcon,
            onPressed: () => finishMobileSheet(context, true),
          ),
        ),
      ),
    ),
  );

  return confirmed ?? false;
}
