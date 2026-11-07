import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

// What on the home leads elsewhere. Without [onTap] the child stands alone.
class MobileLink extends StatelessWidget
{
  final VoidCallback? onTap;
  final Widget child;

  const MobileLink({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return onTap == null ? child : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
  }
}

// The app's sign of a row that opens something; [onSea]: straight on the backdrop, not on glass.
class MobileLinkChevron extends StatelessWidget
{
  final double size;
  final bool onSea;

  const MobileLinkChevron({super.key, this.size = 24, this.onSea = false});

  @override
  Widget build(BuildContext context)
  {
    return Icon(
      Icons.chevron_right_rounded,
      size: size,
      color: onSea ? Colors.white.withValues(alpha: 0.55) : AppTheme.trialInk.withValues(alpha: 0.36),
    );
  }
}
