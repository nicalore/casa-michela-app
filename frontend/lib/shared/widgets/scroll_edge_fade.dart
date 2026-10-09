import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Content that goes on below the bottom edge fades out there instead of being cut.
class ScrollEdgeFade extends StatefulWidget
{
  // One height everywhere: about the cut row alone, the row above stays whole.
  static const double height = 40;

  final Widget child;

  const ScrollEdgeFade({super.key, required this.child});

  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

// Smoothstep over the first three quarters, then clear: no line shows where content is cut.
const List<double> _stops = [0, 0.1875, 0.375, 0.5625, 0.75, 1];
const List<double> _opacity = [1, 0.84, 0.5, 0.16, 0, 0];

class _ScrollEdgeFadeState extends State<ScrollEdgeFade>
{
  // Content below the edge, up to the fade's height: it weakens as the end comes near.
  double _below = 0;

  bool _measure(ScrollMetrics metrics, int depth)
  {
    if (depth != 0 || metrics.axis != Axis.vertical)
    {
      return false;
    }

    final double below = metrics.extentAfter.clamp(0, ScrollEdgeFade.height).toDouble();

    if (below != _below)
    {
      setState(() => _below = below);
    }

    return false;
  }

  // Drawn over the bottom strip alone: what lies above it is left as it is.
  Shader _mask(Rect bounds)
  {
    final double strength = _below / ScrollEdgeFade.height;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [for (final opacity in _opacity) Color.fromRGBO(255, 255, 255, 1 - strength * (1 - opacity))],
      stops: _stops,
    ).createShader(bounds);
  }

  @override
  Widget build(BuildContext context)
  {
    // The mask stays in the tree even when idle: taking it away would remount the list under it.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _measure(notification.metrics, notification.depth),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) => _measure(notification.metrics, notification.depth),
        child: _SidewaysMask(
          active: _below > 0,
          // Pages slide in and out sideways past their bounds: the mask follows them.
          reach: MediaQuery.sizeOf(context).width,
          // A new closure each build: an equal one would not repaint the mask.
          shader: (bounds) => _mask(bounds),
          child: widget.child,
        ),
      ),
    );
  }
}

// A ShaderMask over the bottom strip that also covers reach on either side; vertical fade only.
class _SidewaysMask extends SingleChildRenderObjectWidget
{
  final bool active;
  final double reach;
  final ShaderCallback shader;

  const _SidewaysMask({required this.active, required this.reach, required this.shader, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSidewaysMask(active, reach, shader);

  @override
  void updateRenderObject(BuildContext context, _RenderSidewaysMask renderObject)
  {
    renderObject
      ..active = active
      ..reach = reach
      ..shader = shader;
  }
}

class _RenderSidewaysMask extends RenderProxyBox
{
  bool _active;
  double _reach;
  ShaderCallback _shader;

  _RenderSidewaysMask(this._active, this._reach, this._shader);

  set active(bool value)
  {
    if (value != _active)
    {
      _active = value;
      markNeedsPaint();
    }
  }

  set reach(double value)
  {
    if (value != _reach)
    {
      _reach = value;
      markNeedsPaint();
    }
  }

  set shader(ShaderCallback value)
  {
    if (value != _shader)
    {
      _shader = value;
      markNeedsPaint();
    }
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset)
  {
    // Nothing below: no offscreen pass at all.
    if (child == null || !_active)
    {
      layer = null;
      super.paint(context, offset);

      return;
    }

    final double strip = size.height < ScrollEdgeFade.height ? size.height : ScrollEdgeFade.height;
    final Rect area = Rect.fromLTWH(offset.dx - _reach, offset.dy + size.height - strip, size.width + 2 * _reach, strip);

    layer = (layer ?? ShaderMaskLayer())
      ..shader = _shader(Offset.zero & area.size)
      ..maskRect = area
      ..blendMode = BlendMode.dstIn;

    context.pushLayer(layer!, super.paint, offset);
  }
}
