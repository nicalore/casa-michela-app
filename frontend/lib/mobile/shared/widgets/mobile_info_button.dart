import 'package:flutter/material.dart';

class MobileInfoButton extends StatelessWidget
{
  final VoidCallback onTap;

  const MobileInfoButton({super.key, required this.onTap});

  // As drawn in a tour's text, as tall as given.
  static Widget glyph(double size) => _InfoFace(size: size, iconSize: size * 0.6);

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Informazioni',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const _InfoFace(size: 34, iconSize: 20),
      ),
    );
  }
}

class _InfoFace extends StatelessWidget
{
  final double size;
  final double iconSize;

  const _InfoFace({required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Icon(
        Icons.info_outline_rounded,
        size: iconSize,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}
