import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_glass_panel.dart';

const double _dotWidth = 14;
const double _dotCurrentWidth = 30;
const double _dotHeight = 5;
const double _dotGap = 6;

const double _backRadius = 18;

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x29000000), offset: Offset(0, 8), blurRadius: 18),
];

class MobileWizardDots extends StatelessWidget
{
  final int count;
  final PageController position;
  final int fallback;

  const MobileWizardDots({
    super.key,
    required this.count,
    required this.position,
    required this.fallback,
  });

  static const Color _ahead = Color(0x29122438);

  @override
  Widget build(BuildContext context)
  {
    return AnimatedBuilder(
      animation: position,
      builder: (context, _)
      {
        final double page = position.hasClients && position.position.haveDimensions
            ? position.page ?? fallback.toDouble()
            : fallback.toDouble();

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: _dotGap),
                _buildDot(i, page),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(int index, double page)
  {
    // 1 on the current step, 0 a step or more away.
    final double near = (1 - (page - index).abs()).clamp(0.0, 1.0);
    final double behind = (page - index).clamp(0.0, 1.0);

    final Color rest = Color.lerp(_ahead, AppTheme.trialTealDeep.withValues(alpha: 0.45), behind)!;

    return Container(
      width: ui.lerpDouble(_dotWidth, _dotCurrentWidth, near),
      height: _dotHeight,
      decoration: BoxDecoration(
        color: Color.lerp(rest, AppTheme.trialGold, near),
        borderRadius: BorderRadius.circular(_dotHeight / 2),
      ),
    );
  }
}

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
            borderRadius: BorderRadius.circular(_backRadius),
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
