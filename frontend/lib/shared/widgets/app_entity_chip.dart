import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration _hoverFade = Duration(milliseconds: 180);
const double _radius = 20;

// Something the thing you are looking at is related to: the study programmes of
// a school, the ministry subjects of a programme, the internal disciplines of a
// subject. One look for all of them, because they are all the same kind of
// statement — a fact about what you have open, not a control.
//
// The turquoise laid on white until it is barely a colour, with the deep teal on
// top of it, the same tint the roles wear in the settings.
//
// Some of these can be opened and some cannot. That difference is carried by the
// gold outline the app gives to everything the pointer can act on, so it shows
// up only when the pointer is actually there and never turns two lists of facts
// into two different-looking things.
class AppEntityChip extends StatefulWidget
{
  final String label;

  // Left out, the chip is inert: a fact with nothing behind it.
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
          color: _hover ? AppTheme.trialGold : Colors.transparent,
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
