import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_colours.dart';

abstract final class AppTheme
{

  static Color get trialTealDeep => ThemeColours.of(0xFF0B6478);
  // The deep accents as text, icons and lines: lit up in the dark to read on the dark cards.
  static Color get trialTealDeepText => ThemeColours.lit(0xFF0B6478);
  static Color get trialTurquoise => ThemeColours.of(0xFF17B3A3);
  static const Color trialOcean = Color(0xFF123A5E);
  static Color get trialOceanText => ThemeColours.fixedLit(0xFF123A5E);

  static const Color trialDeepWater = Color(0xFF0B3350);
  static Color get trialDeepWaterText => ThemeColours.fixedLit(0xFF0B3350);
  static Color get trialSeaGreen => ThemeColours.of(0xFF12907F);
  static Color get trialLagoon => ThemeColours.of(0xFF1AA27E);

  static Color get trialViolet => ThemeColours.of(0xFF6C3F95);
  static Color get trialVioletText => ThemeColours.lit(0xFF6C3F95);

  static Color get trialGold => ThemeColours.of(0xFFE3A83C);
  static Color get trialGoldSurface => ThemeColours.of(0xFFFDF3E5);

  static Color get trialSelection => ThemeColours.of(0x3317B3A3);

  static const Color trialDanger = Color(0xFFC1503F);
  static Color get trialDangerText => ThemeColours.fixedLit(0xFFC1503F);

  static const Color trialDangerLight = Color(0xFFD9705F);

  static Color get trialPaper => ThemeColours.fixed(0xFFEBEFF3);

  // The page itself; in the dark trialPaper is the well inside a card, a step above it.
  static Color get pagePaper => ThemeColours.isDark ? ThemeColours.darkPage : trialPaper;

  // A white card, a dark one in the dark mode; surfaceEdge is a white rim around it.
  static Color get surface => ThemeColours.fixed(0xFFFFFFFF);
  static Color get surfaceEdge => ThemeColours.isDark ? trialLine : Colors.white;

  static Color get trialInk => ThemeColours.fixed(0xFF122438);
  static Color get trialLine => ThemeColours.of(0xFFDDE8E6);

  static Color get trialMutedText => ThemeColours.fixed(0xFF5B7280);

  static Color get closedLine => ThemeColours.of(0xFFCBD9D6);

  static Color get modifiedAccent => ThemeColours.of(0xFF9A6B15);

  static Color get modifiedAccentSurface => ThemeColours.of(0xFFF9ECD4);

  static Color get closedSurface => ThemeColours.of(0xFFE2ECEA);

  // A decided closure (holiday, works), under trialDanger text.
  static Color get closedOverrideSurface => ThemeColours.fixed(0xFFFCEDEA);

  static Color get arrowDisabledSurface => ThemeColours.fixed(0xFFDDE3EA);

  static Color get todaySurface => ThemeColours.of(0xFFEAF7F5);

  // Presence keeps its green in every theme, apart from the theme's main colour.
  static Color get presenceAccent => ThemeColours.presenceAccent;
  static Color get presenceAccentText => ThemeColours.presenceAccentText;
  static Color get presenceSurface => ThemeColours.presenceSurface;

  // In-person badges (hours, mode, room), desktop and mobile: todaySurface read as grey.
  static Color get presenceBadge => ThemeColours.of(0xFFC2DCD3);

  // Something paid that starts later: a renewal waiting for the running package or month.
  static const Color laterBlue = Color(0xFF1D5592);
  static Color get laterBlueText => ThemeColours.fixedLit(0xFF1D5592);
  static Color get laterBlueSurface => ThemeColours.fixed(0xFFE2ECF8);

  // A month paid, a renewal starting at once.
  static Color get paidSurface => ThemeColours.fixed(0xFFE3F4F1);

  // Facts and the current tariff inside a dialog.
  static Color get quietSurface => ThemeColours.of(0xFFF5F8F8);

  // Statistics charts: the greeting's ocean and violet, never presence teal or online gold.
  static Color get chartOcean => ThemeColours.of(0xFF4077B3);
  static Color get chartViolet => trialViolet;
  static const Color chartNavy = trialOcean;
  static Color get chartNavyText => trialOceanText;
  static Color get chartLilac => ThemeColours.of(0xFFAE8ED0);

  // A lone series runs from ocean to violet, as the greeting does.
  static LinearGradient get chartLineGradient => LinearGradient(colors: [chartOcean, chartViolet]);

  static LinearGradient get chartBarGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [chartViolet, chartNavy],
  );

  // Slices that stand for "none" or "other".
  static Color get chartGray => slate400;
  static Color get chartGrayLight => ThemeColours.fixed(0xFFCBD5E1);

  // Ordered categories (age groups), lightest first.
  static List<Color> get chartRamp => [
    ThemeColours.of(0xFF77B5FB),
    ThemeColours.of(0xFF6F9AE4),
    ThemeColours.of(0xFF687FCC),
    ThemeColours.of(0xFF6165B3),
    ThemeColours.of(0xFF584C98),
    ThemeColours.of(0xFF4E347D),
    ThemeColours.of(0xFF421B62),
  ];

  static const Color primary = Color(0xFF003C82);
  static Color get primaryText => ThemeColours.fixedLit(0xFF003C82);
  static const Color primaryHover = Color(0xFF004D99);
  static Color get primaryHoverText => ThemeColours.fixedLit(0xFF004D99);
  static const Color secondary = Color(0xFF0175C2);

  static const Color danger = Color(0xFFE53935);
  static const Color dangerHover = Color(0xFFEF5350);

  static Color get pageBackground => ThemeColours.fixed(0xFFF4F7F9);
  static Color get border => ThemeColours.fixed(0xFFE0E5EC);
  static Color get divider => ThemeColours.fixed(0xFFF0F0F0);
  static Color get surfaceHover => ThemeColours.fixed(0xFFF5F8FC);
  static Color get iconHover => ThemeColours.fixed(0xFFE3F2FD);

  static Color get slate800 => ThemeColours.fixed(0xFF1E293B);
  static Color get slate700 => ThemeColours.fixed(0xFF334155);
  static Color get slate500 => ThemeColours.fixed(0xFF64748B);
  static Color get slate400 => ThemeColours.fixed(0xFF94A3B8);
  static Color get slate200 => ThemeColours.fixed(0xFFE2E8F0);

  static Color get hint => ThemeColours.fixed(0xFFB3B3B3);

  static Color get mutedText => ThemeColours.fixed(0xFF8A8A8A);
  static Color get secondaryText => ThemeColours.fixed(0xFF6B7280);

  static LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [trialTealDeep, trialTurquoise],
  );

  // Something still to do, as a payment owed.
  static LinearGradient get goldGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ThemeColours.of(0xFFF0BE5E), ThemeColours.of(0xFFC98A1E)],
  );

  // Text: lit up in the dark.
  static LinearGradient get greetingGradient => LinearGradient(
    colors: [trialOceanText, trialVioletText],
    stops: [0.15, 0.95],
  );

  static const Color halloweenPumpkin = Color(0xFFD9650F);

  // The pumpkin lightened for the dark mobile backdrop.
  static const Color halloweenPumpkinLight = Color(0xFFFFA24C);

  static LinearGradient get halloweenGreetingGradient => LinearGradient(
    colors: [halloweenPumpkin, trialViolet],
    stops: [0.15, 0.95],
  );

  // New Year fireworks, the same in every theme and mode: deep twin (a spark's rim on a light page), bright twin.
  static const List<(Color, Color)> fireworks = [
    (Color(0xFFB3261E), Color(0xFFFF5A4E)),
    (Color(0xFFC25400), Color(0xFFFF9238)),
    fireworksGold,
    (Color(0xFF1E7D32), Color(0xFF4FD16A)),
    (Color(0xFF00798A), Color(0xFF3FD6E8)),
    (Color(0xFF1F4FB8), Color(0xFF5B8CFF)),
    (Color(0xFF5E35B1), Color(0xFFA57CFF)),
    (Color(0xFFB0246A), Color(0xFFFF6FB5)),
  ];

  // The rockets' trails and the willow of the finale.
  static const (Color, Color) fireworksGold = (Color(0xFFA87400), Color(0xFFFFC93C));

  // Lost on a light page: only over dark backdrops.
  static const (Color, Color) fireworksSilver = (Color(0xFF4A5866), Color(0xFFFFFFFF));

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [trialDanger, trialDangerLight],
    stops: [0.15, 0.95],
  );

  static LinearGradient get dismissGradient => LinearGradient(
    colors: [trialOcean, trialViolet],
    stops: [0.15, 0.95],
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> overlayShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2),
  ];

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

  // Built once per theme and mode: ColorScheme.fromSeed must not run on every rebuild.
  static final Map<(ColourTheme, bool), ThemeData> _themes = {};

  static ThemeData get theme => _themes[(ThemeColours.current.value, ThemeColours.isDark)] ??= _buildTheme();

  static ThemeData _buildTheme()
  {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: trialTealDeep,
      primary: trialTealDeep,
      secondary: trialTurquoise,
      surface: surface,
      brightness: ThemeColours.isDark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pagePaper,
      canvasColor: surface,
      // Must match pubspec.yaml and google_fonts' fallbacks, or the engine font takes over.
      fontFamily: 'PlusJakartaSans',
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: trialTurquoise,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: trialTealDeepText,
        selectionColor: trialSelection,
        selectionHandleColor: trialTealDeepText,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: tooltipDecoration,
        textStyle: tooltipTextStyle,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
    );
  }
}
