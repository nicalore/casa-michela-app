import 'package:flutter/material.dart';

class AppTheme
{
  AppTheme._();

  static const Color primary = Color(0xFF003C82);
  static const Color secondary = Color(0xFF0175C2);

  static ThemeData get light
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