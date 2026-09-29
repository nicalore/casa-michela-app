import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';

// How much of the next card peeks in at the right edge.
const double _peek = 28;
const double _gap = 12;

const double _dotSize = 6;
const double _dotCurrentWidth = 18;
const double _dotGap = 6;
const double _dotsGap = 14;

// Past either end a drag moves the cards this fraction of the finger.
const double _edgeResistance = 0.35;

// Pages per second above which a release turns the page whatever the distance.
const double _flingVelocity = 0.6;

final SpringDescription _spring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 380,
  ratio: 1,
);

class _Geometry
{
  final double margin;
  final double card;

  const _Geometry({required this.margin, required this.card});

  factory _Geometry.of(double width, double margin, int count)
  {
    final double card = count > 1 ? width - margin - _gap - _peek : width - 2 * margin;

    return _Geometry(margin: margin, card: math.max(card, 0));
  }

  double get extent => card + _gap;
}

class MobileCardDeck extends StatefulWidget
{
  final List<Widget> pages;
  final double margin;

  const MobileCardDeck({super.key, required this.pages, required this.margin});

  @override
  State<MobileCardDeck> createState() => _MobileCardDeckState();
}

class _MobileCardDeckState extends State<MobileCardDeck> with SingleTickerProviderStateMixin
{
  late final AnimationController _position = AnimationController.unbounded(vsync: this);

  int get _last => math.max(widget.pages.length - 1, 0);

  @override
  void didUpdateWidget(MobileCardDeck oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_position.value > _last)
    {
      _position.value = _last.toDouble();
    }
  }

  @override
  void dispose()
  {
    _position.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails details)
  {
    _position.stop();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onUpdate(DragUpdateDetails details, double extent)
  {
    double delta = -(details.primaryDelta ?? 0) / extent;
    final double page = _position.value;

    if ((page <= 0 && delta < 0) || (page >= _last && delta > 0))
    {
      delta *= _edgeResistance;
    }

    _position.value = page + delta;
  }

  void _onEnd(DragEndDetails details, double extent)
  {
    final double velocity = -(details.primaryVelocity ?? 0) / extent;
    final double page = _position.value;

    final double target = velocity.abs() > _flingVelocity
        ? (velocity > 0 ? page.floorToDouble() + 1 : page.ceilToDouble() - 1)
        : page.roundToDouble();

    final double settled = target.clamp(0, _last).toDouble();

    // Snap once the spring settles; a new drag cancels it and the future never completes.
    _position
        .animateWith(SpringSimulation(_spring, page, settled, velocity))
        .then((_) => _position.value = settled);
  }

  @override
  Widget build(BuildContext context)
  {
    final int count = widget.pages.length;

    // Reads only the width, which holds while the keyboard comes and goes.
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final _Geometry geometry = _Geometry.of(constraints.maxWidth, widget.margin, count);
        final double extent = math.max(geometry.extent, 1);

        final Widget view = _DeckView(
          position: _position,
          geometry: geometry,
          children: [for (final page in widget.pages) RepaintBoundary(child: page)],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (count > 1)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onStart,
                onHorizontalDragUpdate: (details) => _onUpdate(details, extent),
                onHorizontalDragEnd: (details) => _onEnd(details, extent),
                child: view,
              )
            else
              view,
            if (count > 1) ...[
              const SizedBox(height: _dotsGap),
              _DeckDots(count: count, position: _position),
            ],
          ],
        );
      },
    );
  }
}

class _DeckDots extends StatelessWidget
{
  final int count;
  final Animation<double> position;

  const _DeckDots({required this.count, required this.position});

  @override
  Widget build(BuildContext context)
  {
    return AnimatedBuilder(
      animation: position,
      builder: (context, _)
      {
        final double page = position.value.clamp(0, count - 1).toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: _dotGap),
              _buildDot(i, page),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDot(int index, double page)
  {
    // 1 on the current page, 0 a page or more away.
    final double near = (1 - (page - index).abs()).clamp(0.0, 1.0);

    return Container(
      width: ui.lerpDouble(_dotSize, _dotCurrentWidth, near),
      height: _dotSize,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white.withValues(alpha: 0.4), AppTheme.trialGold, near),
        borderRadius: BorderRadius.circular(_dotSize / 2),
      ),
    );
  }
}

class _DeckView extends MultiChildRenderObjectWidget
{
  final Animation<double> position;
  final _Geometry geometry;

  const _DeckView({required this.position, required this.geometry, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context)
  {
    return _RenderDeck(position, geometry);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderDeck renderObject)
  {
    renderObject
      ..position = position
      ..geometry = geometry;
  }
}

class _DeckParentData extends ContainerBoxParentData<RenderBox> {}

// Measures every card, shown or not, so the deck is as tall as the tallest from the start.
class _RenderDeck extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DeckParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DeckParentData>
{
  _RenderDeck(this._position, this._geometry);

  Animation<double> _position;

  set position(Animation<double> value)
  {
    if (value == _position)
    {
      return;
    }

    if (attached)
    {
      _position.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }

    _position = value;
    markNeedsLayout();
  }

  _Geometry _geometry;

  set geometry(_Geometry value)
  {
    if (value.card == _geometry.card && value.margin == _geometry.margin)
    {
      return;
    }

    _geometry = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child)
  {
    if (child.parentData is! _DeckParentData)
    {
      child.parentData = _DeckParentData();
    }
  }

  @override
  void attach(PipelineOwner owner)
  {
    super.attach(owner);
    _position.addListener(markNeedsLayout);
  }

  @override
  void detach()
  {
    _position.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout()
  {
    final double width = _geometry.card;
    double tallest = 0;

    RenderBox? child = firstChild;

    while (child != null)
    {
      tallest = math.max(tallest, child.getMaxIntrinsicHeight(width));
      child = (child.parentData! as _DeckParentData).nextSibling;
    }

    final BoxConstraints card = BoxConstraints.tightFor(width: width, height: tallest);
    final double page = _position.value;

    child = firstChild;
    var index = 0;

    while (child != null)
    {
      child.layout(card);

      final _DeckParentData data = child.parentData! as _DeckParentData;
      data.offset = Offset(_geometry.margin + (index - page) * _geometry.extent, 0);

      child = data.nextSibling;
      index += 1;
    }

    size = constraints.constrain(Size(constraints.maxWidth, tallest));
  }

  // Paints only cards across the deck; others would show on a page sliding in beside it.
  @override
  void paint(PaintingContext context, Offset offset)
  {
    RenderBox? child = firstChild;

    while (child != null)
    {
      final _DeckParentData data = child.parentData! as _DeckParentData;

      if (data.offset.dx < size.width && data.offset.dx + child.size.width > 0)
      {
        context.paintChild(child, offset + data.offset);
      }

      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position})
  {
    return defaultHitTestChildren(result, position: position);
  }
}
