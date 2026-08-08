import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

// Stops sit at the ends of the line rather than at the middle, so on a short
// greeting the two colours still both appear instead of the whole sentence
// landing on the blend between them.
const LinearGradient _greetingGradient = LinearGradient(
  colors: [AppTheme.trialOcean, AppTheme.trialViolet],
  stops: [0.15, 0.95],
);

class DashboardGreeting extends StatelessWidget
{
  static const int _morningStart = 6;
  static const int _afternoonStart = 13;
  static const int _eveningStart = 17;

  final String firstName;

  // As large as the width can carry: it changes with the window, and the
  // greeting is not what knows how.
  final double fontSize;

  const DashboardGreeting({
    super.key,
    required this.firstName,
    this.fontSize = 50,
  });

  String _greeting()
  {
    final hour = DateTime.now().hour;

    if (hour < _morningStart)
    {
      return 'È tardi, $firstName. Non dimenticarti di riposare.';
    }

    if (hour < _afternoonStart)
    {
      return 'Buongiorno, $firstName';
    }

    if (hour < _eveningStart)
    {
      return 'Buon pomeriggio, $firstName';
    }

    return 'Buonasera, $firstName';
  }

  @override
  Widget build(BuildContext context)
  {
    // It belongs to the page's column rather than resting on top of it, where
    // the sections used to slide underneath it while scrolling.
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // The line opens on the brand blue and warms into violet, so the name
        // at the end lands on the accent colour. srcIn paints the gradient
        // only where the glyphs are, which is why the text itself is white:
        // that colour is never seen, it only supplies the mask.
        //
        // The line height must stay at the font's own value. srcIn masks
        // against the box the Text reports, and a tightened height makes that
        // box shorter than the glyphs it holds: descenders sit below it and
        // the mask erases them, which a plain Text would have let overflow.
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => _greetingGradient.createShader(bounds),
          child: Text(
            _greeting(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}