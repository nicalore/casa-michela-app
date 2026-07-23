import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashPage extends StatelessWidget
{
  static const double _indicatorSize = 48;

  const SplashPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: Center(
        child: SizedBox(
          width: _indicatorSize,
          height: _indicatorSize,
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      ),
    );
  }
}