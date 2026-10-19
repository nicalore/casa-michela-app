import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Ellipsis clips text to its box; under line height 1.26 that box ends above the g's tail.
class DescenderRoom extends SingleChildRenderObjectWidget
{
  const DescenderRoom({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDescenderRoom();
}

class _RenderDescenderRoom extends RenderProxyBox
{
  // Only boxes that take their child's size: anything that aligns would move the text.
  RenderParagraph? get _paragraph
  {
    RenderObject? node = child;

    while (node is RenderProxyBox)
    {
      node = node.child;
    }

    return node is RenderParagraph ? node : null;
  }

  // The cases where RenderParagraph clips to its own box.
  static bool _clips(RenderParagraph paragraph)
  {
    if (paragraph.overflow == TextOverflow.visible)
    {
      return false;
    }

    final Size size = paragraph.size;
    final double needed = paragraph.softWrap
        ? paragraph.getMinIntrinsicWidth(double.infinity)
        : paragraph.getMaxIntrinsicWidth(double.infinity);

    return paragraph.didExceedMaxLines
        || needed > size.width
        || paragraph.getMaxIntrinsicHeight(size.width) > size.height;
  }

  @override
  void performLayout()
  {
    final RenderBox? child = this.child;

    if (child == null)
    {
      size = constraints.smallest;

      return;
    }

    child.layout(constraints, parentUsesSize: true);
    size = child.size;

    final RenderParagraph? paragraph = _paragraph;

    if (paragraph != null && _clips(paragraph))
    {
      // Same widths keep the lines; text paints from its top, so only its clip moves down.
      final double tall = size.height * 1.5;

      child.layout(
        BoxConstraints(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth, minHeight: tall, maxHeight: tall),
        parentUsesSize: true,
      );
    }
  }
}
