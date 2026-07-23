import 'package:flutter/material.dart';

abstract final class AppTheme
{
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
    );
  }
}