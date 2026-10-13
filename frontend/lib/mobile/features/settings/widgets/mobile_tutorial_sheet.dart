import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/models/me_response.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../shared/navigation/mobile_destinations.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_glass_list.dart';

const double _badgeSize = 34;
const double _rowLeft = 14;
const double _rowGap = 13;

// The notifications will join the tutorial here.
class MobileSystemCard extends StatelessWidget
{
  final VoidCallback onTutorial;

  const MobileSystemCard({super.key, required this.onTutorial});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassList(
      indent: _rowLeft + _badgeSize + _rowGap,
      rows: [
        MobileGlassListRow(
          leading: const MobileCardBadge(icon: Icons.school_rounded),
          title: kTutorialTitle,
          subtitle: const Text(kTutorialSubtitle),
          trailing: MobileGlassListRow.chevron(),
          onTap: onTutorial,
        ),
      ],
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

// Any section may be chosen, its tours seen or not: a part may be seen and another not, or all wanted again.
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
