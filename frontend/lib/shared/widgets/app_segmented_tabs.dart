import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// How long the pill takes to cross, and how it moves. Everything in the control
// that answers a tap — the pill, the words — runs on these two, so the whole of
// it arrives at once.
const Duration kSegmentedSlide = Duration(milliseconds: 240);
const Curve kSegmentedSlideCurve = Curves.easeOutCubic;

// The ground the pill sits in, and the air around the pill inside it.
const double _padding = 3;
const double _segmentPadding = 18;

// The outline the ground always carries — gold under the pointer, invisible
// otherwise — counted here because it takes room from the inside of the control
// and the rows have to be packed into what is left.
const double _borderWidth = 1.5;

// Between one row of words and the next, where they have wrapped.
const double _rowGap = 3;

// One row, several words, and a white pill that slides to the one chosen — what
// the app changes view with. Loose pills mean something else here, and one shape
// for both made two gestures look like one.
//
// Segments are as wide as their words: equal halves suit a yes-or-no, but seven
// wizard cards would be wider than the window. Too many and they wrap, since
// sliding left a word half in and half out at the edge of the card.
class AppSegmentedTabs extends StatefulWidget
{
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  // The height of the whole control. Tabs stand over a page and take the
  // larger of the two; a yes-or-no at the end of a row takes the smaller.
  final double height;

  final double fontSize;

  // The air the control leaves under itself, where it stands over what it
  // chooses.
  final EdgeInsets padding;

  // Off, all the width given, at the left, which is what a row of tabs wants.
  // On, only the width of its words, so a piece is measured from its widest line
  // instead of being stretched by a control two syllables wide. Still wraps.
  final bool hugContent;

  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 44,
    this.fontSize = 14,
    this.padding = const EdgeInsets.only(bottom: 24),
    this.hugContent = false,
  });

  @override
  State<AppSegmentedTabs> createState() => _AppSegmentedTabsState();
}

class _AppSegmentedTabsState extends State<AppSegmentedTabs>
{
  // What each segment is wide, measured off the words themselves. Both weights
  // are the same, so a segment does not change width when it is chosen and the
  // ones beside it do not shuffle.
  List<double> _widths = const [];

  bool _hover = false;

  @override
  void initState()
  {
    super.initState();

    // The fonts of this app are loaded after the first frame, and a word
    // measured in the fallback font is not the width it will be drawn at. The
    // same listener the overflow labels use puts it right once they arrive.
    PaintingBinding.instance.systemFonts.addListener(_measureAll);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _measureAll();
  }

  @override
  void didUpdateWidget(AppSegmentedTabs oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.labels, widget.labels) ||
        oldWidget.labels.length != widget.labels.length ||
        oldWidget.fontSize != widget.fontSize)
    {
      _measureAll();
    }

  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_measureAll);
    super.dispose();
  }

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
      );

  void _measureAll()
  {
    if (!mounted)
    {
      return;
    }

    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;

    final measured = [
      for (final label in widget.labels) _measure(label, scaler),
    ];

    if (measured.length == _widths.length)
    {
      var same = true;

      for (var index = 0; index < measured.length; index++)
      {
        if ((measured[index] - _widths[index]).abs() > 0.5)
        {
          same = false;
          break;
        }
      }

      if (same)
      {
        return;
      }
    }

    setState(() => _widths = measured);
  }

  double _measure(String label, TextScaler scaler)
  {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();

    return painter.width + 2 * _segmentPadding;
  }

  // Split into rows greedily from the left, which is the order they are read in.
  // A word wider than a row keeps its own and is squeezed to it: losing the tail
  // of a word beats breaking out of the card.
  List<List<int>> _pack(List<double> widths, double available)
  {
    final rows = <List<int>>[];
    var row = <int>[];
    var used = 0.0;

    for (var index = 0; index < widths.length; index++)
    {
      if (row.isNotEmpty && used + widths[index] > available)
      {
        rows.add(row);
        row = <int>[];
        used = 0;
      }

      row.add(index);
      used += widths[index];
    }

    if (row.isNotEmpty)
    {
      rows.add(row);
    }

    return rows;
  }

  Widget _buildSegment(int index, double width)
  {
    final active = index == widget.selectedIndex;

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Each segment picks itself rather than the row toggling: the one thing
        // nobody means to do is unchoose what they are looking at.
        onTap: () => widget.onSelected(index),
        child: Center(
          // The words change colour over the same moment the pill takes to
          // reach them, so the whole control arrives at once.
          child: AnimatedDefaultTextStyle(
            duration: kSegmentedSlide,
            curve: kSegmentedSlideCurve,
            style: _labelStyle.copyWith(
              color: active ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
            ),
            child: Text(
              widget.labels[index],
              maxLines: 1,
              softWrap: false,
              // Only ever reached by a word wider than the whole row: see the
              // note on the packing above.
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // Where the pill stands: along its row, and down the rows. Both are animated,
  // so a choice made on another row is walked to rather than jumped to.
  Widget _buildPill(List<List<int>> rows, List<double> widths, double rowHeight)
  {
    final index = widget.selectedIndex.clamp(0, widths.length - 1);

    var left = 0.0;
    var top = 0.0;

    for (var r = 0; r < rows.length; r++)
    {
      final int at = rows[r].indexOf(index);

      if (at < 0)
      {
        continue;
      }

      top = r * (rowHeight + _rowGap);
      left = 0;

      for (var i = 0; i < at; i++)
      {
        left += widths[rows[r][i]];
      }

      break;
    }

    return AnimatedPositioned(
      duration: kSegmentedSlide,
      curve: kSegmentedSlideCurve,
      left: left,
      top: top,
      width: widths[index],
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(rowHeight / 2),
          boxShadow: AppTheme.cardShadow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_widths.length != widget.labels.length)
    {
      // The first frame, before the words have been measured: the room the
      // control will take, and nothing drawn in it yet.
      return Padding(
        padding: widget.padding,
        child: SizedBox(height: widget.height),
      );
    }

    // The words are measured, so one row's width is known before layout.
    // Capping there is what lets the control be its own size: the builder below
    // fills its constraints. A ceiling and not a size — a narrower piece wins.
    final double oneRow = _widths.fold<double>(0, (sum, width) => sum + width) +
        2 * (_padding + _borderWidth);

    final Widget control = LayoutBuilder(
        builder: (context, constraints)
        {
          // What is left of the room once the ground has taken its outline and
          // its air: the rows are packed into the inside of the control, so the
          // outside of it ends where the card does.
          final double available =
              constraints.maxWidth - 2 * (_padding + _borderWidth);

          // A word wider than the whole row is brought down to it. Everything
          // downstream — the packing, the pill, the segments — reads these and
          // not the measurements, so the three cannot disagree.
          final List<double> widths = [
            for (final width in _widths) math.min(width, available),
          ];

          final List<List<int>> rows = _pack(widths, available);

          // What is left of the declared height once border and padding are
          // taken off: a Container adds both to its child, so counting only one
          // made the control three pixels taller than it claims to be.
          final double rowHeight = widget.height - 2 * (_padding + _borderWidth);
          final double ground = rows
              .map((row) => row.fold<double>(0, (sum, i) => sum + widths[i]))
              .reduce(math.max);

          return Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: AnimatedContainer(
                duration: kSegmentedSlide,
                curve: kSegmentedSlideCurve,
                padding: const EdgeInsets.all(_padding),
                decoration: BoxDecoration(
                  color: AppTheme.closedSurface,
                  // Rounded by half a row either way, so wrapping changes the
                  // height of the control and not its shape.
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  // Gold under the pointer, which is what the rest of the app
                  // does.
                  border: Border.all(
                    color: _hover
                        ? AppTheme.trialGold
                        : AppTheme.trialGold.withValues(alpha: 0),
                    width: _borderWidth,
                  ),
                ),
                child: SizedBox(
                  width: ground,
                  height: rows.length * rowHeight + (rows.length - 1) * _rowGap,
                  child: Stack(
                    children: [
                      _buildPill(rows, widths, rowHeight),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var r = 0; r < rows.length; r++) ...[
                            if (r > 0) const SizedBox(height: _rowGap),
                            SizedBox(
                              height: rowHeight,
                              child: Row(
                                children: [
                                  for (final index in rows[r])
                                    _buildSegment(index, widths[index]),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

    return Padding(
      padding: widget.padding,
      child: widget.hugContent
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: oneRow),
              child: control,
            )
          : control,
    );
  }
}
