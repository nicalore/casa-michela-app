import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../accounting/models/volunteering_rule.dart';
import '../utils/compensation_strings.dart';

const Duration _frameFade = Duration(milliseconds: 150);
const double _frameWidth = 1.5;

// The month's rule for the unpaid hour, on the line of the month; a click changes it.
class VolunteeringPill extends StatefulWidget
{
  final VolunteeringRule rule;

  // The month, when the monthly summary chose its rule for it alone.
  final DateTime? monthOnly;

  final bool dense;
  final VoidCallback onTap;

  const VolunteeringPill({
    super.key,
    required this.rule,
    required this.dense,
    required this.onTap,
    this.monthOnly,
  });

  @override
  State<VolunteeringPill> createState() => _VolunteeringPillState();
}

class _VolunteeringPillState extends State<VolunteeringPill>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool dense = widget.dense;
    final double height = dense ? 40 : 50;
    final DateTime? monthOnly = widget.monthOnly;

    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kVolunteeringLabel.toUpperCase(),
          maxLines: 1,
          style: PageHeading.style().copyWith(fontSize: dense ? 9.5 : 10.5, letterSpacing: 1.4),
        ),
        Text.rich(
          TextSpan(
            text: kVolunteeringRuleNames[widget.rule],
            children: [
              if (monthOnly != null)
                TextSpan(
                  text: ' (${volunteeringMonthOnlyNote(monthOnly)})',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
                ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 13.5 : 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialOceanText,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _hover ? 1 : 0),
            duration: _frameFade,
            curve: Curves.easeOut,
            builder: (context, lit, child) => Container(
              constraints: BoxConstraints(minHeight: height),
              padding: EdgeInsets.fromLTRB(dense ? 12 : 14, 4, dense ? 14 : 16, 4),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _frameWidth),
              ),
              foregroundDecoration: AppTheme.cardEdge(height / 2, strength: 1 - lit),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volunteer_activism_rounded, size: dense ? 18 : 20, color: AppTheme.trialTealDeepText),
                SizedBox(width: dense ? 10 : 12),
                Flexible(child: text),
                SizedBox(width: dense ? 12 : 16),
                Icon(Icons.edit_rounded, size: dense ? 15 : 17, color: AppTheme.trialTealDeepText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
