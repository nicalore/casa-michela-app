import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'calendar_pdf_palette.dart';

const double kNameColumnWidth = 128;

const double kRowPadding = 4;
const double kSubLaneGap = 3;
const double kBlockGap = 1.5;

const double kBlockChrome = 2 * kBlockGap + 2 * 3;

double atMinuteOfTrack(int minute, {required int windowStart, required int windowEnd, required double track})
{
  final clamped = minute.clamp(windowStart, windowEnd);

  return track * (clamped - windowStart) / (windowEnd - windowStart);
}

class CalendarPdfTrackRow extends pw.MultiChildWidget
{
  CalendarPdfTrackRow({
    required this.name,
    required this.blocks,
    required this.spans,
    required this.laneOf,
    required this.laneCount,
    required this.windowStart,
    required this.windowEnd,
    required this.striped,
  }) : super(children: [name, ...blocks]);

  final pw.Widget name;

  final List<pw.Widget> blocks;

  final List<(int, int)> spans;

  final List<int> laneOf;
  final int laneCount;

  final int windowStart;
  final int windowEnd;

  final bool striped;

  final List<PdfPoint> _offsets = [];

  double _trackWidth(double width) => width - kNameColumnWidth;

  double _atMinute(int minute, double track) => atMinuteOfTrack(
        minute,
        windowStart: windowStart,
        windowEnd: windowEnd,
        track: track,
      );

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false})
  {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    final track = _trackWidth(width);

    name.layout(
      context,
      pw.BoxConstraints(minWidth: kNameColumnWidth, maxWidth: kNameColumnWidth),
      parentUsesSize: true,
    );

    _offsets.clear();

    final widths = <double>[];
    final lefts = <double>[];
    final laneHeights = List<double>.filled(math.max(laneCount, 1), 0);

    for (var i = 0; i < blocks.length; i++)
    {
      final left = _atMinute(spans[i].$1, track);
      final right = _atMinute(spans[i].$2, track);
      final span = math.max(right - left - 2 * kBlockGap, 1.0);

      blocks[i].layout(
        context,
        pw.BoxConstraints(minWidth: span, maxWidth: span),
        parentUsesSize: true,
      );

      lefts.add(left);
      widths.add(span);
      laneHeights[laneOf[i]] = math.max(laneHeights[laneOf[i]], blocks[i].box!.height);
    }

    final stacked = laneHeights.fold<double>(0, (total, height) => total + height) +
        (laneHeights.length - 1) * kSubLaneGap;

    final height = math.max(stacked, name.box!.height) + 2 * kRowPadding;

    box = PdfRect(0, 0, width, height);

    _offsets.add(PdfPoint(0, height - kRowPadding - name.box!.height));

    final laneTops = <double>[];
    var top = height - kRowPadding;

    for (final laneHeight in laneHeights)
    {
      laneTops.add(top);
      top -= laneHeight + kSubLaneGap;
    }

    for (var i = 0; i < blocks.length; i++)
    {
      _offsets.add(PdfPoint(
        kNameColumnWidth + lefts[i] + kBlockGap,
        laneTops[laneOf[i]] - blocks[i].box!.height,
      ));
    }
  }

  @override
  void paint(pw.Context context)
  {
    super.paint(context);

    _paintGround(context);

    for (var i = 0; i < children.length; i++)
    {
      final child = children[i];

      child.box = PdfRect(
        box!.left + _offsets[i].x,
        box!.bottom + _offsets[i].y,
        child.box!.width,
        child.box!.height,
      );

      child.paint(context);
    }
  }

  void _paintGround(pw.Context context)
  {
    final left = box!.left;
    final bottom = box!.bottom;
    final width = box!.width;
    final height = box!.height;
    final track = _trackWidth(width);

    if (striped)
    {
      context.canvas
        ..setFillColor(kPdfBand)
        ..drawRect(left, bottom, width, height)
        ..fillPath();
    }

    for (var minute = _firstMark(); minute < windowEnd; minute += 30)
    {
      final x = left + kNameColumnWidth + _atMinute(minute, track);
      final isHour = minute % 60 == 0;

      context.canvas
        ..setStrokeColor(isHour ? kPdfRule : kPdfLine)
        ..setLineWidth(isHour ? 0.7 : 0.35)
        ..moveTo(x, bottom)
        ..lineTo(x, bottom + height)
        ..strokePath();
    }

    context.canvas
      ..setStrokeColor(kPdfLine)
      ..setLineWidth(0.4)
      ..moveTo(left, bottom)
      ..lineTo(left + width, bottom)
      ..strokePath();
  }

  int _firstMark()
  {
    final remainder = windowStart % 30;

    return remainder == 0 ? windowStart + 30 : windowStart + (30 - remainder);
  }
}
