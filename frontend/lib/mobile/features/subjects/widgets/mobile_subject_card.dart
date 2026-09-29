import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

const EdgeInsets _padding = EdgeInsets.fromLTRB(16, 12, 12, 12);

const double _heldAlpha = MobileGlassPanel.cardAlpha;

// Not held yet: the same glass, thinner.
const double _openAlpha = 0.5;

const double _addSize = 32;

class MobileSubjectCard extends StatelessWidget
{
  // Shared with the removal backdrop, which follows the card's shape.
  static const double radius = 22;

  final String name;
  final String detail;

  final bool held;

  final VoidCallback? onTap;

  // The + takes every programme; the row opens the sheet to pick them, as on desktop.
  final VoidCallback? onAdd;

  const MobileSubjectCard({
    super.key,
    required this.name,
    required this.detail,
    required this.held,
    this.onTap,
    this.onAdd,
  });

  Widget _buildTrailing()
  {
    if (held)
    {
      return onTap == null
          ? const SizedBox.shrink()
          : Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: AppTheme.trialInk.withValues(alpha: 0.36),
            );
    }

    if (onAdd == null)
    {
      return const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      label: 'Tutti i percorsi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onAdd,
        child: Container(
          width: _addSize,
          height: _addSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.trialGoldSurface,
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: 0.6), width: 1.5),
          ),
          child: const Icon(Icons.add_rounded, size: 19, color: AppTheme.modifiedAccent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MobileGlassPanel(
        padding: _padding,
        borderRadius: BorderRadius.circular(radius),
        whiteAlpha: held ? _heldAlpha : _openAlpha,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildTrailing(),
          ],
        ),
      ),
    );
  }
}
