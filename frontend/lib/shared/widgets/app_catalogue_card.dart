import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import 'app_field_label.dart';
import 'overflow_tooltip_text.dart';

class CatalogueDetail
{
  final String text;
  final Color color;

  const CatalogueDetail(this.text, {this.color = AppTheme.trialMutedText});
}

class AppCatalogueCard extends StatefulWidget
{
  static const double radius = 30;

  static const double height = 100;

  static const int lineBudget = 3;

  static const double lineHeight = 1.25;

  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);

  // Below the wide window: two lines, the title and the first detail or the eyebrow.
  static const double denseHeight = 68;
  static const double denseRadius = 20;
  static const int denseLineBudget = 2;
  static const EdgeInsets densePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  final String? eyebrow;

  final String title;

  final List<CatalogueDetail> details;

  final VoidCallback? onTap;

  const AppCatalogueCard({
    super.key,
    this.eyebrow,
    required this.title,
    this.details = const [],
    this.onTap,
  });

  @override
  State<AppCatalogueCard> createState() => _AppCatalogueCardState();
}

class _AppCatalogueCardState extends State<AppCatalogueCard>
{
  bool _isHovering = false;

  bool get _isPressable => widget.onTap != null;

  int _titleLines(List<CatalogueDetail> details, int budget)
  {
    final String? eyebrow = widget.eyebrow;
    final int taken =
        (eyebrow != null && eyebrow.isNotEmpty ? 1 : 0) + details.length;

    return (budget - taken).clamp(1, budget);
  }

  @override
  Widget build(BuildContext context)
  {
    final String? eyebrow = widget.eyebrow;
    final bool dense = AppBreakpoints.of(context).isDense;
    final bool eyebrowShown = eyebrow != null && eyebrow.isNotEmpty;

    // The rest is in the details the card opens.
    final List<CatalogueDetail> details = dense
        ? widget.details.take(eyebrowShown ? 0 : 1).toList()
        : widget.details;

    final int budget = dense ? AppCatalogueCard.denseLineBudget : AppCatalogueCard.lineBudget;

    return MouseRegion(
      cursor: _isPressable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovering = _isPressable),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Only the hover border fades: an animated size lets the content spill out on a resize.
        child: SizedBox(
          height: dense ? AppCatalogueCard.denseHeight : AppCatalogueCard.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dense ? AppCatalogueCard.denseRadius : AppCatalogueCard.radius),
              border: Border.all(
                color: _isHovering
                    ? AppTheme.trialGold
                    : AppTheme.trialGold.withValues(alpha: 0),
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Padding(
              padding: dense ? AppCatalogueCard.densePadding : AppCatalogueCard.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrowShown) ...[
                    OverflowTooltipText(
                      text: eyebrow.toUpperCase(),
                      maxLines: 1,
                      style: eyebrowTextStyle().copyWith(
                        height: AppCatalogueCard.lineHeight,
                        fontSize: dense ? 9.5 : null,
                        letterSpacing: dense ? 1.2 : null,
                      ),
                    ),
                    SizedBox(height: dense ? 2 : 4),
                  ],
                  OverflowTooltipText(
                    text: widget.title,
                    maxLines: _titleLines(details, budget),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: dense ? 15.5 : 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialOcean,
                      height: 1.15,
                    ),
                  ),
                  for (final detail in details) ...[
                    SizedBox(height: dense ? 3 : 4),
                    OverflowTooltipText(
                      text: detail.text,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: dense ? 12.5 : 14,
                        fontWeight: FontWeight.w500,
                        height: AppCatalogueCard.lineHeight,
                        color: detail.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
