import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme
{
  // -------------------------------------------------------------------------
  // Brand palette
  // -------------------------------------------------------------------------

  // Only the dashboard reads these for now. Promoting them to the whole app is
  // a matter of assigning these values to [primary] and its neighbours.
  static const Color trialTealDeep = Color(0xFF0B6478);
  static const Color trialTurquoise = Color(0xFF17B3A3);
  static const Color trialOcean = Color(0xFF123A5E);

  // Intermediate stops of the background ramp, for the corner glows only. Not
  // meant as UI colours on their own.
  static const Color trialDeepWater = Color(0xFF0B3350);
  static const Color trialSeaGreen = Color(0xFF12907F);

  // Only ever as the far end of a gradient. Flat, it reads as a third brand
  // colour, which the logo does not support.
  static const Color trialViolet = Color(0xFF6C3F95);

  // Gold is a state and not a colour of the page: it appears where the pointer
  // is and goes with it. The surface is the same gold flattened onto white, for
  // where the pointer is answered by a ground rather than by a line.
  static const Color trialGold = Color(0xFFE3A83C);
  static const Color trialGoldSurface = Color(0xFFFDF3E5);

  // The veil over selected text, light enough to read through.
  static const Color trialSelection = Color(0x3317B3A3);

  static const Color trialDanger = Color(0xFFC1503F);

  // For the button that destroys something, and only for that one.
  static const Color trialDangerLight = Color(0xFFD9705F);

  // -------------------------------------------------------------------------
  // Grounds, lines and text
  // -------------------------------------------------------------------------

  // The ground everything that is not a card or a control is laid on.
  //
  // Cool and neutral, and both are load-bearing: far enough off white for a card
  // to lift off it (1.16), and leaning blue so the mint of a chosen card is the
  // one green thing in view.
  static const Color trialPaper = Color(0xFFEBEFF3);

  // Unread so far: the body text and borders the trial needs the day it leaves
  // the dashboard.
  static const Color trialInk = Color(0xFF122438);
  static const Color trialLine = Color(0xFFDDE8E6);

  static const Color trialMutedText = Color(0xFF5B7280);

  // [trialLine] over a closed surface: an outline is seen for how far it stands
  // off what is under it, and the standard one drops to 1.04 there. This gives
  // back the 1.21 an enabled control's line has.
  static const Color closedLine = Color(0xFFCBD9D6);

  // -------------------------------------------------------------------------
  // State surfaces
  // -------------------------------------------------------------------------

  // A value differing from the weekly template — a hand-edited hour, a holiday
  // closure. Gold reads as notable where [danger]'s red would read as wrong.
  // Deepened from [trialGold], which as type on white is unreadable at 15px.
  static const Color modifiedAccent = Color(0xFF9A6B15);

  // The bed of the "Chiuso" strip. Opaque and not [modifiedAccent] at low
  // alpha, which let the highlighted row of today show through and drain it.
  static const Color modifiedAccentSurface = Color(0xFFF9ECD4);

  // Surfaces that cannot be touched: a disabled field, a spent chip, a day the
  // template never opens, the bed of a segmented control. Just above the outline
  // colour and not just below the paper, or the rail cannot be seen at all.
  static const Color closedSurface = Color(0xFFE2ECEA);

  // The bed of a paging arrow with nowhere left to go.
  //
  // Deliberately not [closedSurface]: that grey is a green grey, a cousin of the
  // mint a chosen card takes, and an arrow is the one disabled thing that
  // regularly stands beside one. Same weight of grey, off the paper's blue side
  // instead, so it is no longer the hue that means chosen.
  static const Color arrowDisabledSurface = Color(0xFFDDE3EA);

  // The row of today. Not gold: the closure strip sits inside that row, and two
  // pale golds one on the other read as one smudge.
  static const Color todaySurface = Color(0xFFEAF7F5);

  // -------------------------------------------------------------------------
  // Legacy blue palette, still read by the pages not yet on the trial colours
  // -------------------------------------------------------------------------

  static const Color primary = Color(0xFF003C82);
  static const Color primaryHover = Color(0xFF004D99);
  static const Color secondary = Color(0xFF0175C2);

  static const Color danger = Color(0xFFE53935);
  static const Color dangerHover = Color(0xFFEF5350);

  static const Color pageBackground = Color(0xFFF4F7F9);
  static const Color border = Color(0xFFE0E5EC);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color surfaceHover = Color(0xFFF5F8FC);
  static const Color iconHover = Color(0xFFE3F2FD);

  // -------------------------------------------------------------------------
  // Neutrals
  // -------------------------------------------------------------------------

  // Numeric names on purpose: the same value serves different purposes —
  // slate800 is a heading here and a dark tooltip surface elsewhere.
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);

  static const Color hint = Color(0xFFB3B3B3);

  // Two greys for secondary text: mutedText on the association pages,
  // secondaryText on the auth ones. Unifying them is a decision still open.
  static const Color mutedText = Color(0xFF8A8A8A);
  static const Color secondaryText = Color(0xFF6B7280);

  // -------------------------------------------------------------------------
  // Gradients
  // -------------------------------------------------------------------------

  // The one place the brand pair appears as a gradient. Read by both the
  // primary button and the dashboard badges, so the two cannot drift apart.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [trialTealDeep, trialTurquoise],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [trialDanger, trialDangerLight],
    stops: [0.15, 0.95],
  );

  // For the button that backs out of a dialog: red answers something
  // destructive, and walking away from a dialog is not that.
  static const LinearGradient dismissGradient = LinearGradient(
    colors: [trialOcean, trialViolet],
    stops: [0.15, 0.95],
  );

  // -------------------------------------------------------------------------
  // Elevations
  // -------------------------------------------------------------------------

  // The two recurring elevations of the interface.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  // Floating layers: dropdown menus, autocomplete lists, popovers.
  static const List<BoxShadow> overlayShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2),
  ];

  // -------------------------------------------------------------------------
  // Theme
  // -------------------------------------------------------------------------

  // Written once here: every Tooltip inherits it through the theme.
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

  // Built once: ColorScheme.fromSeed derives a full tonal palette and must not
  // run on every rebuild.
  static final ThemeData light = _buildLightTheme();

  static ThemeData _buildLightTheme()
  {
    // From the seed Material derives what we do not decide ourselves: the
    // caret, the drag handles, the tick of a system checkbox.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: trialTealDeep,
      primary: trialTealDeep,
      secondary: trialTurquoise,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: trialPaper,
      canvasColor: Colors.white,
      fontFamily: 'Plus Jakarta Sans',
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: trialTurquoise,
      ),
      // Selection takes the green of what is chosen, the caret the teal of the
      // commands.
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: trialTealDeep,
        selectionColor: trialSelection,
        selectionHandleColor: trialTealDeep,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: tooltipDecoration,
        textStyle: tooltipTextStyle,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
    );
  }
}
