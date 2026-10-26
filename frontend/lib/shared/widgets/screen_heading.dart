import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import 'app_back_button.dart';

const double _afterBack = 16;
const double _afterTitle = 14;
const double _countBelow = 6;
const double _trailingBelow = 10;

// Below the wide window a screen of the user menu leads with one line: back, title, count, a filter.
class ScreenHeading extends StatelessWidget
{
  final String title;

  // Null: no count to show; empty keeps its room while it loads.
  final String? count;

  final Widget? trailing;

  final String backTooltip;
  final VoidCallback onBack;

  const ScreenHeading({
    super.key,
    required this.title,
    required this.backTooltip,
    required this.onBack,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? count = this.count;
    final Widget? trailing = this.trailing;

    final Widget back = AppBackButton(tooltip: backTooltip, onTap: onBack, dense: true);

    final Widget words = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
    );

    final Widget? counted = count == null
        ? null
        : Text(
            count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
          );

    if (AppBreakpoints.of(context).isMinimal)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              back,
              const SizedBox(width: _afterBack),
              Expanded(child: words),
            ],
          ),
          if (counted != null) ...[
            const SizedBox(height: _countBelow),
            counted,
          ],
          if (trailing != null) ...[
            const SizedBox(height: _trailingBelow),
            trailing,
          ],
        ],
      );
    }

    return Row(
      children: [
        back,
        const SizedBox(width: _afterBack),
        words,
        const SizedBox(width: _afterTitle),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: counted ?? const SizedBox.shrink(),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: _afterTitle),
          trailing,
        ],
      ],
    );
  }
}
