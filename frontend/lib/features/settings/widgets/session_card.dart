import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/session_item.dart';
import '../utils/settings_strings.dart';

const double kSessionCardWidth = 328;
const double kSessionCardGap = 20;

const double _cardHeight = 224;
const double _cardRadius = 26;
const int _maxColumns = 4;

const double _badgeSize = 50;

const double _revokeSize = 36;
const Duration _hoverFade = Duration(milliseconds: 150);

int sessionGridColumns(double maxWidth, double cardWidth, int count)
{
  return ((maxWidth + kSessionCardGap) / (cardWidth + kSessionCardGap))
      .floor()
      .clamp(1, math.max(1, math.min(_maxColumns, count)));
}

class SessionCard extends StatefulWidget
{
  final SessionItem session;

  final double width;

  final bool busy;

  final VoidCallback onRevoke;

  const SessionCard({
    super.key,
    required this.session,
    required this.width,
    required this.busy,
    required this.onRevoke,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final SessionItem session = widget.session;

    final TextStyle detailStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AppTheme.trialMutedText,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      // One height for every card, so rows line up and the content sits centred.
      child: Container(
        width: widget.width,
        height: _cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DeviceBadge(session.deviceType),
                    const SizedBox(height: 12),
                    OverflowTooltipText(
                      text: sessionDeviceName(session),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in [
                      '$kSessionLoginLabel: ${formatSessionTime(session.loggedInAt)}',
                      '$kSessionLastUsedLabel: ${formatSessionTime(session.lastUsedAt)}',
                    ])
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(line, maxLines: 1, style: detailStyle),
                      ),
                    if (session.isCurrent) ...[
                      const SizedBox(height: 12),
                      const _CurrentSessionChip(),
                    ],
                  ],
                ),
              ),
            ),
            if (!session.isCurrent)
              Positioned(
                top: 12,
                right: 12,
                child: _RevokeIcon(
                  visible: _hover || widget.busy,
                  busy: widget.busy,
                  onTap: widget.onRevoke,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
      child: Icon(sessionDeviceIcon(type), size: 26, color: AppTheme.trialTealDeep),
    );
  }
}

// Keeps its size while hidden so nothing shifts on hover.
class _RevokeIcon extends StatefulWidget
{
  final bool visible;

  final bool busy;

  final VoidCallback onTap;

  const _RevokeIcon({
    required this.visible,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_RevokeIcon> createState() => _RevokeIconState();
}

class _RevokeIconState extends State<_RevokeIcon>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final Widget face = widget.busy
        ? const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.trialDanger),
            ),
          )
        : const Icon(Icons.logout_rounded, size: 20, color: AppTheme.trialDanger);

    return IgnorePointer(
      ignoring: !widget.visible || widget.busy,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: _hoverFade,
        child: Tooltip(
          message: kRevokeSessionLabel,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: _hoverFade,
                width: _revokeSize,
                height: _revokeSize,
                decoration: BoxDecoration(
                  color: _hover && !widget.busy
                      ? AppTheme.trialGoldSurface
                      : AppTheme.trialGoldSurface.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentSessionChip extends StatelessWidget
{
  const _CurrentSessionChip();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.trialTurquoise, width: 1.5),
      ),
      child: Text(
        kCurrentSessionLabel,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}
