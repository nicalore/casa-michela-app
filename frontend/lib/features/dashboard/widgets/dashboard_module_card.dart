import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';

const Color _subtitleColor = AppTheme.trialMutedText;

class DashboardModuleCard extends StatefulWidget
{
  // Exposed because DashboardLayout positions these cards absolutely and needs
  // their footprint to compute the grid: the size must be declared once.
  static const double width = 287;
  static const double height = 200;

  static const double _contentPadding = 23;
  static const double _iconBoxSize = 48;

  final String title;
  final String subtitle;
  final IconData? icon;
  final String? imageAsset;
  final VoidCallback onTap;

  const DashboardModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.imageAsset,
  }) : assert(
          icon != null || imageAsset != null,
          'Specificare icon oppure imageAsset',
        );

  @override
  State<DashboardModuleCard> createState() => _DashboardModuleCardState();
}

class _DashboardModuleCardState extends State<DashboardModuleCard>
{
  bool _hover = false;

  // The asset takes precedence over the icon, and the constructor assert
  // guarantees that at least one of the two is present.
  Widget _buildLeadingGlyph()
  {
    final imageAsset = widget.imageAsset;

    if (imageAsset != null)
    {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(imageAsset, fit: BoxFit.contain),
      );
    }

    return Icon(widget.icon!, color: Colors.white, size: 26);
  }

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: DashboardModuleCard.width,
          height: DashboardModuleCard.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            // Gold marks the pointer, and nothing else on the page uses it: the
            // card being hovered is the only warm thing on screen, so the eye
            // finds it without the border having to shout.
            border: Border.all(
              color: _hover ? AppTheme.trialGold : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: DashboardModuleCard._contentPadding,
              top: DashboardModuleCard._contentPadding,
              right: DashboardModuleCard._contentPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: DashboardModuleCard._iconBoxSize,
                      height: DashboardModuleCard._iconBoxSize,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: _buildLeadingGlyph(),
                    ),
                    const SizedBox(width: DashboardModuleCard._contentPadding),
                    Expanded(
                      child: OverflowTooltipText(
                        text: widget.title,
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.trialOcean,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 42),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: _subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}