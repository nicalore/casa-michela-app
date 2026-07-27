import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// Long enough for the eye to follow the fill across the button, short enough
// that a pointer passing over on its way somewhere else does not leave a
// half-filled button behind it.
const Duration _sweepDuration = Duration(milliseconds: 320);

// How much of the width the leading edge of the fill takes to become solid.
// Without it the fill arrives as a hard line, which reads as a rectangle being
// dragged over the button rather than as the button filling up.
const double _feather = 0.16;

// The rounded box of the mockup's button. A caller that stands beside something
// round — a search pill, a bar — passes half its own height instead and comes
// out a pill.
const double _defaultRadius = 14;
const double _borderWidth = 2;

const double _horizontalPadding = 30;
const double _verticalPadding = 15;

// The press is a nudge rather than a squash: a millimetre down and a hair
// smaller, which is what the mockup does and what stops a wide button from
// looking like it is being crushed.
const double _pressedScale = 0.99;
const double _pressedShift = 1;

// The primary button of the app. At rest it is an outline: white, with the
// accent on the border and on the letters. Under the pointer the brand ramp
// floods it from the left, taking the letters white as it passes over them, and
// drains back the same way when the pointer leaves.
//
// It carries the one action a page is really about — changing the password in
// the settings, backing out of the role dialog — so it is the loudest thing a
// surface is allowed to put on itself, and there should never be two of them
// competing on one screen.
class AppGradientButton extends StatefulWidget
{
  final String label;

  final VoidCallback onPressed;

  final IconData? icon;

  // The ramp that floods the button. Defaults to the brand pair; the dialogs
  // that answer for something other than the brand pass their own.
  final LinearGradient gradient;

  // Border, letters and shadow while the button is at rest, so the outline
  // states which ramp is coming before the pointer asks for it.
  final Color accent;

  // Left out the button hugs its label, which is what one standing on its own in
  // the middle of a page wants. Given a width it fills it.
  final double? width;
  final double? height;

  final double fontSize;

  final double radius;

  // While the action is on its way: a turning ring stands where the icon was and
  // the button stops answering. The label does not change, because a button that
  // renames itself mid-press is a button that also changes width, and these
  // stand two to a row.
  final bool busy;

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
    this.busy = false,
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

    // Eased out on the way in and in on the way out, so the fill leaves briskly
    // and settles softly at both ends instead of stopping dead at the edge.
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

  // The two faces of the button hold the same row at the same size, so the
  // letters of one land exactly over the letters of the other and the fill
  // appears to recolour them rather than to replace them.
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
        // Flexible, so a label too long for the room it was given ends in an
        // ellipsis instead of overflowing the button it lives in.
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(contentColor),
          ),
        ),
      ],
    );
  }

  // Everything the fill brings with it — the ramp and the white letters over it
  // — cut off wherever the sweep has got to. dstIn keeps the layer only where
  // the shader is opaque, and the shader is a hard white up to the sweep, a
  // short fade, then nothing.
  Widget _buildFill(double t)
  {
    if (t <= 0)
    {
      return const SizedBox.shrink();
    }

    final Widget fill = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: widget.gradient),
      // The letters up here are the same letters as underneath, painted a
      // second time in white and cut off at the same place as the ground they
      // sit on, which is what makes the fill look like it is recolouring them
      // as it goes past. Only one of the two copies is announced.
      child: ExcludeSemantics(child: _buildFace(Colors.white)),
    );

    if (t >= 1)
    {
      return fill;
    }

    final double edge = t;
    final double solid = math.max(0, edge - _feather);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
        stops: [0, solid, edge, 1],
      ).createShader(bounds),
      child: fill,
    );
  }

  @override
  Widget build(BuildContext context)
  {
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
            // The shift rides on the container's own transform rather than on a
            // slide, which works in fractions of a size this button does not
            // have a fixed one of.
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
                    // The shadow arrives with the fill: an outline sitting flat
                    // on the page has nothing to cast one from.
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.45 * t),
                        offset: Offset(0, 10 * t),
                        blurRadius: 20 * t,
                        spreadRadius: -8 * t,
                      ),
                    ],
                  ),
                  // The label is the only child that counts for layout, so a
                  // button left to itself comes out the size of its own word.
                  //
                  // The fill goes over it, not under: it carries its own copy of
                  // the word in white, and covering the accent one as it travels
                  // is exactly what makes the letters look like they are turning
                  // white under the wave. Underneath, the dark letters would
                  // stay on top of the ramp and nothing would ever turn.
                  //
                  // It needs no inset of its own either. A Container with a
                  // border already lays its child inside that border, so the
                  // fill starts where the outline ends; padding it again is what
                  // left a white ring between the two.
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _horizontalPadding,
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
