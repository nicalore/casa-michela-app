import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/platform/visual_effects.dart';
import '../utils/calendar_search.dart';

// What the search leaves out steps back; what it finds keeps its colours and wears the gold rim.
const double kSearchMissOpacity = 0.3;

const Duration kSearchFade = Duration(milliseconds: 160);

const Duration _revealTravel = Duration(milliseconds: 260);

// Where what comes into sight stops, as a share of the view: clear of the hours and of the faded edge.
const double _revealAt = 0.15;

// Under the faded bottom of a view something is not yet seen.
const double _fadedEdge = 24;

class CalendarSearchFade extends StatelessWidget
{
  final ValueListenable<CalendarSearch?>? search;

  final bool Function(CalendarSearch search) finds;

  final Widget child;

  const CalendarSearchFade({super.key, required this.search, required this.finds, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final listenable = search;

    if (listenable == null)
    {
      return child;
    }

    return ValueListenableBuilder<CalendarSearch?>(
      valueListenable: listenable,
      child: child,
      builder: (context, current, child) => AnimatedOpacity(
        opacity: current == null || finds(current) ? 1 : kSearchMissOpacity,
        duration: kSearchFade,
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

// For a card that draws the search itself: the gold rim when found, the fade when missed. It
// rebuilds only when either changes, not at every letter typed.
mixin CalendarSearchMarks<T extends StatefulWidget> on State<T>
{
  ValueListenable<CalendarSearch?>? searchOf(T widget);

  bool isFoundBy(CalendarSearch search);

  ({bool found, bool missed}) _marks = (found: false, missed: false);

  _CalendarSearchRevealState? _revealer;

  ({bool found, bool missed}) get searchMarks
  {
    final search = searchOf(widget)?.value;
    final found = search != null && isFoundBy(search);

    return (found: found, missed: search != null && !found);
  }

  void _remark()
  {
    if (mounted && searchMarks != _marks)
    {
      setState(() => _marks = searchMarks);
    }
  }

  @override
  void initState()
  {
    super.initState();
    searchOf(widget)?.addListener(_remark);
    _revealer = context.findAncestorStateOfType<_CalendarSearchRevealState>();
    _revealer?._marked.add(this);
  }

  @override
  void didUpdateWidget(T oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (searchOf(oldWidget) != searchOf(widget))
    {
      searchOf(oldWidget)?.removeListener(_remark);
      searchOf(widget)?.addListener(_remark);
    }
  }

  @override
  void dispose()
  {
    searchOf(widget)?.removeListener(_remark);
    _revealer?._marked.remove(this);
    super.dispose();
  }
}

// What a missed card is faded by.
Widget searchFaded(({bool found, bool missed}) marks, Widget child)
{
  return AnimatedOpacity(
    opacity: marks.missed ? kSearchMissOpacity : 1,
    duration: kSearchFade,
    curve: Curves.easeOut,
    child: child,
  );
}

// Something found that draws nothing of the search: the head of a row, for a name with no hours.
class CalendarSearchTarget extends StatefulWidget
{
  final ValueListenable<CalendarSearch?>? search;

  final bool Function(CalendarSearch search) finds;

  final Widget child;

  const CalendarSearchTarget({super.key, required this.search, required this.finds, required this.child});

  @override
  State<CalendarSearchTarget> createState() => _CalendarSearchTargetState();
}

class _CalendarSearchTargetState extends State<CalendarSearchTarget> with CalendarSearchMarks
{
  @override
  ValueListenable<CalendarSearch?>? searchOf(CalendarSearchTarget widget) => widget.search;

  @override
  bool isFoundBy(CalendarSearch search) => widget.finds(search);

  @override
  Widget build(BuildContext context) => widget.child;
}

// Over a scrolled view: with nothing found in sight, the first found comes into it, on the axes
// that need it. With something in sight it stays put, or it would jump at every letter typed.
class CalendarSearchReveal extends StatefulWidget
{
  final ValueListenable<CalendarSearch?>? search;

  // What stays over the top of the view, as the hours over the rows.
  final double head;

  final Widget child;

  const CalendarSearchReveal({super.key, required this.search, this.head = 0, required this.child});

  @override
  State<CalendarSearchReveal> createState() => _CalendarSearchRevealState();
}

class _CalendarSearchRevealState extends State<CalendarSearchReveal>
{
  final Set<CalendarSearchMarks> _marked = {};

  @override
  void initState()
  {
    super.initState();
    widget.search?.addListener(_reveal);

    // Another reading of a calendar already searched.
    if (widget.search?.value != null)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void didUpdateWidget(CalendarSearchReveal oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.search != widget.search)
    {
      oldWidget.search?.removeListener(_reveal);
      widget.search?.addListener(_reveal);
    }
  }

  @override
  void dispose()
  {
    widget.search?.removeListener(_reveal);
    super.dispose();
  }

  Rect _rectOf(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;

  bool _seenIn(ScrollableState scrollable, Rect rect)
  {
    final Rect view = _rectOf(scrollable.context.findRenderObject()! as RenderBox);

    return scrollable.position.axis == Axis.vertical
        ? rect.top >= view.top + widget.head && rect.bottom <= view.bottom - _fadedEdge
        : rect.left >= view.left && rect.right <= view.right;
  }

  List<ScrollableState> _viewsOver(BuildContext context)
  {
    return [
      for (ScrollableState? view = Scrollable.maybeOf(context); view != null; view = Scrollable.maybeOf(view.context))
        view,
    ];
  }

  void _reveal()
  {
    final CalendarSearch? search = widget.search?.value;

    if (search == null || !mounted)
    {
      return;
    }

    final found = [
      for (final mark in _marked)
        if (mark.mounted && mark.isFoundBy(search))
          if (mark.context.findRenderObject() case final RenderBox box when box.attached && box.hasSize)
            (context: mark.context, box: box, rect: _rectOf(box)),
    ]..sort((a, b) => a.rect.top != b.rect.top ? a.rect.top.compareTo(b.rect.top) : a.rect.left.compareTo(b.rect.left));

    bool inSight(({BuildContext context, RenderBox box, Rect rect}) item) =>
        _viewsOver(item.context).every((view) => _seenIn(view, item.rect));

    if (found.isEmpty || found.any(inSight))
    {
      return;
    }

    final first = found.first;

    for (final view in _viewsOver(first.context))
    {
      if (!_seenIn(view, first.rect))
      {
        view.position.ensureVisible(
          first.box,
          alignment: _revealAt,
          duration: VisualEffects.on ? _revealTravel : Duration.zero,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
