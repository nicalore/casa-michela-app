import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class MobileHeightReporter extends SingleChildRenderObjectWidget
{
  final ValueChanged<double> onHeight;

  const MobileHeightReporter({super.key, required this.onHeight, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMobileHeightReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderMobileHeightReporter renderObject)
  {
    renderObject.onHeight = onHeight;
  }
}

class RenderMobileHeightReporter extends RenderProxyBox
{
  ValueChanged<double> onHeight;

  double? _reported;

  RenderMobileHeightReporter(this.onHeight);

  @override
  void performLayout()
  {
    super.performLayout();

    final double height = size.height;

    if (height == _reported)
    {
      return;
    }

    _reported = height;

    // Heard after the frame: whoever listens cannot change size while laying out.
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
