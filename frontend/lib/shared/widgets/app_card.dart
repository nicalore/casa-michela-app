import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
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

// Between the title and the controls beside it, and between the two rows they
// make when they do not fit on one.
const double _headingGap = 16;

// The two ways a card's own controls can share the heading with its title, and
// the caller is the one that knows which it wants.
//
// A card that has already worked out there is room for them wants them beside
// the title, with the title giving way: the week nav of the opening hours moves
// down into the body on its own, at its own width, and would not have handed
// them over here otherwise.
//
// A card whose controls are a handful of filter pills has no such number to lean
// on — three of them can be wider than the whole card — so there they take a
// line of their own the moment they do not fit on this one.
enum AppCardTrailing
{
  beside,
  wrapping,
}

// The chrome every card of the app wears: a badge, a heading beside it and a
// rule under the two. The white, the radius and the shadow are the same the
// dashboard gives its module cards, so a card here and a card there read as the
// same object.
class AppCard extends StatelessWidget
{
  final String title;

  // Usually a AppCardBadge, but the identity card puts the profile picture
  // here instead, which is why this is a widget and not an icon.
  final Widget leading;

  final Widget child;

  // Controls belonging to the heading rather than to the body: the week the
  // opening-hours table is showing, the filters a chart is drawn under. Left
  // out, the heading is the title alone.
  final Widget? trailing;

  final AppCardTrailing trailingFit;

  // Set on a card carrying only a couple of values, which then wears a smaller
  // badge, a smaller heading and less padding. Pass it to AppCardBadge as
  // well, or the badge and the space kept for it disagree.
  final bool compact;

  // The statistics cards turn this off. Their figures stand under charts that
  // are hovered and dragged across, and a drag that begins on a chart must not
  // come back with half the card highlighted.
  final bool selectable;

  // Set by a card whose height is decided elsewhere — two cards matched to the
  // same height, a table pinned to a fixed one. The body then spreads into the
  // height it was handed instead of leaving a hole under itself, while the
  // heading stays where the other card's heading is.
  //
  // Only pass it where the height really is given: a card free to be as tall as
  // it likes has no room to spread into and the flex would have nothing to
  // measure against.
  final bool fillHeight;

  const AppCard({
    super.key,
    required this.title,
    required this.leading,
    required this.child,
    this.trailing,
    this.trailingFit = AppCardTrailing.beside,
    this.compact = false,
    this.selectable = true,
    this.fillHeight = false,
  });

  Widget _buildTitle()
  {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: compact ? 21 : 26,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
        height: 1.1,
      ),
    );
  }

  // Nothing in here measures itself. That is a requirement, not a preference:
  // matching two cards to the same height means asking each of them how tall it
  // would be at a given width, and a LayoutBuilder cannot answer that question
  // at all.
  Widget _buildHeader(double badgeSize)
  {
    if (trailing == null || trailingFit == AppCardTrailing.beside)
    {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: badgeSize),
        child: Row(
          children: [
            leading,
            SizedBox(width: compact ? 18 : 24),
            Expanded(child: _buildTitle()),
            if (trailing != null) ...[
              const SizedBox(width: _headingGap),
              trailing!,
            ],
          ],
        ),
      );
    }

    // A Wrap is what turns "beside the title, or under it" into a matter of fit
    // rather than of a number: a breakpoint would have to be guessed for every
    // card, and these run from a third of the page to all of it.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _headingGap,
      runSpacing: _headingGap,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: badgeSize),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              SizedBox(width: compact ? 18 : 24),
              Flexible(child: _buildTitle()),
            ],
          ),
        ),
        trailing!,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double badgeSize = compact ? _compactBadgeSize : _badgeSize;

    final Widget body = fillHeight
        ? Expanded(child: Align(alignment: Alignment.centerLeft, child: child))
        : child;

    final Widget card = Container(
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
          _buildHeader(badgeSize),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? _compactDividerSpace : _dividerSpace,
            ),
            child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
          ),
          body,
        ],
      ),
    );

    return selectable ? SelectionArea(child: card) : card;
  }
}

// The card's badge: the brand ramp with the icon reversed out of it, the same
// mark the module cards on the dashboard carry, only larger.
class AppCardBadge extends StatelessWidget
{
  final IconData icon;

  final bool compact;

  const AppCardBadge({super.key, required this.icon, this.compact = false});

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
class AppInfoRow extends StatelessWidget
{
  final String label;
  final String value;
  final double labelWidth;

  // Spreads the characters of a masked value, so a row of bullets does not read
  // as one long word.
  final double valueLetterSpacing;

  final Widget? trailing;

  const AppInfoRow({
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
    final Widget labelText = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      ),
    );

    // On a narrow window the label goes above the value instead of beside it.
    // A hundred and sixty pixels of label out of the two hundred and ninety a
    // phone has left inside a card is most of the row spent naming the thing,
    // and a tax code broken over two lines to fit what was left.
    if (AppBreakpoints.of(context).isCompact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelText,
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: trailing == null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(width: labelWidth, child: labelText),
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
