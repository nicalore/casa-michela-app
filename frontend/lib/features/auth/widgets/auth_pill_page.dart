import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_watermark.dart';

// Background for pre-sign-in pages and the not-found page.
class AuthPageBackground extends StatelessWidget
{
  final Widget child;

  // Off on the login page, where it would overlap the logo.
  final bool watermark;

  const AuthPageBackground({super.key, required this.child, this.watermark = true});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: AppTheme.trialPaper,
      body: Stack(
        children: [
          // CornerGlows position themselves; do not wrap them in Positioned.
          const CornerGlow(
            corner: GlowCorner.topRight,
            tint: AppTheme.trialDeepWater,
            edgeTint: AppTheme.trialOcean,
            intensity: 1.25,
            animated: true,
          ),
          const CornerGlow(
            corner: GlowCorner.bottomLeft,
            tint: AppTheme.trialSeaGreen,
            edgeTint: AppTheme.trialTealDeep,
            animated: true,
          ),
          if (watermark) const PageWatermark(),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class AuthPillPage extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final List<Widget> children;
  final Widget? footer;
  final double maxWidth;

  const AuthPillPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.children,
    this.footer,
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context)
  {
    return AuthPageBackground(
      child: AppDialogStack(
        eyebrow: eyebrow,
        title: title,
        showClose: false,
        maxWidth: maxWidth,
        footer: footer,
        children: children,
      ),
    );
  }
}
