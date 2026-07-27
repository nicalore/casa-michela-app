import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme
{
  static const Color primary = Color(0xFF003C82);
  static const Color primaryHover = Color(0xFF004D99);
  static const Color secondary = Color(0xFF0175C2);

  static const Color danger = Color(0xFFE53935);
  static const Color dangerHover = Color(0xFFEF5350);

  // Marks a value that differs from the recurring weekly template (a
  // hand-edited hour, a holiday closure): amber reads as "notable", not as an
  // error the way danger's red would. First semantic accent beyond
  // primary/secondary/danger, introduced for the opening-hours table
  // (Associazione > Orari), the app's first true data table.
  static const Color modifiedAccent = Color(0xFFB45309);

  // Surfaces for the "Chiuso" strip that runs across the band columns. Opaque,
  // not modifiedAccent at low alpha: a translucent strip lets whatever is
  // behind it through, and on the highlighted row of today the blue showed
  // through and drained the colour out of it. These are that tint already
  // flattened onto white.
  //
  // The neutral one marks a day the weekly template simply never opens, as
  // against a closure somebody decided on.
  static const Color modifiedAccentSurface = Color(0xFFF9F1EB);
  static const Color closedSurface = Color(0xFFF1F3F6);

  // Trial palette taken from the timbrature mockup: deep teal and turquoise as
  // the brand pair, ocean for headings, gold and violet as the two decorative
  // accents. Only the dashboard reads these for now, so the new colours can be
  // judged next to the pages still on the blue; promoting them to the whole app
  // is a matter of assigning these values to primary and its neighbours.
  //
  // trialInk and trialLine are the rest of the mockup's palette and nothing
  // reads them yet: they are the body text and the borders the trial would need
  // the day it leaves the dashboard. If the trial is abandoned they go with it.
  static const Color trialTealDeep = Color(0xFF0B6478);
  static const Color trialTurquoise = Color(0xFF17B3A3);
  static const Color trialOcean = Color(0xFF123A5E);

  // The two intermediate stops of the mockup's background ramp
  // (deep ocean to teal to sea green). They exist only to reproduce that
  // gradient in the corner glows, and are not meant as UI colours on their own.
  static const Color trialDeepWater = Color(0xFF0B3350);
  static const Color trialSeaGreen = Color(0xFF12907F);

  // Violet earns its place only where it arrives out of another colour, as the
  // far end of the greeting's gradient. Tried as a flat colour on labels, roles
  // and notices it read as a third brand colour rather than as an accent, which
  // the logo does not support: there the violet is a few small figures against
  // the blue and the green.
  static const Color trialViolet = Color(0xFF6C3F95);

  // Gold is a state, not a colour of the page: it appears where the pointer is
  // and goes away with it, which is the one job no other colour here has. The
  // surface is that same gold flattened onto white until it is barely a colour,
  // for the places where the pointer is answered by a ground rather than by a
  // line: the mockup uses this exact tint as the bed of its "uscita" pill.
  static const Color trialGold = Color(0xFFE3A83C);
  static const Color trialGoldSurface = Color(0xFFFDF3E5);
  static const Color trialPaper = Color(0xFFF5FAF9);
  static const Color trialInk = Color(0xFF122438);
  static const Color trialLine = Color(0xFFDDE8E6);
  static const Color trialDanger = Color(0xFFC1503F);
  static const Color trialMutedText = Color(0xFF5B7280);

  // For the button that destroys something, and only for that one. It is the
  // one place in the app where red is the right answer, so it gets a ramp of its
  // own rather than a tint of the brand.
  static const Color trialDangerLight = Color(0xFFD9705F);

  // The teal to turquoise ramp the mockup gives its primary button: the one
  // place the brand pair appears as a gradient instead of as two flat colours.
  // The icon badges on the dashboard cards and the primary button read it from
  // here, so the ramp cannot drift apart between them.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [trialTealDeep, trialTurquoise],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [trialDanger, trialDangerLight],
    stops: [0.15, 0.95],
  );

  // The blue to violet ramp of the greeting, kept for the button that backs out
  // of a dialog. Red is how the app answers something destructive, and walking
  // away from a dialog is not that, so a full width red bar would warn about
  // nothing.
  static const LinearGradient dismissGradient = LinearGradient(
    colors: [trialOcean, trialViolet],
    stops: [0.15, 0.95],
  );

  static const Color pageBackground = Color(0xFFF4F7F9);
  static const Color border = Color(0xFFE0E5EC);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color surfaceHover = Color(0xFFF5F8FC);
  static const Color iconHover = Color(0xFFE3F2FD);

  // Neutral slate scale already in use across the screens, so far declared
  // locally under a different name in each file. The names stay numeric because
  // the same value serves different purposes: slate800 is a heading here and a
  // dark tooltip surface elsewhere.
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);

  static const Color hint = Color(0xFFB3B3B3);

  // Two distinct greys for secondary text, inherited from the existing screens:
  // mutedText on the association pages, secondaryText on the auth ones. They are
  // close but not equal, and unifying them is a visual decision still open.
  static const Color mutedText = Color(0xFF8A8A8A);
  static const Color secondaryText = Color(0xFF6B7280);

  // The two recurring elevations of the interface. Declared here because the
  // same values were repeated in every card, dialog and raised control.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  // Floating layers that are not anchored to the page: dropdown menus,
  // autocomplete lists, popovers.
  static const List<BoxShadow> overlayShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2),
  ];

  // The one dark surface in an interface otherwise made of white and paper, so
  // it is written once here and every Tooltip in the app inherits it through the
  // theme rather than dressing itself.
  static BoxDecoration get tooltipDecoration => BoxDecoration(
        color: trialOcean.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 18),
        ],
      );

  static TextStyle get tooltipTextStyle => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: Colors.white,
      );

  // Built once on first access, since ColorScheme.fromSeed derives a full
  // tonal palette and must not run on every widget rebuild.
  static final ThemeData light = _buildLightTheme();

  static ThemeData _buildLightTheme()
  {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      fontFamily: 'Plus Jakarta Sans',
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: tooltipDecoration,
        textStyle: tooltipTextStyle,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
    );
  }
}