import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double _badgeSize = 90;
const double _cardPadding = 32;
const double _cardRadius = 40;

// A card holding two or three values does not need the chrome of one holding
// eight: the badge and the heading come down a size and the padding with them,
// so a short card reads as compact rather than as mostly empty.
const double _compactBadgeSize = 64;
const double _compactCardPadding = 26;
const double _compactCardRadius = 32;

// Rule under the heading. Barely there on purpose: it separates the title from
// the values without drawing a line across the card.
const double _dividerSpace = 24;
const double _compactDividerSpace = 20;

// The chrome every card in the settings wears: a badge, a heading beside it and
// a rule under the two. The white, the radius and the shadow are the same the
// dashboard gives its module cards, so a card here and a card there read as the
// same object.
class SettingsCard extends StatelessWidget
{
  final String title;

  // Usually a SettingsCardBadge, but the identity card puts the profile picture
  // here instead, which is why this is a widget and not an icon.
  final Widget leading;

  final Widget child;

  // Set on a card carrying only a couple of values, which then wears a smaller
  // badge, a smaller heading and less padding. Pass it to SettingsCardBadge as
  // well, or the badge and the space kept for it disagree.
  final bool compact;

  const SettingsCard({
    super.key,
    required this.title,
    required this.leading,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final double badgeSize = compact ? _compactBadgeSize : _badgeSize;

    return SelectionArea(
      child: Container(
        padding: EdgeInsets.all(compact ? _compactCardPadding : _cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? _compactCardRadius : _cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: badgeSize,
              child: Row(
                children: [
                  leading,
                  SizedBox(width: compact ? 18 : 24),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: compact ? 21 : 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: compact ? _compactDividerSpace : _dividerSpace,
              ),
              child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// The card's badge: the brand ramp with the icon reversed out of it, the same
// mark the module cards on the dashboard carry, only larger.
class SettingsCardBadge extends StatelessWidget
{
  final IconData icon;

  final bool compact;

  const SettingsCardBadge({super.key, required this.icon, this.compact = false});

  @override
  Widget build(BuildContext context)
  {
    final double size = compact ? _compactBadgeSize : _badgeSize;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: compact ? 30 : 42, color: Colors.white),
    );
  }
}

// One value in a settings card: what it is on the left, what it says on the
// right. The label is muted and the value is not, so a column of these reads as
// values with names attached rather than as a table.
class SettingsInfoRow extends StatelessWidget
{
  final String label;
  final String value;
  final double labelWidth;

  // Spreads the characters of a masked value, so a row of bullets does not read
  // as one long word.
  final double valueLetterSpacing;

  final Widget? trailing;

  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.labelWidth,
    this.valueLetterSpacing = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: trailing == null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialInk,
              letterSpacing: valueLetterSpacing,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
