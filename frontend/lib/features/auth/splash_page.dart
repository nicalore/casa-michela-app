import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/auth_pill_page.dart';

// The couple of seconds the app takes to decide whether you are already signed
// in. Not an empty page with a spinner in the middle: the same paper and the
// same corner glows as everything else, so whoever opens the app sees at once
// where they have landed.
class SplashPage extends StatelessWidget
{
  static const double _logoSize = 132;
  static const double _indicatorSize = 34;

  const SplashPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return AuthPageBackground(
      watermark: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: _logoSize,
              height: _logoSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'Associazione Casa Michela',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppTheme.trialOcean,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: _indicatorSize,
              height: _indicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.trialTurquoise,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
