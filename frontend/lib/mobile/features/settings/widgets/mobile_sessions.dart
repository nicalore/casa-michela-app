import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart';
import '../../../../features/settings/models/session_item.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_glass_list.dart';

const double _iconSize = 24;
const double _rowLeft = 18;
const double _rowGap = 15;

const double _badgeSize = 58;

class MobileSessionList extends StatelessWidget
{
  final List<SessionItem> sessions;
  final ValueChanged<SessionItem> onOpen;

  const MobileSessionList({super.key, required this.sessions, required this.onOpen});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassList(
      indent: _rowLeft + _iconSize + _rowGap,
      rows: [
        for (final session in sessions)
          MobileGlassListRow(
            padding: const EdgeInsets.fromLTRB(_rowLeft, 10, 10, 10),
            gap: _rowGap,
            minHeight: 68,
            leading: Icon(sessionDeviceIcon(session.deviceType), size: _iconSize, color: AppTheme.trialTealDeep),
            title: sessionDeviceName(session),
            titleStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppTheme.trialInk,
            ),
            subtitle: session.isCurrent
                ? const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: MobilePill(kCurrentSessionLabel, tone: MobilePillTone.teal),
                  )
                : Text('$kSessionLastUsedLabel: ${formatSessionTime(session.lastUsedAt)}'),
            trailing: MobileGlassListRow.chevron(),
            onTap: () => onOpen(session),
          ),
      ],
    );
  }
}

Future<void> showMobileSessionSheet({
  required BuildContext context,
  required SessionItem session,
  required Future<void> Function(BuildContext sheet) onRevoke,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: kSessionEyebrow,
      title: sessionDeviceName(session),
      leading: _DeviceBadge(session.deviceType),
      body: [
        const SizedBox(height: 18),
        if (session.isCurrent) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: MobilePill(kCurrentSessionLabel, tone: MobilePillTone.teal),
          ),
          const SizedBox(height: 12),
        ],
        MobileSheetCard(
          child: MobileDetailRows(
            rows: [
              DetailRowData(kSessionLoginLabel, formatSessionTime(session.loggedInAt)),
              DetailRowData(kSessionLastUsedLabel, formatSessionTime(session.lastUsedAt)),
            ],
          ),
        ),
      ],
      footer: session.isCurrent
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 22),
              child: MobileDangerButton(
                label: kRevokeSessionLabel,
                icon: Icons.logout_rounded,
                onPressed: () => onRevoke(context),
              ),
            ),
    ),
  );
}

class _DeviceBadge extends StatelessWidget
{
  final SessionDeviceType type;

  const _DeviceBadge(this.type);

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.trialTealDeep.withValues(alpha: 0.13),
      ),
      child: Icon(sessionDeviceIcon(type), size: 30, color: AppTheme.trialTealDeep),
    );
  }
}
