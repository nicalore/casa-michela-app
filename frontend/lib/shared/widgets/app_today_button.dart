import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// The jump back to the current day, beside the arrows that walk away from it.
//
// Deliberately not styled like a selectable chip: this is a tertiary "go back"
// next to the nav arrows, not another option among them. Sized to stand level
// with the 44px CarouselArrowButton it sits with.
class AppTodayButton extends StatefulWidget
{
  final VoidCallback onTap;

  // "Oggi" for a day, whatever names the current period for anything else.
  final String label;

  const AppTodayButton({super.key, required this.onTap, this.label = 'Oggi'});

  @override
  State<AppTodayButton> createState() => _AppTodayButtonState();
}

class _AppTodayButtonState extends State<AppTodayButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            // White standing, like the arrows beside it: transparent, it read
            // as a gap in the row rather than a button. Both ends opaque so the
            // fade stays light — fading from transparent walks the RGB down
            // through grey, since transparent is transparent black.
            color: _isHovered ? AppTheme.trialGoldSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isHovered ? AppTheme.trialGold : AppTheme.trialLine, width: 1.5),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialTealDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
