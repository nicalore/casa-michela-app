import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/search_reveal.dart';
import '../utils/calendar_search.dart';

export '../../../shared/widgets/search_reveal.dart' show SearchReveal, kSearchFade, kSearchMissOpacity;

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
mixin CalendarSearchMarks<T extends StatefulWidget> on State<T> implements SearchRevealTarget
{
  ValueListenable<CalendarSearch?>? searchOf(T widget);

  bool isFoundBy(CalendarSearch search);

  ({bool found, bool missed}) _marks = (found: false, missed: false);

  SearchRevealState? _revealer;

  ({bool found, bool missed}) get searchMarks
  {
    final search = searchOf(widget)?.value;
    final found = search != null && isFoundBy(search);

    return (found: found, missed: search != null && !found);
  }

  @override
  bool get isSearchFound => searchMarks.found;

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
    _revealer = SearchReveal.maybeOf(context);
    _revealer?.enrol(this);
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
    _revealer?.leave(this);
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
