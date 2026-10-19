import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_action_circle.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_tour.dart';

const EdgeInsets _padding = EdgeInsets.fromLTRB(16, 12, 12, 12);

// As the availability day card's round button on a phone.
const double _addSize = 36;

const EdgeInsets _tourAddInflate = EdgeInsets.all(5);

// Also drawn in a tour's text, where a larger [iconShare] keeps it legible.
Widget mobileSubjectAddCircle(double size, {double iconShare = 23 / 36})
{
  return MobileActionCircle(icon: Icons.add_rounded, size: size, iconSize: size * iconShare);
}

class MobileSubjectCard extends StatelessWidget
{
  // Shared with the removal backdrop, which follows the card's shape.
  static const double radius = 22;

  final String name;
  final String detail;

  final bool held;

  final VoidCallback? onTap;

  // The + takes every programme; the row opens the sheet to pick them.
  final VoidCallback? onAdd;

  final String? addTourId;

  const MobileSubjectCard({
    super.key,
    required this.name,
    required this.detail,
    required this.held,
    this.onTap,
    this.onAdd,
    this.addTourId,
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

    return MobileTourTarget(
      id: addTourId,
      inflate: _tourAddInflate,
      radius: _addSize / 2 + _tourAddInflate.left,
      child: Semantics(
        button: true,
        label: 'Tutti i percorsi',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
          child: mobileSubjectAddCircle(_addSize),
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
