import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/notifications/device_notifications.dart';
import '../../../features/notifications/notification_item.dart';
import '../../../features/notifications/notification_kinds.dart';
import '../../../features/notifications/notification_look.dart';
import '../../../features/notifications/notification_strings.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_select_parts.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../profile/widgets/mobile_detail_card.dart';

// Every kind of the account's roles; a tap turns one on or off for every device, at once.
Future<void> showMobileNotificationKindsSheet(BuildContext context)
{
  return showMobileSheet<void>(
    context: context,
    builder: (_) => const _KindsSheet(),
  );
}

class _KindsSheet extends StatefulWidget
{
  const _KindsSheet();

  @override
  State<_KindsSheet> createState() => _KindsSheetState();
}

class _KindsSheetState extends State<_KindsSheet>
{
  // A tap waits for the one before: the last kind off turns the device off and closes the sheet.
  bool _saving = false;

  Future<void> _turn(NotificationKindChoice choice) async
  {
    if (_saving)
    {
      return;
    }

    final List<NotificationKindChoice> choices = NotificationKinds.instance.choices ?? const [];

    _saving = true;

    try
    {
      await DeviceNotifications.chooseKinds([
        for (final other in choices) other.kind == choice.kind ? other.turned(!other.enabled) : other,
      ]);

      // The last one off turned this device off, and kinds are chosen only while it is on.
      if (mounted && DeviceNotifications.state.value != NotificationSwitch.on)
      {
        closeMobileSheet(context);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: NotificationKinds.instance,
      builder: (context, _) => MobileSheet(
        eyebrow: kSystemSection,
        title: kNotificationKindsTitle,
        body: [
          const SizedBox(height: 12),
          const MobileSheetText(kNotificationKindsHint),
          const SizedBox(height: 18),
          for (final choice in NotificationKinds.instance.choices ?? const <NotificationKindChoice>[])
            MobileSelectRow(
              title: kNotificationKindLabels[choice.kind]?.$1 ?? '',
              subtitle: kNotificationKindLabels[choice.kind]?.$2,
              leading: MobileCardBadge(
                icon: NotificationLook.of(choice.kind).icon,
                tint: choice.enabled ? Colors.white : AppTheme.trialTealDeep,
              ),
              selected: choice.enabled,
              onTap: () => _turn(choice),
            ),
        ],
      ),
    );
  }
}
