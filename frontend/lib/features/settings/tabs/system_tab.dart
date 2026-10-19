import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../notifications/device_notifications.dart';
import '../../notifications/notification_kinds.dart';
import '../../notifications/notification_strings.dart';
import '../../notifications/widgets/desktop_notifications_offer.dart';
import '../../notifications/widgets/notification_kinds_dialog.dart';
import '../utils/settings_strings.dart';
import '../widgets/settings_panel.dart';
import '../widgets/tutorial_card.dart';

class SystemTab extends StatefulWidget
{
  const SystemTab({super.key});

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab>
{
  // Read again on every visit: the browser's settings or another device may have changed them.
  @override
  void initState()
  {
    super.initState();

    DeviceNotifications.refresh();
    NotificationKinds.instance.load();
  }

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: Listenable.merge([DeviceNotifications.state, NotificationKinds.instance]),
      builder: (context, _)
      {
        final NotificationSwitch state = DeviceNotifications.state.value;
        final bool hasKinds = NotificationKinds.instance.choices?.isNotEmpty ?? false;

        return SettingsColumn(
          children: [
            SettingsPanel(
              heading: kNotificationsSettingTitle,
              rows: [
                _DeviceRow(state: state),
                if (hasKinds) _KindsRow(on: state == NotificationSwitch.on),
              ],
            ),
            if (TutorialRow.shownFor(ApiService().lastKnownIdentity))
              const SettingsPanel(heading: kTutorialTitle, rows: [TutorialRow()]),
          ],
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget
{
  final NotificationSwitch state;

  const _DeviceRow({required this.state});

  String get _line => switch (state)
  {
    NotificationSwitch.blocked => kNotificationsBlockedWeb,
    NotificationSwitch.unsupported => kNotificationsUnsupported,
    _ => kNotificationsSettingHint,
  };

  // Blocked by the browser, a tap on "Attive" says so.
  @override
  Widget build(BuildContext context)
  {
    return SettingsRow(
      icon: Icons.notifications_rounded,
      title: kNotificationsSettingTitle,
      subtitle: _line,
      trailing: state == NotificationSwitch.unsupported
          ? null
          : AppSegmentedSwitch(
              value: state == NotificationSwitch.on,
              trueLabel: kNotificationsOn,
              falseLabel: kNotificationsOff,
              hugContent: true,
              onChanged: (on) => on ? turnNotificationsOn(context) : DeviceNotifications.turnOff(),
            ),
    );
  }
}

class _KindsRow extends StatelessWidget
{
  final bool on;

  const _KindsRow({required this.on});

  @override
  Widget build(BuildContext context)
  {
    final NotificationKinds kinds = NotificationKinds.instance;

    return SettingsRow(
      icon: Icons.tune_rounded,
      title: kNotificationKindsTitle,
      subtitle: on
          ? notificationKindsCount(kinds.enabledCount, kinds.choices?.length ?? 0)
          : kNotificationKindsTurnOnFirst,
      trailing: on
          ? AppGradientButton(
              label: kNotificationKindsChoose.toUpperCase(),
              icon: Icons.tune_rounded,
              height: kSettingsButtonHeight,
              radius: kSettingsButtonHeight / 2,
              fontSize: kSettingsButtonFontSize,
              onPressed: () => showNotificationKindsDialog(context),
            )
          : null,
    );
  }
}
