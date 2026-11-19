import 'package:flutter/widgets.dart';

// The automatic tile's preview: the dark look over the lower right half, cut along the diagonal.
class SplitPreviewClip extends CustomClipper<Path>
{
  const SplitPreviewClip();

  @override
  Path getClip(Size size)
  {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(SplitPreviewClip oldClipper) => false;
}
