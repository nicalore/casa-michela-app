import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// The scale mirrors the database (app/models/teacher.py); change them together.
const double kTeacherRatingMinimum = 0;
const double kTeacherRatingMaximum = 5;
const double kTeacherRatingStep = 0.5;

const int _dotCount = 5;

class TeacherRatingDots extends StatefulWidget
{
  static const double defaultDotSize = 20;

  static const double _gap = 8;

  // One duration for the whole row, not one per dot.
  static const Duration _sweep = Duration(milliseconds: 260);

  static const String _hint =
      'Clicca i pallini per valutare. Clicca due volte il primo mezzo pallino '
      'per azzerare.';

  final double value;

  // Null means read-only.
  final ValueChanged<double>? onChanged;

  final double dotSize;

  const TeacherRatingDots({
    super.key,
    required this.value,
    this.onChanged,
    this.dotSize = defaultDotSize,
  });

  @override
  State<TeacherRatingDots> createState() => _TeacherRatingDotsState();
}

class _TeacherRatingDotsState extends State<TeacherRatingDots>
{
  // Hover preview: the value a click would set right now.
  double? _preview;

  bool get _isEditable => widget.onChanged != null;

  double get _shown => _preview ?? widget.value;

  double get _pointWidth => widget.dotSize + TeacherRatingDots._gap;

  double get _rowWidth => _dotCount * _pointWidth - TeacherRatingDots._gap;

  // A whole point spans dot plus gap; a half point spans half a dot, not half
  // a step, or the cut would not fall mid-dot.
  double _filledWidth(double value)
  {
    final double whole = value.floorToDouble();
    final double part = value - whole;

    return (whole * _pointWidth + part * widget.dotSize).clamp(0, _rowWidth);
  }

  // Left half of a dot is the half point; the right half and its gap the whole.
  double _valueAt(double dx)
  {
    final int index = (dx / _pointWidth).floor().clamp(0, _dotCount - 1);
    final double within = dx - index * _pointWidth;

    return index + (within > widget.dotSize / 2 ? 1 : kTeacherRatingStep);
  }

  void _tapped(double dx)
  {
    final double picked = _valueAt(dx);

    // Zero has no dot: it is reached by tapping the lit half point again.
    final bool zeroing =
        picked == kTeacherRatingStep && widget.value == kTeacherRatingStep;

    setState(() => _preview = null);

    widget.onChanged!(zeroing ? kTeacherRatingMinimum : picked);
  }

  // Drawn twice with the same geometry: empty row below, filled row clipped
  // above.
  Widget _buildDotRow(Widget dot)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < _dotCount; index++) ...[
          if (index > 0) const SizedBox(width: TeacherRatingDots._gap),
          SizedBox(width: widget.dotSize, height: widget.dotSize, child: dot),
        ],
      ],
    );
  }

  Widget _buildDots()
  {
    return SizedBox(
      width: _rowWidth,
      height: widget.dotSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildDotRow(const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppTheme.trialLine, width: 2),
                ),
              ),
            )),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _shown),
            duration: TeacherRatingDots._sweep,
            curve: Curves.easeOutCubic,
            builder: (context, reached, child) => ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: _filledWidth(reached) / _rowWidth,
                child: child,
              ),
            ),
            // The white is never seen: it only tells the mask where colour goes.
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) =>
                  AppTheme.greetingGradient.createShader(bounds),
              child: _buildDotRow(const DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              )),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget dots = _buildDots();

    if (!_isEditable)
    {
      return dots;
    }

    return Tooltip(
      message: TeacherRatingDots._hint,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (event) =>
            setState(() => _preview = _valueAt(event.localPosition.dx)),
        onExit: (_) => setState(() => _preview = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _tapped(details.localPosition.dx),
          child: dots,
        ),
      ),
    );
  }
}
