import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// On the web, paints its child on whole device pixels, so a photo sized to them is copied one to one.
class PixelSnap extends SingleChildRenderObjectWidget
{
  const PixelSnap({super.key, super.child});

  @override
  RenderPixelSnap createRenderObject(BuildContext context)
  {
    return RenderPixelSnap(MediaQuery.devicePixelRatioOf(context));
  }

  @override
  void updateRenderObject(BuildContext context, RenderPixelSnap renderObject)
  {
    renderObject.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class RenderPixelSnap extends RenderProxyBox
{
  double _devicePixelRatio;

  Offset _shift = Offset.zero;

  RenderPixelSnap(this._devicePixelRatio);

  set devicePixelRatio(double value)
  {
    if (value != _devicePixelRatio)
    {
      _devicePixelRatio = value;
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    final RenderBox? child = this.child;

    if (child == null)
    {
      return;
    }

    _shift = _snapShift();
    context.paintChild(child, offset + _shift);
  }

  // Less than half a device pixel; none while scaled or rotated, where no grid lines up.
  Offset _snapShift()
  {
    if (!kIsWeb)
    {
      return Offset.zero;
    }

    final Offset? origin = MatrixUtils.getAsTranslation(getTransformTo(null));

    if (origin == null)
    {
      return Offset.zero;
    }

    final double ratio = _devicePixelRatio;
    final double x = origin.dx * ratio;
    final double y = origin.dy * ratio;

    return Offset((x.roundToDouble() - x) / ratio, (y.roundToDouble() - y) / ratio);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform)
  {
    transform.translateByDouble(_shift.dx, _shift.dy, 0, 1);
  }
}
