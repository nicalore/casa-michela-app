import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../people/tabs/statistics/widgets/chart_value_popup.dart';
import '../../people/tabs/statistics/widgets/stat_widgets.dart';

const double _rowHeight = 36;
const double _denseRowHeight = 32;
const double _barHeight = 14;
const double _namesShare = 0.28;
const double _namesMax = 240;
const double _gap = 12;

// Inside a row, as the statistics' bars laid across.
const double _rowInset = 6;
const double _hoverRadius = 8;
const double _fontSize = 12.5;

Color get _hoverColor => AppTheme.chartOcean.withValues(alpha: 0.06);

// One signed bar per row about a zero line: losses to the left in lilac, the rest to the right.
// The hovered row lights up and its popup stands on the bar's end.
class MarginBars extends StatefulWidget
{
  final List<String> names;
  final List<int> cents;
  final Widget Function(int index) tooltip;

  const MarginBars({super.key, required this.names, required this.cents, required this.tooltip});

  @override
  State<MarginBars> createState() => _MarginBarsState();
}

class _MarginBarsState extends State<MarginBars>
{
  int? _hovered;

  // Survives the pointer leaving, so the popup fades out in place.
  int _shown = 0;

  TextStyle _nameStyle(bool hovered) => GoogleFonts.plusJakartaSans(
        fontSize: _fontSize,
        fontWeight: hovered ? FontWeight.w700 : FontWeight.w600,
        color: hovered ? AppTheme.trialOceanText : AppTheme.trialInk,
      );

  TextStyle _amountStyle(int cents) => GoogleFonts.plusJakartaSans(
        fontSize: _fontSize,
        fontWeight: FontWeight.w700,
        color: cents < 0 ? AppTheme.chartViolet : AppTheme.trialOceanText,
      );

  double _labelRoom(BuildContext context)
  {
    double widest = 0;

    for (final cents in widget.cents)
    {
      final painter = TextPainter(
        text: TextSpan(text: formatSignedAmount(cents), style: _amountStyle(cents)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();

      widest = math.max(widest, painter.width);
    }

    return widest + _gap;
  }

  void _hover(int? index)
  {
    setState(()
    {
      _hovered = index;
      _shown = index ?? _shown;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final double rowHeight = StatMetrics.of(context).dense ? _denseRowHeight : _rowHeight;
    final double labelRoom = _labelRoom(context);
    final int low = widget.cents.fold(0, math.min);
    final int high = widget.cents.fold(0, math.max);
    final int range = math.max(1, high - low);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth;
        final double namesWidth = math.min(width * _namesShare, _namesMax);
        final double plotLeft = _rowInset + namesWidth + _gap + labelRoom;
        final double plot = math.max(0, width - _rowInset - labelRoom - plotLeft);
        final double zero = plotLeft + plot * -low / range;
        final double barTop = (rowHeight - _barHeight) / 2;

        double lengthOf(int index) => plot * widget.cents[index].abs() / range;

        double tipOf(int index) => widget.cents[index] < 0 ? zero - lengthOf(index) : zero + lengthOf(index);

        Widget row(int index)
        {
          final int cents = widget.cents[index];
          final bool hovered = index == _hovered;
          final double length = lengthOf(index);
          final bool loss = cents < 0;

          return MouseRegion(
            onEnter: (_) => _hover(index),
            onExit: (_) => _hover(_hovered == index ? null : _hovered),
            child: Container(
              height: rowHeight,
              decoration: BoxDecoration(
                color: hovered ? _hoverColor : null,
                borderRadius: BorderRadius.circular(_hoverRadius),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: _rowInset,
                    width: namesWidth,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OverflowTooltipText(text: widget.names[index], maxLines: 1, style: _nameStyle(hovered)),
                    ),
                  ),
                  Positioned(
                    left: zero - 0.5,
                    width: 1,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(color: AppTheme.trialMutedText.withValues(alpha: 0.35)),
                  ),
                  Positioned(
                    left: loss ? zero - length : zero,
                    width: length,
                    top: barTop,
                    height: _barHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: loss ? AppTheme.chartLilac : AppTheme.chartOcean,
                        borderRadius: BorderRadius.circular(_barHeight / 2 - 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: loss ? zero - length - labelRoom : zero + length + _gap / 2,
                    width: labelRoom - _gap / 2,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: loss ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(formatSignedAmount(cents), maxLines: 1, softWrap: false, style: _amountStyle(cents)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Another period may bring fewer rows.
        final int shown = math.min(_shown, widget.cents.length - 1);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (var index = 0; index < widget.cents.length; index++) row(index)],
            ),
            if (widget.cents.isNotEmpty)
              ChartValuePopup(
                target: Offset(tipOf(shown), shown * rowHeight + barTop),
                content: widget.tooltip(shown),
                isVisible: _hovered != null,
              ),
          ],
        );
      },
    );
  }
}
