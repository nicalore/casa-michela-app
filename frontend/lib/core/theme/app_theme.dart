import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme
{

  static const Color trialTealDeep = Color(0xFF0B6478);
  static const Color trialTurquoise = Color(0xFF17B3A3);
  static const Color trialOcean = Color(0xFF123A5E);

  static const Color trialDeepWater = Color(0xFF0B3350);
  static const Color trialSeaGreen = Color(0xFF12907F);

  static const Color trialViolet = Color(0xFF6C3F95);

  static const Color trialGold = Color(0xFFE3A83C);
  static const Color trialGoldSurface = Color(0xFFFDF3E5);

  static const Color trialSelection = Color(0x3317B3A3);

  static const Color trialDanger = Color(0xFFC1503F);

  static const Color trialDangerLight = Color(0xFFD9705F);

  static const Color trialPaper = Color(0xFFEBEFF3);

  static const Color trialInk = Color(0xFF122438);
  static const Color trialLine = Color(0xFFDDE8E6);

  static const Color trialMutedText = Color(0xFF5B7280);

  static const Color closedLine = Color(0xFFCBD9D6);

  static const Color modifiedAccent = Color(0xFF9A6B15);

  static const Color modifiedAccentSurface = Color(0xFFF9ECD4);

  static const Color closedSurface = Color(0xFFE2ECEA);

  static const Color arrowDisabledSurface = Color(0xFFDDE3EA);

  static const Color todaySurface = Color(0xFFEAF7F5);

  // Legacy blue palette, still read by pages not yet on the trial colours.

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

  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);

  static const Color hint = Color(0xFFB3B3B3);

  static const Color mutedText = Color(0xFF8A8A8A);
  static const Color secondaryText = Color(0xFF6B7280);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [trialTealDeep, trialTurquoise],
  );

  static const LinearGradient greetingGradient = LinearGradient(
    colors: [trialOcean, trialViolet],
    stops: [0.15, 0.95],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [trialDanger, trialDangerLight],
    stops: [0.15, 0.95],
  );

  static const LinearGradient dismissGradient = LinearGradient(
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

  // Built once: ColorScheme.fromSeed must not run on every rebuild.
  static final ThemeData light = _buildLightTheme();

  static ThemeData _buildLightTheme()
  {
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
