import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_watermark.dart';

// The background of the pages seen before signing in, and of the one seen when
// an address leads nowhere. The same as every other page of the app: the paper,
// the two corner glows — the two ends of the brand ramp, split between the
// corners — and the watermark.
class AuthPageBackground extends StatelessWidget
{
  final Widget child;

  // The watermark. Off on the login page, where the association's logo is
  // already the largest thing on screen and the two overlapped.
  final bool watermark;

  const AuthPageBackground({super.key, required this.child, this.watermark = true});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: AppTheme.trialPaper,
      body: Stack(
        children: [
          // They position themselves: inside a Positioned they would get two
          // positions, one overriding the other.
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

// One of those pages shaped like a dialog of the app: the header, and under it
// the pills carrying what has to be answered.
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
        // There is no dialog to close: what lies underneath is the page.
        showClose: false,
        maxWidth: maxWidth,
        footer: footer,
        children: children,
      ),
    );
  }
}
