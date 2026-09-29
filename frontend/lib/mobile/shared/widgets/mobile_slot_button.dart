import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mobile_button_label.dart';

const double _dash = 7;
const double _gap = 5;
const double _stroke = 1.5;

class MobileSlotButton extends StatelessWidget
{
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool onLight;

  // Faded through its colours: an Opacity trips Impeller's check.
  final double alpha;

  const MobileSlotButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onLight = false,
    this.alpha = 1,
  });

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: CustomPaint(
          painter: _DashedOutline(onLight: onLight, alpha: alpha),
          child: SizedBox(
            height: onLight ? 48 : 58,
            child: Center(
              child: MobileButtonLabel(
                label: label,
                icon: icon,
                color: (onLight ? AppTheme.trialTealDeep : Colors.white).withValues(alpha: alpha),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedOutline extends CustomPainter
{
  final bool onLight;
  final double alpha;

  const _DashedOutline({required this.onLight, required this.alpha});

  @override
  void paint(Canvas canvas, Size size)
  {
    final Color ink = onLight ? AppTheme.trialTealDeep : Colors.white;

    final RRect shape = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_stroke / 2),
      Radius.circular(onLight ? 14 : 18),
    );

    canvas.drawRRect(shape, Paint()..color = ink.withValues(alpha: alpha * (onLight ? 0.05 : 0.08)));

    final Paint line = Paint()
      ..color = ink.withValues(alpha: alpha * (onLight ? 0.45 : 0.55))
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    for (final ui.PathMetric metric in (Path()..addRRect(shape)).computeMetrics())
    {
      for (double at = 0; at < metric.length; at += _dash + _gap)
      {
        canvas.drawPath(metric.extractPath(at, at + _dash), line);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate)
  {
    return oldDelegate.onLight != onLight || oldDelegate.alpha != alpha;
  }
}
