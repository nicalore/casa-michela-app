import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration _fade = Duration(milliseconds: 220);
const double _radius = 22;
const double _borderWidth = 1.5;

// One thing you can pick out of many. Chosen, it wears the brand ramp with a
// check on it — the same answer a filter pill gives when it is on, because it is
// the same statement: this one is in.
//
// Under the pointer it takes the gold outline every other pickable surface in
// the app takes, so a chip you have not chosen still tells you it can be.
class AppSelectableChip extends StatefulWidget
{
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const AppSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<AppSelectableChip> createState() => _AppSelectableChipState();
}

class _AppSelectableChipState extends State<AppSelectableChip>
{
  bool _hover = false;

  // The white is written as a ramp of two whites rather than as a plain colour.
  // It looks like a pointless way to say white, and it is the whole fix: a
  // decoration that carries a colour and one that carries a gradient cannot be
  // interpolated into each other, so the old chip had nothing to animate through
  // and flashed on its way between the two. Two gradients lerp colour by colour,
  // and the ramp simply grows out of the white.
  LinearGradient _gradient(double t)
  {
    return LinearGradient(
      begin: AppTheme.brandGradient.begin,
      end: AppTheme.brandGradient.end,
      colors: [
        Color.lerp(Colors.white, AppTheme.trialTealDeep, t)!,
        Color.lerp(Colors.white, AppTheme.trialTurquoise, t)!,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // Two values, because the two answers are to two different questions and can
    // be halfway through at the same time: t is whether it is chosen, h is
    // whether the pointer is on it.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _hover ? 1 : 0),
      duration: _fade,
      curve: Curves.easeOut,
      builder: (context, h, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: widget.selected ? 1 : 0),
        duration: _fade,
        curve: Curves.easeOut,
        builder: (context, t, _) => _buildChip(t, h),
      ),
    );
  }

  Widget _buildChip(double t, double h)
  {
    final Color contentColor = Color.lerp(
      Color.lerp(AppTheme.trialMutedText, AppTheme.trialTealDeep, h)!,
      Colors.white,
      t,
    )!;

    final Color borderColor = Color.lerp(
      Color.lerp(AppTheme.trialLine, Colors.transparent, t)!,
      AppTheme.trialGold,
      h,
    )!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: _gradient(t),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor, width: _borderWidth),
          ),
          // The colour is the whole message: a chip that has gone from white to
          // the brand ramp has already said it is in, and a tick on top of that
          // says it twice.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flexible and free to wrap: a study programme can be named at
              // length, and the name is the whole point of the chip. It runs on
              // to a second line and the chip grows to hold it, rather than
              // being cut short with a tooltip standing in for what was lost.
              Flexible(
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w500,
                    height: 1.25,
                    color: contentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
