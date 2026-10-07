import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

const Duration _glideDuration = Duration(milliseconds: 300);

// One curve for every card, so a line moves in step and no card crosses another.
const Curve _curve = Curves.easeOutCubic;

class MobileReflowSlot extends StatefulWidget
{
  // Bumped with each removal; any other move, such as a rotation, stays a jump.
  final int generation;

  // Must match the Wrap's spacing.
  final double spacing;

  final Widget child;

  const MobileReflowSlot({
    super.key,
    required this.generation,
    required this.spacing,
    required this.child,
  });

  @override
  State<MobileReflowSlot> createState() => _MobileReflowSlotState();
}

class _MobileReflowSlotState extends State<MobileReflowSlot> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller;

  @override
  void initState()
  {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _glideDuration, value: 1);
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  void _glide()
  {
    if (mounted)
    {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return _ReflowSlot(
      generation: widget.generation,
      spacing: widget.spacing,
      progress: _controller,
      onMoved: _glide,
      child: widget.child,
    );
  }
}

class _ReflowSlot extends SingleChildRenderObjectWidget
{
  final int generation;
  final double spacing;
  final Animation<double> progress;
  final VoidCallback onMoved;

  const _ReflowSlot({
    required this.generation,
    required this.spacing,
    required this.progress,
    required this.onMoved,
    required super.child,
  });

  @override
  _RenderReflowSlot createRenderObject(BuildContext context)
  {
    return _RenderReflowSlot(generation: generation, spacing: spacing, progress: progress, onMoved: onMoved);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderReflowSlot renderObject)
  {
    renderObject
      ..generation = generation
      ..spacing = spacing
      ..onMoved = onMoved;
  }
}

// Detects the move at paint, after the Wrap placed it, so no frame shows the jump.
class _RenderReflowSlot extends RenderProxyBox
{
  int generation;
  double spacing;
  final Animation<double> progress;
  VoidCallback onMoved;

  int? _seen;
  Offset? _placed;

  // Relative to the new place.
  Offset _from = Offset.zero;

  // On a line change it fades out and in one place along: crossing would cover the neighbours.
  double? _step;

  // Held at the start until the first tick, a frame later.
  bool _starting = false;

  _RenderReflowSlot({
    required this.generation,
    required this.spacing,
    required this.progress,
    required this.onMoved,
  });

  double get _t => _starting ? 0 : progress.value;

  Offset get _shift
  {
    final double travelled = _curve.transform(_t);
    final double? step = _step;

    if (step == null)
    {
      return _from * (1 - travelled);
    }

    return _t < 0.5 ? _from + Offset(-step * travelled, 0) : Offset(step * (1 - travelled), 0);
  }

  double get _opacity
  {
    if (_step == null)
    {
      return 1;
    }

    return _t < 0.5 ? 1 - _t * 2 : _t * 2 - 1;
  }

  @override
  void attach(PipelineOwner owner)
  {
    super.attach(owner);
    progress.addListener(markNeedsPaint);
  }

  @override
  void detach()
  {
    progress.removeListener(markNeedsPaint);
    super.detach();
  }

  void _moved(Offset before, Offset placed)
  {
    if ((before.dy - placed.dy).abs() > 0.5)
    {
      _from = before - placed;
      _step = (placed.dx - before.dx).sign * (size.width + spacing);
    }
    else
    {
      // From where it is seen now, should a glide still be under way.
      _from = before - placed + (_step == null ? _shift : Offset.zero);
      _step = null;
    }

    _starting = true;

    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      _starting = false;

      if (attached)
      {
        onMoved();
      }
    });
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    final RenderBox? child = this.child;
    final Offset placed = (parentData! as BoxParentData).offset;
    final Offset? before = _placed;

    if (before != null && before != placed && _seen != generation)
    {
      _moved(before, placed);
    }

    _placed = placed;
    _seen = generation;

    if (child == null)
    {
      return;
    }

    final int alpha = (_opacity * 255).round().clamp(0, 255);

    if (alpha == 255)
    {
      layer = null;
      context.paintChild(child, offset + _shift);

      return;
    }

    layer = context.pushOpacity(
      offset + _shift,
      alpha,
      (PaintingContext inner, Offset innerOffset) => inner.paintChild(child, innerOffset),
      oldLayer: layer as OpacityLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position})
  {
    return result.addWithPaintOffset(
      offset: _shift,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          super.hitTestChildren(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform)
  {
    transform.translateByDouble(_shift.dx, _shift.dy, 0, 1);
  }
}
