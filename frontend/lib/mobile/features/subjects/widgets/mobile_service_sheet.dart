import 'package:flutter/material.dart';

import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_sheet.dart';

// True when the service was taken on; null when dismissed.
Future<bool?> showMobileServiceSheet({
  required BuildContext context,
  required String name,
  required String? description,
  required Future<void> Function(BuildContext sheet)? onRemove,
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
      footer: onRemove != null
          ? Padding(
              padding: const EdgeInsets.only(top: 24),
              child: MobileDangerButton(
                label: 'Rimuovi servizio',
                icon: Icons.delete_outline_rounded,
                onPressed: () => onRemove(context),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 24),
              child: MobileGoldButton(
                label: 'Conferma',
                icon: Icons.check_rounded,
                onPressed: () => finishMobileSheet(context, true),
              ),
            ),
    ),
  );
}
