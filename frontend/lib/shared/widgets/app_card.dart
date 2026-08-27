import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';

const double _badgeSize = 90;
const double _cardPadding = 32;
const double _cardRadius = 40;

const double _compactBadgeSize = 64;
const double _compactCardPadding = 26;
const double _compactCardRadius = 32;

const double _dividerSpace = 24;
const double _compactDividerSpace = 20;

const double _headingGap = 16;

enum AppCardTrailing
{
  beside,
  wrapping,
}

class AppCard extends StatelessWidget
{
  final String title;

  final Widget leading;

  final Widget child;

  final Widget? trailing;

  final AppCardTrailing trailingFit;

  final bool compact;

  final bool selectable;

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
    final Widget labelText = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      ),
    );

    final Widget valueBody = valueWidget ??
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialInk,
            letterSpacing: valueLetterSpacing,
          ),
        );

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
        SizedBox(width: labelWidth, child: labelText),
        Expanded(child: valueBody),
        ?trailing,
      ],
    );
  }
}
