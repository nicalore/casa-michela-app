import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import 'page_density.dart';

const double _badgeSize = 90;
const double _cardPadding = 32;
const double _cardRadius = 40;

const double _compactBadgeSize = 64;
const double _smallBadgeSize = 40;
const double _denseBadgeSize = 32;
const double _compactCardPadding = 26;
const double _compactCardRadius = 32;

const double _dividerSpace = 24;
const double _compactDividerSpace = 20;

const double _headingGap = 16;

// Inside a dense page (AppPageDensity).
const double _pageBadgeSize = 36;
const double _pageBadgeIcon = 19;
const double _pageTitleSize = 17;
const double _pageCardRadius = 24;
const EdgeInsets _pageCardPadding = EdgeInsets.fromLTRB(20, 16, 20, 18);
const double _pageDividerSpace = 13;
const double _pageHeadingGap = 12;
const double _pageRowSize = 14.5;
const double _pageLabelShare = 0.8;

enum AppCardTrailing
{
  beside,
  wrapping,
  // At the end of the title's line while it fits there, else under the title (a score).
  endOrBelow,
}

class AppCard extends StatelessWidget
{
  final String title;

  final Widget leading;

  // Null: the header is the whole card, with no divider under it.
  final Widget? child;

  final Widget? trailing;

  final AppCardTrailing trailingFit;

  final bool compact;

  final bool selectable;

  final bool fillHeight;

  const AppCard({
    super.key,
    required this.title,
    required this.leading,
    this.child,
    this.trailing,
    this.trailingFit = AppCardTrailing.beside,
    this.compact = false,
    this.selectable = true,
    this.fillHeight = false,
  });

  Widget _buildTitle(bool dense)
  {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? _pageTitleSize : (compact ? 21 : 26),
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
        height: 1.1,
      ),
    );
  }

  Widget _buildHeader(double badgeSize, bool dense)
  {
    final double leadingGap = dense ? _pageHeadingGap : (compact ? 18 : 24);

    if (trailing == null || trailingFit == AppCardTrailing.beside)
    {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: badgeSize),
        child: Row(
          children: [
            leading,
            SizedBox(width: leadingGap),
            Expanded(child: _buildTitle(dense)),
            if (trailing != null) ...[
              const SizedBox(width: _headingGap),
              trailing!,
            ],
          ],
        ),
      );
    }

    final Widget wrap = Wrap(
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
              SizedBox(width: leadingGap),
              Flexible(child: _buildTitle(dense)),
            ],
          ),
        ),
        trailing!,
      ],
    );

    // As wide as the card, so a trailing that fits is pushed to the end of the line.
    return trailingFit == AppCardTrailing.endOrBelow ? SizedBox(width: double.infinity, child: wrap) : wrap;
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = !compact && AppPageDensity.of(context);
    final double badgeSize = dense ? _pageBadgeSize : (compact ? _compactBadgeSize : _badgeSize);

    final Widget? body = switch (child)
    {
      null => null,
      final child when fillHeight =>
        Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
      final child => child,
    };

    final Widget card = Container(
      padding: dense ? _pageCardPadding : EdgeInsets.all(compact ? _compactCardPadding : _cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dense ? _pageCardRadius : (compact ? _compactCardRadius : _cardRadius)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(badgeSize, dense),
          if (body != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: dense ? _pageDividerSpace : (compact ? _compactDividerSpace : _dividerSpace),
              ),
              child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            ),
            body,
          ],
        ],
      ),
    );

    return selectable ? SelectionArea(child: card) : card;
  }
}

class AppCardBadge extends StatelessWidget
{
  final IconData icon;

  final bool compact;

  // The home cards' header.
  final bool small;

  // The home cards' header below the wide window.
  final bool dense;

  const AppCardBadge({super.key, required this.icon, this.compact = false, this.small = false, this.dense = false});

  @override
  Widget build(BuildContext context)
  {
    if (dense)
    {
      return Container(
        width: _denseBadgeSize,
        height: _denseBadgeSize,
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: Colors.white),
      );
    }

    final bool page = !small && !compact && AppPageDensity.of(context);
    final double size = page ? _pageBadgeSize : (small ? _smallBadgeSize : compact ? _compactBadgeSize : _badgeSize);

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: page ? _pageBadgeIcon : (small ? 21 : compact ? 30 : 42), color: Colors.white),
    );
  }
}

class AppInfoRow extends StatelessWidget
{
  final String label;
  final String value;
  final double labelWidth;

  final double valueLetterSpacing;

  final Widget? trailing;

  final Widget? valueWidget;

  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.labelWidth,
    this.valueLetterSpacing = 0,
    this.trailing,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    // Label over value: smaller cards keep them side by side down to the minimal window.
    final AppWindowSize size = AppBreakpoints.of(context);
    final bool narrow = dense ? size.isMinimal : size.isNarrow;

    final Widget labelText = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? (narrow ? 12.5 : _pageRowSize) : 18,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      ),
    );

    final Widget valueBody = valueWidget ??
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? _pageRowSize : 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialInk,
            letterSpacing: valueLetterSpacing,
          ),
        );

    if (narrow)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelText,
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: valueBody),
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
        SizedBox(width: dense ? labelWidth * _pageLabelShare : labelWidth, child: labelText),
        Expanded(child: valueBody),
        ?trailing,
      ],
    );
  }
}
