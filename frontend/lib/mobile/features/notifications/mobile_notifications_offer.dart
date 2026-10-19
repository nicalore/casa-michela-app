import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/notifications/device_notifications.dart';
import '../../../features/notifications/notification_strings.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_sheet.dart';

const double _badgeSize = 58;

bool _offering = false;

// While the first-access question may still come: what opens by itself waits behind it.
bool get isMobileNotificationsOfferPending => _offering;

// Refused for good, only the system's settings turn them back on.
Future<void> turnMobileNotificationsOn(BuildContext context) async
{
  if (DeviceNotifications.state.value != NotificationSwitch.blocked)
  {
    await DeviceNotifications.turnOn();

    return;
  }

  if (!await DeviceNotifications.openSettings() && context.mounted)
  {
    MobileNotice.show(context, kNotificationsBlockedMobile);
  }
}

// The first-access question, once per install: after onboarding, before the home's tour.
Future<void> offerMobileNotificationsOnce(BuildContext context) async
{
  if (_offering)
  {
    return;
  }

  _offering = true;

  try
  {
    if (!await DeviceNotifications.shouldOffer() || !context.mounted)
    {
      return;
    }

    // Marked first: an app closed on the question must not ask it again.
    await DeviceNotifications.markOffered();

    if (!context.mounted)
    {
      return;
    }

    if (await askMobileNotifications(context))
    {
      await DeviceNotifications.turnOn();
    }
  }
  finally
  {
    _offering = false;
  }
}

// The question itself: true when "Attiva" was tapped.
Future<bool> askMobileNotifications(BuildContext context) async
{
  final bool? accepted = await showMobileSheet<bool>(
    context: context,
    builder: (sheetContext) => MobileSheet(
      eyebrow: kNotificationsOfferEyebrow,
      title: kNotificationsOfferTitle,
      leading: Container(
        width: _badgeSize,
        height: _badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.trialTealDeep.withValues(alpha: 0.13),
        ),
        child: const Icon(Icons.notifications_active_rounded, size: 30, color: AppTheme.trialTealDeep),
      ),
      body: const [
        SizedBox(height: 16),
        MobileSheetCard(child: MobileSheetText(kNotificationsOfferMessage)),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Row(
          children: [
            Expanded(
              child: MobileDismissButton(
                label: kNotificationsNotNow,
                icon: Icons.close_rounded,
                onPressed: () => finishMobileSheet(sheetContext, false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MobileGoldButton(
                label: kNotificationsTurnOn,
                icon: Icons.notifications_active_rounded,
                onPressed: () => finishMobileSheet(sheetContext, true),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return accepted ?? false;
}
