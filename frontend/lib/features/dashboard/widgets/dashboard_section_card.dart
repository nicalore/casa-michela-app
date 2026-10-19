import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/descender_room.dart';

class DashboardSectionCard extends StatelessWidget
{
  static const double radius = 28;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(28, 24, 28, 26);

  static const EdgeInsets badgedPadding = EdgeInsets.fromLTRB(22, 14, 22, 16);

  static const EdgeInsets _compactPadding = EdgeInsets.fromLTRB(22, 20, 22, 20);

  final String eyebrow;
  final String title;
  final Widget child;

  final Widget? action;

  // Given: a badge and the title replace the eyebrow, with a rule under them.
  final IconData? icon;

  final double minHeight;

  // True inside a row, where the tallest card sets the height; false in a column.
  final bool fill;

  final bool compact;

  const DashboardSectionCard({
    super.key,
    this.eyebrow = '',
    required this.title,
    required this.child,
    this.action,
    this.icon,
    this.minHeight = 0,
    this.fill = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final IconData? icon = this.icon;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: icon != null ? badgedPadding : compact ? _compactPadding : padding,
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              _badgedHead(icon),
              const SizedBox(height: 10),
              Container(height: 1, color: AppTheme.trialLine),
              const SizedBox(height: 12),
            ] else ...[
              _plainHead(),
              SizedBox(height: compact ? 14 : 20),
            ],
            if (fill) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }

  Widget _badgedHead(IconData icon)
  {
    return Row(
      children: [
        AppCardBadge(icon: icon, small: true),
        const SizedBox(width: 12),
        Expanded(
          child: DescenderRoom(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppTheme.trialOcean,
              ),
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 16),
          action!,
        ],
      ],
    );
  }

  Widget _plainHead()
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  height: 1.2,
                  color: AppTheme.trialMutedText,
                ),
              ),
              SizedBox(height: compact ? 2 : 3),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: compact ? 18 : 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppTheme.trialOcean,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 16),
          action!,
        ],
      ],
    );
  }
}

class DashboardCardNote extends StatelessWidget
{
  final String text;

  const DashboardCardNote(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      maxLines: 1,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialMutedText,
      ),
    );
  }
}

class DashboardComingSoon extends StatelessWidget
{
  final IconData icon;
  final String description;

  const DashboardComingSoon({
    super.key,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: AppTheme.trialTealDeep),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In arrivo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
