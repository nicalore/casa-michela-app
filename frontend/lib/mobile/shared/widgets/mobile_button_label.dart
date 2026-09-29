import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mobile_baseline_hang.dart';

const double _fontSize = 15;
const double _gap = 10;

const double _sideRoom = 16;

// The icon hangs from the baseline: row-centred, it drifted with the text box's rounding.
class MobileButtonLabel extends StatelessWidget
{
  final String label;
  final IconData icon;
  final Color color;
  final double iconSize;

  // Takes the icon's place and size.
  final Widget? replacement;

  const MobileButtonLabel({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.iconSize = 20,
    this.replacement,
  });

  @override
  Widget build(BuildContext context)
  {
    final double scale = MediaQuery.textScalerOf(context).scale(_fontSize) / _fontSize;
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
            fontSize: _fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.35,
            color: color,
          ),
        ),
        const SizedBox(width: _gap),
        MobileBaselineHang(
          above: kCapitalsMiddle * _fontSize * scale,
          child: SizedBox.square(
            dimension: size,
            child: replacement ?? Icon(icon, size: size, color: color),
          ),
        ),
      ],
    );
  }
}
