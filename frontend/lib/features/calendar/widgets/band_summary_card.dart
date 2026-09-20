import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

String countOf(int value, String singular, String plural)
{
  return '$value ${value == 1 ? singular : plural}';
}

class BandSummaryCard extends StatelessWidget
{
  final String? eyebrow;

  final String title;
  final String? summary;
  final List<Widget> chips;

  final bool compact;

  const BandSummaryCard({
    super.key,
    this.eyebrow,
    required this.title,
    this.summary,
    this.chips = const [],
    this.compact = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final eyebrow = this.eyebrow;
    final summary = this.summary;

    return Container(
      padding: compact ? const EdgeInsets.fromLTRB(18, 16, 18, 14) : const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: AppTheme.trialMutedText,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: compact ? 17 : 21,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              style: GoogleFonts.plusJakartaSans(
                fontSize: compact ? 13.5 : 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppTheme.trialMutedText,
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            SizedBox(height: compact ? 12 : 16),
            const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            SizedBox(height: compact ? 12 : 16),
            Wrap(spacing: 10, runSpacing: 10, children: chips),
          ],
        ],
      ),
    );
  }
}

class BandChip extends StatelessWidget
{
  final IconData icon;
  final String label;
  final String? detail;

  final Color accent;
  final Color? surface;

  final bool filled;

  const BandChip({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    required this.accent,
    this.surface,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final foreground = filled ? Colors.white : accent;

    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
      decoration: BoxDecoration(
        color: filled ? accent : surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? accent : accent.withValues(alpha: 0.3), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          if (detail != null)
            Text(
              ' · $detail',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white.withValues(alpha: 0.8) : AppTheme.trialMutedText,
              ),
            ),
        ],
      ),
    );
  }
}
