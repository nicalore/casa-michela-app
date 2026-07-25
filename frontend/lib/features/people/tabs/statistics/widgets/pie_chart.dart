import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';
import 'chart_common.dart';
import 'chart_value_popup.dart';

// Cycled when there are more slices than colours.
const List<Color> _sliceColors = [
  Color(0xFF003C82),
  Color(0xFF0284C7),
  Color(0xFF38BDF8),
  Color(0xFF818CF8),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
];

const double _ringThickness = 30.0;

// Angular gap between slices, in radians. Dropped when there is a single slice,
// which would otherwise show a seam in a full circle.
const double _sliceGap = 0.04;

// Tolerance around the ring for hover detection: a few pixels outside and most
// of the thickness inside, so thin slices stay reachable.
const double _hoverOuterTolerance = 15.0;
const double _hoverInnerTolerance = 35.0;

class PieChart extends StatefulWidget
{
  final List<ChartDatum> data;

  const PieChart({super.key, required this.data});

  @override
  State<PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<PieChart>
{
  Offset? _popupTarget;
  int? _hoveredIndex;
  String? _popupText;

  int get _total => widget.data.fold(0, (sum, item) => sum + item.count);

  // Walks the slices accumulating their angles and returns the one containing the
  // pointer, or null when the pointer is outside the ring.
  int? _sliceAt(Offset position, Offset center, double radius, int total)
  {
    final delta = position - center;
    final distance = delta.distance;

    if (distance > radius + _hoverOuterTolerance || distance < radius - _hoverInnerTolerance)
    {
      return null;
    }

    final angle = math.atan2(delta.dy, delta.dx);
    final normalizedAngle = angle < 0 ? angle + 2 * math.pi : angle;
    final gap = widget.data.length > 1 ? _sliceGap : 0.0;

    var startAngle = -math.pi / 2;

    for (var i = 0; i < widget.data.length; i++)
    {
      final sweepAngle = (widget.data[i].count / total) * 2 * math.pi;
      final sliceStart = startAngle < 0 ? startAngle + 2 * math.pi : startAngle;
      final sliceEnd = sliceStart + sweepAngle - gap;

      // A slice crossing the zero angle has to be tested as two ranges.
      if (sliceEnd > 2 * math.pi)
      {
        if (normalizedAngle >= sliceStart || normalizedAngle <= sliceEnd - 2 * math.pi)
        {
          return i;
        }
      }
      else if (normalizedAngle >= sliceStart && normalizedAngle <= sliceEnd)
      {
        return i;
      }

      startAngle += sweepAngle;
    }

    return null;
  }

  void _onHover(Offset position, Offset center, double radius, int total)
  {
    final foundIndex = _sliceAt(position, center, radius, total);

    setState(()
    {
      _hoveredIndex = foundIndex;

      if (foundIndex != null)
      {
        final datum = widget.data[foundIndex];
        final share = total == 0 ? 0.0 : datum.count / total * 100;

        // The popup follows the pointer here rather than the slice: a ring
        // segment has no single obvious anchor point.
        _popupTarget = position;
        _popupText = '${datum.label}: ${datum.count} (${share.toStringAsFixed(1)}%)';
      }
    });
  }

  Widget _buildLegendEntry(int index, int total)
  {
    final datum = widget.data[index];
    final share = total == 0 ? 0.0 : datum.count / total * 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _sliceColors[index % _sliceColors.length],
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OverflowTooltipText(
              text: '${datum.label} (${share.toStringAsFixed(1)}%)',
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate800,
              ),
              textSpan: TextSpan(
                children: [
                  TextSpan(
                    text: '${datum.label} ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate800,
                    ),
                  ),
                  TextSpan(
                    text: '(${share.toStringAsFixed(1)}%)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final total = _total;

    // Ring and legend occupy two separate flex regions, which makes it
    // structurally impossible for them to overlap however long the labels are.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, constraints)
            {
              final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
              final radius = math.max(
                20.0,
                math.min(constraints.maxWidth, constraints.maxHeight) / 2 - 16,
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: MouseRegion(
                      onHover: (event) => _onHover(event.localPosition, center, radius, total),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _PieChartPainter(
                          data: widget.data,
                          total: total,
                          center: center,
                          radius: radius,
                          hoveredIndex: _hoveredIndex,
                        ),
                      ),
                    ),
                  ),
                  if (_popupTarget != null)
                    ChartValuePopup(
                      target: _popupTarget!,
                      text: _popupText ?? '',
                      isVisible: _hoveredIndex != null,
                      verticalOffset: 15,
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        // Scrollable, so a long list of categories never overflows vertically.
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.data.length; i++) _buildLegendEntry(i, total),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter
{
  final List<ChartDatum> data;
  final int total;
  final Offset center;
  final double radius;
  final int? hoveredIndex;

  _PieChartPainter({
    required this.data,
    required this.total,
    required this.center,
    required this.radius,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    if (data.isEmpty || total == 0)
    {
      return;
    }

    final gap = data.length > 1 ? _sliceGap : 0.0;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < data.length; i++)
    {
      final sweepAngle = (data[i].count / total) * 2 * math.pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        math.max(0, sweepAngle - gap),
        false,
        Paint()
          ..color = _sliceColors[i % _sliceColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringThickness
          ..strokeCap = StrokeCap.butt,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate)
  {
    return oldDelegate.hoveredIndex != hoveredIndex || oldDelegate.data != data;
  }
}