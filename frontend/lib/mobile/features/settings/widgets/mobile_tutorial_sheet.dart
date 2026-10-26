import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/models/me_response.dart';
import '../../../../features/notifications/device_notifications.dart';
import '../../../../features/notifications/notification_kinds.dart';
import '../../../../features/notifications/notification_strings.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../shared/mobile_line_breaks.dart';
import '../../../shared/navigation/mobile_destinations.dart';
import '../../../shared/widgets/mobile_choice_sheet.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../../notifications/mobile_notification_kinds_sheet.dart';
import '../../notifications/mobile_notifications_offer.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_glass_list.dart';

const double _badgeSize = 34;
const double _rowLeft = 14;
const double _rowGap = 13;

const double _offOpacity = 0.45;

// The tutorial, this device's notifications once it can show them, then the account's kinds.
class MobileSystemCard extends StatefulWidget
{
  final VoidCallback onTutorial;

  const MobileSystemCard({super.key, required this.onTutorial});

  @override
  State<MobileSystemCard> createState() => _MobileSystemCardState();
}

class _MobileSystemCardState extends State<MobileSystemCard>
{
  // Read again on every visit: the system's settings may have changed them.
  @override
  void initState()
  {
    super.initState();

    DeviceNotifications.refresh();
    NotificationKinds.instance.load();
  }

  Future<void> _chooseNotifications(NotificationSwitch state) async
  {
    final MobileChoice<bool>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: kSystemSection,
      title: kNotificationsSettingTitle,
      choices: const [
        MobileChoice(value: true, label: kNotificationsOn),
        MobileChoice(value: false, label: kNotificationsOff),
      ],
      value: state == NotificationSwitch.on,
    );

    if (picked == null || !mounted)
    {
      return;
    }

    if (picked.value)
    {
      await turnMobileNotificationsOn(context);
    }
    else
    {
      await DeviceNotifications.turnOff();
    }
  }

  String _stateLabel(NotificationSwitch state)
  {
    return switch (state)
    {
      NotificationSwitch.on => kNotificationsOn,
      NotificationSwitch.blocked => kNotificationsBlocked,
      _ => kNotificationsOff,
    };
  }

  // Dimmed, not removed, while this device's notifications are off: the rows stay put.
  MobileGlassListRow _kindsRow(bool on)
  {
    final NotificationKinds kinds = NotificationKinds.instance;

    return MobileGlassListRow(
      leading: MobileCardBadge(
        icon: Icons.tune_rounded,
        tint: on ? AppTheme.trialTealDeep : AppTheme.trialTealDeep.withValues(alpha: _offOpacity),
      ),
      title: kNotificationKindsTitle,
      titleStyle: on
          ? null
          : GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppTheme.trialInk.withValues(alpha: _offOpacity),
            ),
      subtitle: Text(
        on
            ? notificationKindsCount(kinds.enabledCount, kinds.choices?.length ?? 0)
            : withoutOrphans(kNotificationKindsTurnOnFirst),
      ),
      trailing: Opacity(opacity: on ? 1 : _offOpacity, child: MobileGlassListRow.chevron()),
      onTap: on ? () => showMobileNotificationKindsSheet(context) : null,
    );
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

        return MobileGlassList(
          indent: _rowLeft + _badgeSize + _rowGap,
          rows: [
            MobileGlassListRow(
              leading: const MobileCardBadge(icon: Icons.school_rounded),
              title: kTutorialTitle,
              subtitle: const Text(kTutorialSubtitle),
              trailing: MobileGlassListRow.chevron(),
              onTap: widget.onTutorial,
            ),
            if (state != NotificationSwitch.unsupported)
              MobileGlassListRow(
                leading: const MobileCardBadge(icon: Icons.notifications_rounded),
                title: kNotificationsSettingTitle,
                subtitle: Text(_stateLabel(state)),
                trailing: MobileGlassListRow.chevron(),
                onTap: () => _chooseNotifications(state),
              ),
            if (hasKinds) _kindsRow(state == NotificationSwitch.on),
          ],
        );
      },
    );
  }
}

// Every menu entry with a tour across the person's roles, in menu order, the own page last.
List<MobileDestination> _sectionsOf(MeResponse user)
{
  final Map<String, MobileDestination> sections = {};

  for (final MobileDestination destination in [
    for (final String role in user.availableRoles)
      ...mobileDestinationsFor(role, hasParentalResponsibility: user.hasParentalResponsibility),
    ...mobileUserDestinationsFor(user.firstName),
  ])
  {
    if (destination.available && kMobileTourSections.contains(destination.slug))
    {
      sections.putIfAbsent(destination.slug, () => destination);
    }
  }

  return sections.values.toList();
}

// Any section may be picked, seen or not: its parts may be partly seen, or all replayed.
Future<void> showMobileTutorialSheet({required BuildContext context, required MeResponse user})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _TutorialSheet(user: user),
  );
}

class _TutorialSheet extends StatefulWidget
{
  final MeResponse user;

  const _TutorialSheet({required this.user});

  @override
  State<_TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<_TutorialSheet>
{
  late final List<MobileDestination> _sections = _sectionsOf(widget.user);

  final Set<String> _chosen = {};

  bool _busy = false;

  void _toggle(String slug)
  {
    setState(()
    {
      if (!_chosen.remove(slug))
      {
        _chosen.add(slug);
      }
    });
  }

  Future<void> _reactivate() async
  {
    if (_busy)
    {
      return;
    }

    if (_chosen.isEmpty)
    {
      MobileNotice.show(context, kTutorialPickASection, error: true);

      return;
    }

    setState(() => _busy = true);

    await resetMobileToursOf(widget.user.taxCode, _chosen);

    if (!mounted)
    {
      return;
    }

    MobileNotice.show(context, tutorialsReactivated(_chosen.length));
    finishMobileSheet(context);
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileSheet(
      eyebrow: kSystemSection,
      title: kTutorialTitle,
      saving: _busy,
      body: [
        const SizedBox(height: 12),
        const MobileSheetText(kTutorialHint),
        const SizedBox(height: 18),
        const MobileSelectGroupHead(title: kTutorialSections),
        const SizedBox(height: 4),
        for (final MobileDestination section in _sections)
          MobileSelectRow(
            title: section.label,
            leading: MobileCardBadge(
              icon: section.icon,
              tint: _chosen.contains(section.slug) ? Colors.white : AppTheme.trialTealDeep,
            ),
            selected: _chosen.contains(section.slug),
            onTap: () => _toggle(section.slug),
          ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: MobileGoldButton(
          label: kTutorialReactivate,
          icon: Icons.replay_rounded,
          busy: _busy,
          onPressed: _reactivate,
        ),
      ),
    );
  }
}
