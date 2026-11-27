import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// A grid whose children are all as tall as the tallest, each filling that height.
class MobileEqualGrid extends MultiChildRenderObjectWidget
{
  final int columns;
  final double gap;
  final double runGap;

  const MobileEqualGrid({
    super.key,
    required this.columns,
    this.gap = 0,
    required this.runGap,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMobileEqualGrid(columns, gap, runGap);

  @override
  void updateRenderObject(BuildContext context, RenderMobileEqualGrid renderObject)
  {
    renderObject
      ..columns = columns
      ..gap = gap
      ..runGap = runGap;
  }
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMobileEqualGrid extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData>
{
  RenderMobileEqualGrid(this._columns, this._gap, this._runGap);

  int _columns;
  double _gap;
  double _runGap;

  set columns(int value)
  {
    if (value != _columns)
    {
      _columns = value;
      markNeedsLayout();
    }
  }

  set gap(double value)
  {
    if (value != _gap)
    {
      _gap = value;
      markNeedsLayout();
    }
  }

  set runGap(double value)
  {
    if (value != _runGap)
    {
      _runGap = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child)
  {
    if (child.parentData is! _GridParentData)
    {
      child.parentData = _GridParentData();
    }
  }

  List<RenderBox> get _children
  {
    final List<RenderBox> children = [];
    RenderBox? child = firstChild;

    while (child != null)
    {
      children.add(child);
      child = childAfter(child);
    }

    return children;
  }

  int get _rows => (childCount / _columns).ceil();

  double _cellWidth(double width) => math.max(0, (width - _gap * (_columns - 1)) / _columns);

  double _heightOf(double cell) => _rows * cell + _runGap * math.max(0, _rows - 1);

  double _tallest(double width, double Function(RenderBox child, double cell) height)
  {
    final double cell = _cellWidth(width);

    return _children.fold(0.0, (tallest, child) => math.max(tallest, height(child, cell)));
  }

  @override
  double computeMinIntrinsicWidth(double height)
  {
    final double widest = _children.fold(0.0, (widest, child) => math.max(widest, child.getMinIntrinsicWidth(double.infinity)));

    return widest * _columns + _gap * (_columns - 1);
  }

  @override
  double computeMaxIntrinsicWidth(double height)
  {
    final double widest = _children.fold(0.0, (widest, child) => math.max(widest, child.getMaxIntrinsicWidth(double.infinity)));

    return widest * _columns + _gap * (_columns - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width)
  {
    return _heightOf(_tallest(width, (child, cell) => child.getMinIntrinsicHeight(cell)));
  }

  @override
  double computeMaxIntrinsicHeight(double width)
  {
    return _heightOf(_tallest(width, (child, cell) => child.getMaxIntrinsicHeight(cell)));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints)
  {
    final double width = constraints.maxWidth;
    final double tallest = _tallest(width, (child, cell) => child.getDryLayout(BoxConstraints.tightFor(width: cell)).height);

    return constraints.constrain(Size(width, _heightOf(tallest)));
  }

  // Laid out at their own height first, then again at the tallest.
  @override
  void performLayout()
  {
    final double width = constraints.maxWidth;
    final double cell = _cellWidth(width);
    final List<RenderBox> children = _children;
    double tallest = 0;

    for (final child in children)
    {
      child.layout(BoxConstraints.tightFor(width: cell), parentUsesSize: true);
      tallest = math.max(tallest, child.size.height);
    }

    for (final (i, child) in children.indexed)
    {
      child.layout(BoxConstraints.tightFor(width: cell, height: tallest));
      (child.parentData! as _GridParentData).offset = Offset(
        (i % _columns) * (cell + _gap),
        (i ~/ _columns) * (tallest + _runGap),
      );
    }

    size = constraints.constrain(Size(width, _heightOf(tallest)));
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position})
  {
    return defaultHitTestChildren(result, position: position);
  }
}
