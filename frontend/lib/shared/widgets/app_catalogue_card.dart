import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_field_label.dart';
import 'overflow_tooltip_text.dart';

// One line of what is said under an entry's name. One line for real: the card
// holds three in total, and whatever does not fit is ellipsized. The colour is
// the caller's call — a ministry subject's level is an accent, a description is
// grey.
class CatalogueDetail
{
  final String text;
  final Color color;

  const CatalogueDetail(this.text, {this.color = AppTheme.trialMutedText});
}

// The card a catalogue names one of its entries with: a discipline, a ministry
// subject, a study programme, a school, a service.
//
// The name is what the card is looked at for, so it takes whatever lines the
// others leave unused. All cards keep the same height, because one that grows
// with its contents leaves holes at the end of the grid rows; the price is that
// what does not fit is ellipsized, and spelled out in full on hover.
class AppCatalogueCard extends StatefulWidget
{
  static const double radius = 30;

  static const double height = 100;

  // Three lines fit, and only just: the vertical padding is 14 rather than 16
  // for that reason, and every line carries the line height spelled out below
  // instead of the theme's, which would overflow the card by two pixels.
  static const int lineBudget = 3;

  static const double lineHeight = 1.25;

  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);

  // The small tracked line above the name, where something precedes it: the
  // sector of a study programme, which says which family it belongs to.
  final String? eyebrow;

  final String title;

  final List<CatalogueDetail> details;

  // What pressing it opens. Null where nothing opens, and then the card does
  // not light up under the pointer: gold in this app means "this can be pressed".
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

  // How many lines are left to the name: those the eyebrow and the details do
  // not take, and at least one anyway. A count and not a measurement — measuring
  // the real height of every text would give the same answer with many more ways
  // to get it wrong, and the two fonts in play would not agree on the number.
  int get _titleLines
  {
    final String? eyebrow = widget.eyebrow;
    final int taken =
        (eyebrow != null && eyebrow.isNotEmpty ? 1 : 0) + widget.details.length;

    return (AppCatalogueCard.lineBudget - taken).clamp(1, AppCatalogueCard.lineBudget);
  }

  @override
  Widget build(BuildContext context)
  {
    final String? eyebrow = widget.eyebrow;

    return MouseRegion(
      cursor: _isPressable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovering = _isPressable),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: AppCatalogueCard.height,
          padding: AppCatalogueCard.padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppCatalogueCard.radius),
            // Gold under the pointer, the same mark a module card takes on the
            // dashboard and a document row in the settings.
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          // Centred through the column and not through an alignment on the
          // container: an aligned Container takes all the space it is given, and
          // where that space is a page the card becomes a page tall.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow.isNotEmpty) ...[
                OverflowTooltipText(
                  text: eyebrow.toUpperCase(),
                  maxLines: 1,
                  style: eyebrowTextStyle().copyWith(height: AppCatalogueCard.lineHeight),
                ),
                const SizedBox(height: 4),
              ],
              OverflowTooltipText(
                text: widget.title,
                maxLines: _titleLines,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialOcean,
                  height: 1.15,
                ),
              ),
              for (final detail in widget.details) ...[
                const SizedBox(height: 4),
                OverflowTooltipText(
                  text: detail.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
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
    );
  }
}
