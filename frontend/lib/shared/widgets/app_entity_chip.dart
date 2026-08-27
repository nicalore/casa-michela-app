import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration _hoverFade = Duration(milliseconds: 180);
const double _radius = 20;

class AppEntityChip extends StatefulWidget
{
  final String label;

  final VoidCallback? onTap;

  const AppEntityChip({
    super.key,
    required this.label,
    this.onTap,
  });

  @override
  State<AppEntityChip> createState() => _AppEntityChipState();
}

class _AppEntityChipState extends State<AppEntityChip>
{
  bool _hover = false;

  bool get _isTappable => widget.onTap != null;

  @override
  Widget build(BuildContext context)
  {
    final Widget chip = AnimatedContainer(
      duration: _hoverFade,
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.trialTurquoise.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: _hover
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
          width: 1.5,
        ),
      ),
      child: Text(
        widget.label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    if (!_isTappable)
    {
      return chip;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: chip),
    );
  }
}
