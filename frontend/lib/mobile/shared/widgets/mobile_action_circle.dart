import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class MobileActionCircle extends StatelessWidget
{
  final IconData icon;
  final double size;
  final double iconSize;

  const MobileActionCircle({super.key, required this.icon, required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.brandGradient,
        boxShadow: [BoxShadow(color: Color(0x330B6478), offset: Offset(0, 4), blurRadius: 10)],
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}
