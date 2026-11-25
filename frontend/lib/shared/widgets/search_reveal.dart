import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';

// What a search leaves out steps back; what it finds keeps its colours and wears the gold rim.
const double kSearchMissOpacity = 0.3;

const Duration kSearchFade = Duration(milliseconds: 160);

const Duration _revealTravel = Duration(milliseconds: 260);

// Where what comes into sight stops, as a share of the view: clear of the hours and of the faded edge.
const double _revealAt = 0.15;

// Under the faded bottom of a view something is not yet seen.
const double _fadedEdge = 24;

// Something a search may find, made known to the [SearchReveal] over it.
abstract interface class SearchRevealTarget
{
  BuildContext get context;

  bool get mounted;

  // Found by the search as it now stands.
  bool get isSearchFound;
}

// Over a scrolled view: with nothing found in sight, the first found comes into it, on the axes
// that need it. With something in sight it stays put, or it would jump at every letter typed.
class SearchReveal extends StatefulWidget
{
  // Null while nothing is searched.
  final ValueListenable<Object?>? search;

  // What stays over the top of the view, as the hours over the rows.
  final double head;

  final Widget child;

  const SearchReveal({super.key, required this.search, this.head = 0, required this.child});

  // The one over [context], for a target to enrol in.
  static SearchRevealState? maybeOf(BuildContext context) => context.findAncestorStateOfType<SearchRevealState>();

  @override
  State<SearchReveal> createState() => SearchRevealState();
}

class SearchRevealState extends State<SearchReveal>
{
  final Set<SearchRevealTarget> _targets = {};

  void enrol(SearchRevealTarget target) => _targets.add(target);

  void leave(SearchRevealTarget target) => _targets.remove(target);

  @override
  void initState()
  {
    super.initState();
    widget.search?.addListener(_reveal);

    // Another reading of a view already searched.
    if (widget.search?.value != null)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void didUpdateWidget(SearchReveal oldWidget)
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
    if (widget.search?.value == null || !mounted)
    {
      return;
    }

    final found = [
      for (final target in _targets)
        if (target.mounted && target.isSearchFound)
          if (target.context.findRenderObject() case final RenderBox box when box.attached && box.hasSize)
            (context: target.context, box: box, rect: _rectOf(box)),
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
