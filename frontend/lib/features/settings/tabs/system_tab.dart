import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../notifications/device_notifications.dart';
import '../../notifications/notification_kinds.dart';
import '../../notifications/notification_strings.dart';
import '../../notifications/widgets/desktop_notifications_offer.dart';
import '../../notifications/widgets/notification_kinds_dialog.dart';
import '../widgets/settings_card_grid.dart';
import '../widgets/tutorial_card.dart';

const double _chipGap = 10;
const double _hintGap = 18;

TextStyle _hintStyle() => GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppTheme.trialMutedText,
    );

// This device's notifications, which kinds the account receives on every device, then the tutorials.
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

        return SettingsCardGrid(
          cards: [
            _DeviceCard(state: state),
            if (hasKinds) _KindsCard(on: state == NotificationSwitch.on),
            if (TutorialCard.shownFor(ApiService().lastKnownIdentity)) const TutorialCard(),
          ],
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget
{
  final NotificationSwitch state;

  const _DeviceCard({required this.state});

  String get _hint => switch (state)
  {
    NotificationSwitch.blocked => kNotificationsBlockedWeb,
    NotificationSwitch.unsupported => kNotificationsUnsupported,
    _ => kNotificationsSettingHint,
  };

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: kNotificationsSettingTitle,
      compact: true,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.notifications_rounded, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hint, style: _hintStyle()),
          if (state != NotificationSwitch.unsupported) ...[
            const SizedBox(height: _hintGap),
            Wrap(
              spacing: _chipGap,
              runSpacing: _chipGap,
              children: [
                AppSelectableChip(
                  label: kNotificationsOn,
                  selected: state == NotificationSwitch.on,
                  onSelected: (_) => turnNotificationsOn(context),
                ),
                AppSelectableChip(
                  label: kNotificationsOff,
                  selected: state != NotificationSwitch.on,
                  onSelected: (_) => DeviceNotifications.turnOff(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Only the button: the dialog says which kinds there are and which are on.
class _KindsCard extends StatelessWidget
{
  final bool on;

  const _KindsCard({required this.on});

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: kNotificationKindsTitle,
      compact: true,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.tune_rounded, compact: true),
      // The button in the middle of the room the card shares with its neighbour.
      fillHeight: on,
      child: on
          ? SizedBox(
              width: double.infinity,
              child: Center(
                child: AppGradientButton(
                  label: kNotificationKindsChoose.toUpperCase(),
                  icon: Icons.tune_rounded,
                  onPressed: () => showNotificationKindsDialog(context),
                ),
              ),
            )
          : Text(kNotificationKindsTurnOnFirst, style: _hintStyle()),
    );
  }
}
