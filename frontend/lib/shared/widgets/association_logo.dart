import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AssociationLogo extends StatelessWidget
{
  // The size the ring, halo and shadow were drawn for.
  static const double _drawnAt = 92;

  final double size;

  const AssociationLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context)
  {
    final double scale = size / _drawnAt;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Drop shadow, halo, ring: later spread shadows paint on top.
        boxShadow: [
          BoxShadow(color: const Color(0x59000000), offset: Offset(0, 14 * scale), blurRadius: 28 * scale),
          BoxShadow(color: AppTheme.trialGold.withValues(alpha: 0.16), spreadRadius: 10 * scale),
          BoxShadow(color: AppTheme.trialGold.withValues(alpha: 0.8), spreadRadius: 3 * scale),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}
