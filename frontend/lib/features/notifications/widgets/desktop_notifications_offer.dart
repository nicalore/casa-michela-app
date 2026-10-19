import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../device_notifications.dart';
import '../notification_strings.dart';

const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _offerWidth = 520;

bool _offering = false;

// While the first-access question may still come: what opens by itself waits behind it.
bool get isNotificationsOfferPending => _offering;

// From a tap: the browser asks only inside one. Blocked, it can only say where to undo it.
Future<void> turnNotificationsOn(BuildContext context) async
{
  if (DeviceNotifications.state.value == NotificationSwitch.blocked)
  {
    CustomSnackBar.show(context: context, message: kNotificationsBlockedWeb, tone: SnackBarTone.warning);

    return;
  }

  final NotificationSwitch result = await DeviceNotifications.turnOn();

  if (result == NotificationSwitch.blocked && context.mounted)
  {
    CustomSnackBar.show(context: context, message: kNotificationsBlockedWeb, tone: SnackBarTone.warning);
  }
}

// The first-access question, once per browser: after onboarding, before any tour.
Future<void> offerNotificationsOnce(BuildContext context) async
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

    await settleDesktopPage(context);

    if (!context.mounted || !isDestinationShown(context))
    {
      return;
    }

    // Marked first: a tab closed on the question must not ask it again.
    await DeviceNotifications.markOffered();

    if (!context.mounted)
    {
      return;
    }

    await showNotificationsOffer(context);
    await blurredDialogsGone();
  }
  finally
  {
    _offering = false;
  }
}

// The question itself; "Attiva" asks the browser from inside its own tap.
Future<void> showNotificationsOffer(BuildContext context)
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'NotificationsOffer',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: kNotificationsOfferEyebrow,
      title: kNotificationsOfferTitle,
      showClose: false,
      maxWidth: _offerWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: kNotificationsNotNow.toUpperCase(),
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => Navigator.pop(dialogContext),
        ),
        primary: AppGradientButton(
          label: kNotificationsTurnOn.toUpperCase(),
          icon: Icons.notifications_active_rounded,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: ()
          {
            DeviceNotifications.turnOn();
            Navigator.pop(dialogContext);
          },
        ),
      ),
      children: [
        AppDialogPill(
          child: Text(
            kNotificationsOfferMessage,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
    ),
  );
}
