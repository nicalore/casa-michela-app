import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/page_density.dart';
import '../models/session_item.dart';
import '../utils/settings_strings.dart';
import 'session_card.dart';
import 'settings_panel.dart';

const double _heroRadius = 28;
const double _heroTile = 76;

const double _cardRadius = 22;

// Below the wide window (AppPageDensity).
const double _denseHeroRadius = 20;
const double _denseHeroTile = 40;
const double _denseCardRadius = 18;

TextStyle _detailStyle({bool dense = false}) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 12.5 : 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: AppTheme.trialMutedText,
    );

String _details(SessionItem session)
{
  return '$kSessionLoginLabel: ${formatSessionTime(session.loggedInAt)}\n'
      '$kSessionLastUsedLabel: ${formatSessionTime(session.lastUsedAt)}';
}

BoxDecoration _cardDecoration(double radius)
{
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: AppTheme.cardShadow,
  );
}

class CurrentSessionCard extends StatelessWidget
{
  final SessionItem session;

  const CurrentSessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final double tile = dense ? _denseHeroTile : _heroTile;

    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: _cardDecoration(dense ? _denseHeroRadius : _heroRadius),
      child: Row(
        children: [
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: AppTheme.trialTealDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(dense ? 12 : 22),
            ),
            child: Icon(sessionDeviceIcon(session.deviceType), size: dense ? 22 : 40, color: AppTheme.trialTealDeep),
          ),
          SizedBox(width: dense ? 12 : 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverflowTooltipText(
                  text: sessionDeviceName(session),
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: dense ? 16 : 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
                SizedBox(height: dense ? 2 : 4),
                Text(_details(session), style: _detailStyle(dense: dense)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const CurrentSessionChip(),
        ],
      ),
    );
  }
}

// Another session: its revoke button shows under the pointer.
class OtherSessionCard extends StatefulWidget
{
  final SessionItem session;
  final bool busy;
  final VoidCallback onRevoke;

  const OtherSessionCard({super.key, required this.session, required this.busy, required this.onRevoke});

  @override
  State<OtherSessionCard> createState() => _OtherSessionCardState();
}

class _OtherSessionCardState extends State<OtherSessionCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final SessionItem session = widget.session;
    final bool dense = AppPageDensity.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: dense ? const EdgeInsets.fromLTRB(16, 12, 12, 12) : const EdgeInsets.fromLTRB(20, 18, 14, 18),
        decoration: _cardDecoration(dense ? _denseCardRadius : _cardRadius),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsIconTile(icon: sessionDeviceIcon(session.deviceType)),
            SizedBox(width: dense ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OverflowTooltipText(
                    text: sessionDeviceName(session),
                    maxLines: 1,
                    style: settingsTitleStyle(dense: dense),
                  ),
                  const SizedBox(height: 2),
                  Text(_details(session), style: _detailStyle(dense: dense)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SessionRevokeIcon(visible: _hover || widget.busy, busy: widget.busy, onTap: widget.onRevoke),
          ],
        ),
      ),
    );
  }
}
