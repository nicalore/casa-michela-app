import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Half the cap height of Plus Jakarta Sans (745/1000 in every weight), in font sizes.
const double kCapitalsMiddle = 0.3725;

// Takes no height in a baseline row; its child is centred [above] the baseline.
class MobileBaselineHang extends SingleChildRenderObjectWidget
{
  final double above;

  const MobileBaselineHang({super.key, required this.above, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMobileBaselineHang(above);

  @override
  void updateRenderObject(BuildContext context, RenderMobileBaselineHang renderObject)
  {
    renderObject.above = above;
  }
}

class RenderMobileBaselineHang extends RenderBox with RenderObjectWithChildMixin<RenderBox>
{
  double _above;

  RenderMobileBaselineHang(this._above);

  set above(double value)
  {
    if (value != _above)
    {
      _above = value;
      markNeedsLayout();
    }
  }

  // Text paints on its baseline rounded to a whole pixel; the row aligns on the exact one.
  double get _childTop
  {
    final double baseline = (parentData! as BoxParentData).offset.dy;

    return baseline.roundToDouble() - baseline - _above - child!.size.height / 2;
  }

  @override
  void setupParentData(RenderBox child)
  {
    if (child.parentData is! BoxParentData)
    {
      child.parentData = BoxParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => 0;

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) => 0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints)
  {
    final double width = child?.getDryLayout(constraints.loosen()).width ?? 0;

    return constraints.constrain(Size(width, 0));
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

    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(Size(child.size.width, 0));
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    final RenderBox? child = this.child;

    if (child != null)
    {
      context.paintChild(child, offset + Offset(0, _childTop));
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform)
  {
    transform.translateByDouble(0, _childTop, 0, 1);
  }
}
