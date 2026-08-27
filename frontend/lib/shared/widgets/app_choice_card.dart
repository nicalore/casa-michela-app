import '../../../../shared/widgets/app_check_mark.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class AppChoiceCard extends StatefulWidget
{
  final IconData? icon;

  final String title;
  final String? subtitle;
  final bool selected;
  final ValueChanged<bool> onSelected;

  final bool disabled;

  const AppChoiceCard({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onSelected,
    this.disabled = false,
  });

  @override
  State<AppChoiceCard> createState() => _AppChoiceCardState();
}

class _AppChoiceCardState extends State<AppChoiceCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = !widget.disabled),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : () => widget.onSelected(!widget.selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: widget.disabled
                ? AppTheme.trialPaper
                : (widget.selected ? kPickedSurface : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: widget.disabled ? null : AppTheme.brandGradient,
                    color: widget.disabled ? AppTheme.trialLine : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 22, color: Colors.white),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.disabled ? AppTheme.trialMutedText : AppTheme.trialOcean,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Opacity(
                opacity: widget.disabled ? 0.45 : 1,
                child: AppCheckMark(selected: widget.selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
