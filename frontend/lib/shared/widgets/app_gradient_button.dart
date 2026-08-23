import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration _sweepDuration = Duration(milliseconds: 320);

const double _feather = 0.16;

const double _defaultRadius = 14;
const double _borderWidth = 2;

const double _horizontalPadding = 30;
const double _verticalPadding = 15;

const double _pressedScale = 0.99;
const double _pressedShift = 1;

class AppGradientButton extends StatefulWidget
{
  final String label;

  final VoidCallback onPressed;

  final IconData? icon;

  final LinearGradient gradient;

  final Color accent;

  final double? width;
  final double? height;

  final double fontSize;

  final double radius;

  final double horizontalPadding;

  final bool busy;

  final String? disabledReason;

  const AppGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppTheme.brandGradient,
    this.accent = AppTheme.trialTealDeep,
    this.width,
    this.height,
    this.fontSize = 17,
    this.radius = _defaultRadius,
    this.horizontalPadding = _horizontalPadding,
    this.busy = false,
    this.disabledReason,
  });

  @override
  State<AppGradientButton> createState() => _AppGradientButtonState();
}

class _AppGradientButtonState extends State<AppGradientButton>
    with SingleTickerProviderStateMixin
{
  late final AnimationController _controller;
  late final Animation<double> _sweep;

  bool _pressed = false;

  @override
  void initState()
  {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _sweepDuration);

    _sweep = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _labelStyle(Color color)
  {
    return GoogleFonts.plusJakartaSans(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 1.1,
      color: color,
    );
  }

  Widget _buildFace(Color contentColor)
  {
    final double glyphSize = widget.fontSize + 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy) ...[
          SizedBox(
            width: glyphSize,
            height: glyphSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: contentColor),
          ),
          const SizedBox(width: 8),
        ]
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: glyphSize, color: contentColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(contentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildFill(double t)
  {
    if (t <= 0)
    {
      return const SizedBox.shrink();
    }

    final Widget fill = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: widget.gradient),
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
        vertical: widget.height == null ? _verticalPadding : 0,
      ),
      child: ExcludeSemantics(child: _buildFace(Colors.white)),
    );

    final double edge = t * (1 + _feather);
    final double solid = edge - _feather;

    if (solid >= 1)
    {
      return fill;
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
        stops: [0, math.max(0, solid), math.min(edge, 1), 1],
      ).createShader(bounds),
      child: fill,
    );
  }

  Widget _buildDisabled(String reason)
  {
    return Tooltip(
      message: reason,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: widget.height == null ? _verticalPadding : 0,
          ),
          decoration: BoxDecoration(
            color: AppTheme.arrowDisabledSurface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: AppTheme.trialLine, width: _borderWidth),
          ),
          child: _buildFace(AppTheme.trialMutedText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final reason = widget.disabledReason;

    if (reason != null)
    {
      return _buildDisabled(reason);
    }

    return MouseRegion(
      cursor: widget.busy ? SystemMouseCursors.progress : SystemMouseCursors.click,
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTapDown: widget.busy ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.busy ? null : (_) => setState(() => _pressed = false),
        onTapCancel: widget.busy ? null : () => setState(() => _pressed = false),
        onTap: widget.busy ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? _pressedScale : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _pressed ? _pressedShift : 0, 0),
            transformAlignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, child)
              {
                final double t = _sweep.value;

                return Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(color: widget.accent, width: _borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.45 * t),
                        offset: Offset(0, 10 * t),
                        blurRadius: 20 * t,
                        spreadRadius: -8 * t,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.horizontalPadding,
                          vertical: widget.height == null ? _verticalPadding : 0,
                        ),
                        child: child,
                      ),
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(widget.radius - _borderWidth),
                          child: _buildFill(t),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: _buildFace(widget.accent),
            ),
          ),
        ),
      ),
    );
  }
}
