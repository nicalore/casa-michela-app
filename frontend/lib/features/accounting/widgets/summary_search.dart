import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/search_terms.dart';
import '../../../shared/widgets/search_reveal.dart';
import 'hours_table_parts.dart' show HoursPart;

// The search in a summary finds people by name, as the calendar's does.

const double _frameInset = 3;
const double _frameRadius = 10;
const double _frameWidth = 2;

// The search keeps at least this beside the summary's controls, else it goes under them.
const double _searchLeast = 280;
const double _searchMost = 560;

// First among the filters: this wide, or a line of its own where the line is shorter than [_searchAlone].
const double _filterSearch = 340;
const double _denseFilterSearch = 300;
const double _searchAlone = 560;

// A row found wears the gold frame, a row missed steps back.
class SummarySearchRow extends StatefulWidget
{
  final ValueListenable<SearchTerms?>? search;
  final String name;

  // Cut where the names stay and the rest scrolls: the frame stays open there.
  final HoursPart part;

  // Against the card's edge the frame's corners follow the card's, as the hover's do.
  final double cardRadius;
  final bool atTop;
  final bool atBottom;

  final Widget child;

  const SummarySearchRow({
    super.key,
    required this.search,
    required this.name,
    this.part = HoursPart.whole,
    this.cardRadius = 0,
    this.atTop = false,
    this.atBottom = false,
    required this.child,
  });

  @override
  State<SummarySearchRow> createState() => _SummarySearchRowState();
}

class _SummarySearchRowState extends State<SummarySearchRow> implements SearchRevealTarget
{
  SearchRevealState? _revealer;

  late ({bool found, bool missed}) _marks = _marksNow;

  ({bool found, bool missed}) get _marksNow
  {
    final SearchTerms? terms = widget.search?.value;
    final bool found = terms != null && terms.findsAmong([widget.name]);

    return (found: found, missed: terms != null && !found);
  }

  @override
  bool get isSearchFound => _marksNow.found;

  void _remark()
  {
    if (mounted && _marksNow != _marks)
    {
      setState(() => _marks = _marksNow);
    }
  }

  @override
  void initState()
  {
    super.initState();
    widget.search?.addListener(_remark);

    // The part that scrolls sideways is never what comes into sight.
    if (widget.part != HoursPart.scrolled)
    {
      _revealer = SearchReveal.maybeOf(context);
      _revealer?.enrol(this);
    }
  }

  @override
  void didUpdateWidget(SummarySearchRow oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.search != widget.search)
    {
      oldWidget.search?.removeListener(_remark);
      widget.search?.addListener(_remark);
    }

    _marks = _marksNow;
  }

  @override
  void dispose()
  {
    widget.search?.removeListener(_remark);
    _revealer?.leave(this);
    super.dispose();
  }

  Radius _corner(bool againstTheCard) => Radius.circular(againstTheCard ? widget.cardRadius - _frameInset : _frameRadius);

  Widget _frame()
  {
    final BorderRadius corners = BorderRadius.vertical(top: _corner(widget.atTop), bottom: _corner(widget.atBottom));

    // Past the open side of a cut row: its corners fall out of sight.
    final double overhang = math.max(corners.topLeft.x, corners.bottomLeft.x) + _frameWidth;
    final double left = widget.part == HoursPart.scrolled ? -overhang : _frameInset;
    final double right = widget.part == HoursPart.pinned ? -overhang : _frameInset;

    // The row's own box clips what overhangs.
    return Stack(
      children: [
        Positioned(
          left: left,
          right: right,
          top: _frameInset,
          bottom: _frameInset,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _marks.found ? 1 : 0),
            duration: kSearchFade,
            curve: Curves.easeOut,
            builder: (context, lit, _) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: corners,
                border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _frameWidth),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AnimatedOpacity(
      opacity: _marks.missed ? kSearchMissOpacity : 1,
      duration: kSearchFade,
      curve: Curves.easeOut,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(child: IgnorePointer(child: _frame())),
        ],
      ),
    );
  }
}

// The search first among a summary's filters, as a pill among pills.
class SummarySearchFilters extends StatelessWidget
{
  final Widget search;
  final List<Widget> filters;
  final double gap;

  const SummarySearchFilters({super.key, required this.search, required this.filters, required this.gap});

  @override
  Widget build(BuildContext context)
  {
    final double most = AppBreakpoints.of(context).isDense ? _denseFilterSearch : _filterSearch;

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: constraints.maxWidth < _searchAlone ? constraints.maxWidth : most, child: search),
          ...filters,
        ],
      ),
    );
  }
}

// The search at the left, the summary's own controls at the right; the search goes under them
// when it would be too short beside them. Nothing moves in the tree: the field keeps its focus.
class SummaryToolbar extends MultiChildRenderObjectWidget
{
  final double gap;
  final double runGap;

  SummaryToolbar({super.key, required Widget search, required Widget controls, required this.gap, required this.runGap})
      : super(children: [search, controls]);

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSummaryToolbar(gap, runGap);

  @override
  void updateRenderObject(BuildContext context, RenderSummaryToolbar renderObject)
  {
    renderObject
      ..gap = gap
      ..runGap = runGap;
  }
}

class _ToolbarParentData extends ContainerBoxParentData<RenderBox> {}

class RenderSummaryToolbar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ToolbarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ToolbarParentData>
{
  double _gap;
  double _runGap;

  RenderSummaryToolbar(this._gap, this._runGap);

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
    if (child.parentData is! _ToolbarParentData)
    {
      child.parentData = _ToolbarParentData();
    }
  }

  Size _place(BoxConstraints constraints, {required bool dry})
  {
    final RenderBox search = firstChild!;
    final RenderBox controls = childAfter(search)!;
    final double width = constraints.maxWidth;

    Size sized(RenderBox child, BoxConstraints box)
    {
      if (dry)
      {
        return child.getDryLayout(box);
      }

      child.layout(box, parentUsesSize: true);

      return child.size;
    }

    void put(RenderBox child, Offset offset)
    {
      if (!dry)
      {
        (child.parentData! as _ToolbarParentData).offset = offset;
      }
    }

    final Size side = sized(controls, BoxConstraints(maxWidth: width));
    final double room = width - side.width - _gap;

    if (room >= _searchLeast)
    {
      final Size field = sized(search, BoxConstraints.tightFor(width: math.min(room, _searchMost)));
      final double height = math.max(field.height, side.height);

      put(search, Offset(0, (height - field.height) / 2));
      put(controls, Offset(width - side.width, (height - side.height) / 2));

      return constraints.constrain(Size(width, height));
    }

    final Size field = sized(search, BoxConstraints.tightFor(width: width));

    put(controls, Offset(width - side.width, 0));
    put(search, Offset(0, side.height + _runGap));

    return constraints.constrain(Size(width, side.height + _runGap + field.height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _place(constraints, dry: true);

  @override
  void performLayout()
  {
    size = _place(constraints, dry: false);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position})
  {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
