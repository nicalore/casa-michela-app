import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_glass_panel.dart';

const double _radius = 18;

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x29000000), offset: Offset(0, 8), blurRadius: 18),
];

// The ← of footers, beside the page's own buttons.
class MobileWizardBackButton extends StatelessWidget
{
  static const double size = 58;

  final VoidCallback? onTap;

  const MobileWizardBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Indietro',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            color: Colors.white.withValues(alpha: MobileGlassPanel.cardAlpha),
            border: Border.all(color: AppTheme.trialOcean.withValues(alpha: 0.14)),
            boxShadow: _shadow,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: AppTheme.trialInk.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
