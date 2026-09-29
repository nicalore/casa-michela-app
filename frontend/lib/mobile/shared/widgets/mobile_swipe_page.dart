import 'package:flutter/widgets.dart';

// Clipped above and below only, so card shadows carry across pages as they slide.
class MobileSwipePage extends StatelessWidget
{
  final Widget child;

  const MobileSwipePage({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return ClipRect(clipper: const _AboveAndBelow(), child: child);
  }
}

class _AboveAndBelow extends CustomClipper<Rect>
{
  const _AboveAndBelow();

  // A page width either side, beyond any shadow; the PageView still clips at the screen.
  @override
  Rect getClip(Size size) => Rect.fromLTRB(-size.width, 0, size.width * 2, size.height);

  @override
  bool shouldReclip(_AboveAndBelow oldClipper) => false;
}
