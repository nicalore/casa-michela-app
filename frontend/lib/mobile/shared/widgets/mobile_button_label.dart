import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mobile_baseline_hang.dart';

// Spacing in font sizes: 1.35 and 10 at the buttons' 15.
const double _tracking = 0.09;
const double _gap = 2 / 3;

const double _sideRoom = 16;

// The icon hangs from the baseline: row-centred, it drifted with the text box's rounding.
class MobileButtonLabel extends StatelessWidget
{
  final String label;
  final IconData icon;
  final Color color;
  final double iconSize;
  final double fontSize;

  // Takes the icon's place and size.
  final Widget? replacement;

  const MobileButtonLabel({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.iconSize = 20,
    this.fontSize = 15,
    this.replacement,
  });

  @override
  Widget build(BuildContext context)
  {
    final double scale = MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
    // Glyphs snap to a whole-pixel baseline, so a fractional size drifts off-centre.
    final double size = (iconSize * scale).roundToDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideRoom),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _buildRow(size, scale),
      ),
    );
  }

  Widget _buildRow(double size, double scale)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: _tracking * fontSize,
            color: color,
          ),
        ),
        SizedBox(width: _gap * fontSize),
        MobileBaselineHang(
          above: kCapitalsMiddle * fontSize * scale,
          child: SizedBox.square(
            dimension: size,
            child: replacement ?? Icon(icon, size: size, color: color),
          ),
        ),
      ],
    );
  }
}
