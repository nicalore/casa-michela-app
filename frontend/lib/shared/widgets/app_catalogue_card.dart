import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
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
