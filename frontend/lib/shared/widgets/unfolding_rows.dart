import 'package:flutter/widgets.dart';

import 'scroll_edge_fade.dart';

const Duration _unfoldTime = Duration(milliseconds: 380);
const Duration _foldTime = Duration(milliseconds: 280);
const Duration _scrollTime = Duration(milliseconds: 300);

// Not a decelerating one: its tail left a sliver of the first row creeping shut.
const Curve _foldCurve = Curves.easeInOut;

// Each row starts this share of the unfolding after the one above it.
const double _rowStagger = 0.08;
const double _lastRowStart = 0.4;

// Rows under a header that a tap opens: the area grows from the top while each row slides out from under it.
class UnfoldingRows extends StatefulWidget
{
  final bool open;

  // False to open and shut at once.
  final bool animate;

  // Once open, the list holding the rows scrolls them into sight.
  final bool keepInView;

  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  const UnfoldingRows({
    super.key,
    required this.open,
    required this.animate,
    this.keepInView = false,
    this.padding = EdgeInsets.zero,
    required this.children,
  });

  @override
  State<UnfoldingRows> createState() => _UnfoldingRowsState();
}

class _UnfoldingRowsState extends State<UnfoldingRows> with SingleTickerProviderStateMixin
{
  late final AnimationController _unfold = AnimationController(
    vsync: this,
    duration: _unfoldTime,
    reverseDuration: _foldTime,
    value: widget.open ? 1 : 0,
  )..addStatusListener(_onStatus);

  late final CurvedAnimation _size = CurvedAnimation(
    parent: _unfold,
    curve: Curves.easeOutCubic,
    reverseCurve: _foldCurve,
  );

  final List<CurvedAnimation> _rowCurves = [];
  final List<Animation<Offset>> _rowSlides = [];

  // The rows are built only from the first frame of unfolding to the last of folding.
  void _onStatus(AnimationStatus status)
  {
    if (status == AnimationStatus.dismissed || status == AnimationStatus.forward)
    {
      setState(() {});
    }

    if (status == AnimationStatus.completed && widget.keepInView)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepInView());
    }
  }

  // Rows opened below the list's edge are brought up past its fade; those already in sight stay put.
  void _keepInView()
  {
    final ScrollableState? scrollable = mounted && _unfold.isCompleted ? Scrollable.maybeOf(context) : null;
    final RenderObject? rows = context.findRenderObject();
    final RenderObject? view = scrollable?.context.findRenderObject();

    if (scrollable == null || rows is! RenderBox || view is! RenderBox || !rows.hasSize || !view.hasSize)
    {
      return;
    }

    final double bottom = rows.localToGlobal(Offset(0, rows.size.height), ancestor: view).dy;
    final double over = bottom - (view.size.height - ScrollEdgeFade.height);

    if (over <= 0)
    {
      return;
    }

    final ScrollPosition position = scrollable.position;
    final double to = (position.pixels + over).clamp(position.minScrollExtent, position.maxScrollExtent);

    if (widget.animate)
    {
      position.animateTo(to, duration: _scrollTime, curve: Curves.easeInOutCubic);
    }
    else
    {
      position.jumpTo(to);
    }
  }

  @override
  void didUpdateWidget(UnfoldingRows oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.open == oldWidget.open)
    {
      return;
    }

    if (!widget.animate)
    {
      _unfold.value = widget.open ? 1 : 0;

      return;
    }

    if (widget.open)
    {
      _unfold.forward();
    }
    else
    {
      _unfold.reverse();
    }
  }

  @override
  void dispose()
  {
    for (final curve in _rowCurves)
    {
      curve.dispose();
    }

    _size.dispose();
    _unfold.dispose();
    super.dispose();
  }

  // Each row slides out a little after the one above; folding, the last goes first.
  List<Animation<Offset>> _slidesFor(int count)
  {
    while (_rowSlides.length < count)
    {
      final double start = (_rowSlides.length * _rowStagger).clamp(0, _lastRowStart).toDouble();
      final CurvedAnimation curve = CurvedAnimation(
        parent: _unfold,
        curve: Interval(start, 1, curve: Curves.easeOutCubic),
        reverseCurve: Interval(start, 1, curve: _foldCurve),
      );

      _rowCurves.add(curve);
      _rowSlides.add(Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero).animate(curve));
    }

    return _rowSlides;
  }

  @override
  Widget build(BuildContext context)
  {
    if (_unfold.isDismissed)
    {
      return const SizedBox.shrink();
    }

    final List<Animation<Offset>> slides = _slidesFor(widget.children.length);

    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, row) in widget.children.indexed) SlideTransition(position: slides[index], child: row),
          ],
        ),
      ),
    );
  }
}
