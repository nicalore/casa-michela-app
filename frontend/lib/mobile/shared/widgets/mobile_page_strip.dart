import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';
import 'mobile_pill.dart';

const double _fontSize = 15;
const double _gap = 20;
const double _underlineHeight = 3;
const double _underlineGap = 7;

const Duration _switchDuration = Duration(milliseconds: 320);

const double _fadeWidth = 44;

const LinearGradient _goldRule = LinearGradient(
  colors: [AppTheme.trialGold, Color(0xFFF3C766)],
);

TextStyle _labelStyle(Color color)
{
  return GoogleFonts.plusJakartaSans(
    fontSize: _fontSize,
    fontWeight: FontWeight.w700,
    color: color,
  );
}

class MobilePageStrip extends StatefulWidget
{
  final List<String> labels;
  final PageController controller;

  // Sections not built yet: no page, no tap.
  final List<String> comingSoon;

  // Set, the row scrolls sideways; null, the names shrink to fit.
  final double? scrollMargin;

  final bool onLight;

  const MobilePageStrip({
    super.key,
    required this.labels,
    required this.controller,
    this.comingSoon = const [],
    this.scrollMargin,
    this.onLight = false,
  });

  @override
  State<MobilePageStrip> createState() => _MobilePageStripState();
}

class _MobilePageStripState extends State<MobilePageStrip>
{
  // Set while a tap animates; null during a swipe.
  (int, int)? _jump;

  // Bumped per tap, so a jump cut short by the next one does not clear it.
  int _jumpToken = 0;

  final ScrollController _scroll = ScrollController();

  // Measured in build, read by _follow between frames.
  List<double> _lefts = const [];
  List<double> _widths = const [];

  @override
  void initState()
  {
    super.initState();

    widget.controller.addListener(_follow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
  }

  @override
  void didUpdateWidget(MobilePageStrip oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller)
    {
      oldWidget.controller.removeListener(_follow);
      widget.controller.addListener(_follow);
    }
  }

  @override
  void dispose()
  {
    widget.controller.removeListener(_follow);
    _scroll.dispose();

    super.dispose();
  }

  void _follow()
  {
    final double? margin = widget.scrollMargin;

    if (margin == null || !_scroll.hasClients || _lefts.isEmpty)
    {
      return;
    }

    final (int from, int to, double t) = _span();
    final double left = ui.lerpDouble(_lefts[from], _lefts[to], t)!;
    final double right = left + ui.lerpDouble(_widths[from], _widths[to], t)!;

    final ScrollPosition position = _scroll.position;
    double target = position.pixels;

    if (right + margin * 2 > target + position.viewportDimension)
    {
      target = right + margin * 2 - position.viewportDimension;
    }

    if (left < target)
    {
      target = left;
    }

    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);

    if (target != position.pixels)
    {
      position.jumpTo(target);
    }
  }

  void _go(int index)
  {
    final int from = _page.round();

    if (index == from)
    {
      return;
    }

    final int token = ++_jumpToken;

    setState(() => _jump = (from, index));

    widget.controller
        .animateToPage(index, duration: _switchDuration, curve: Curves.easeOutCubic)
        .whenComplete(()
    {
      if (mounted && token == _jumpToken)
      {
        setState(() => _jump = null);
      }
    });
  }

  double get _page
  {
    final PageController controller = widget.controller;

    return controller.hasClients && controller.position.haveDimensions
        ? controller.page ?? controller.initialPage.toDouble()
        : controller.initialPage.toDouble();
  }

  // A tap skips the names in between; a swipe spans the pages either side.
  (int, int, double) _span()
  {
    final double page = _page;
    final (int, int)? jump = _jump;

    if (jump == null)
    {
      final int low = page.floor().clamp(0, widget.labels.length - 1);
      final int high = page.ceil().clamp(0, widget.labels.length - 1);

      return (low, high, page - low);
    }

    final (int from, int to) = jump;

    return (from, to, from == to ? 0 : ((page - from) / (to - from)).clamp(0.0, 1.0));
  }

  // Measured over the ambient style, whose letter spacing the drawn names inherit.
  double _widthOf(String text, TextStyle ambient, TextScaler scaler)
  {
    final painter = TextPainter(
      text: TextSpan(text: text, style: ambient.merge(_labelStyle(Colors.white))),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    return painter.width;
  }

  @override
  Widget build(BuildContext context)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final List<double> widths = [for (final label in widget.labels) _widthOf(label, ambient, scaler)];

    final List<double> lefts = [];
    double x = 0;

    for (final width in widths)
    {
      lefts.add(x);
      x += width + _gap;
    }

    _lefts = lefts;
    _widths = widths;

    final Color lit = widget.onLight ? AppTheme.trialInk : Colors.white;
    final Color unlit = widget.onLight ? MobilePalette.mutedText : Colors.white.withValues(alpha: 0.55);

    final Widget names = AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _)
      {
        final (int from, int to, double t) = _span();

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: _underlineGap + _underlineHeight),
              child: Row(
                children: [
                  for (var i = 0; i < widget.labels.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(i),
                      child: Text(
                        widget.labels[i],
                        style: _labelStyle(
                          Color.lerp(
                            unlit,
                            lit,
                            i == from ? 1 - t : (i == to ? t : 0),
                          )!,
                        ),
                      ),
                    ),
                  ],
                  for (final label in widget.comingSoon) ...[
                    const SizedBox(width: _gap),
                    _ComingSoon(label: label, color: unlit, onLight: widget.onLight),
                  ],
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: ui.lerpDouble(lefts[from], lefts[to], t),
              width: ui.lerpDouble(widths[from], widths[to], t),
              height: _underlineHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _goldRule,
                  borderRadius: BorderRadius.all(Radius.circular(_underlineHeight / 2)),
                ),
              ),
            ),
          ],
        );
      },
    );

    final double? margin = widget.scrollMargin;

    if (margin == null)
    {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: names,
      );
    }

    return _FadingEdges(
      scroll: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: names,
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget
{
  final String label;
  final Color color;
  final bool onLight;

  const _ComingSoon({required this.label, required this.color, required this.onLight});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle(color)),
        const SizedBox(width: 7),
        MobilePill('In arrivo', tone: onLight ? MobilePillTone.teal : MobilePillTone.sea),
      ],
    );
  }
}

class _FadingEdges extends StatelessWidget
{
  final ScrollController scroll;
  final Widget child;

  const _FadingEdges({required this.scroll, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: scroll,
      builder: (context, child)
      {
        final bool measured = scroll.hasClients && scroll.position.hasContentDimensions;
        final double pixels = measured ? scroll.position.pixels : 0;

        final bool before = measured && pixels > scroll.position.minScrollExtent;
        final bool after = measured && pixels < scroll.position.maxScrollExtent;

        if (!before && !after)
        {
          return child!;
        }

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds)
          {
            final double fade = _fadeWidth / bounds.width;

            return LinearGradient(
              colors: [
                before ? Colors.transparent : Colors.white,
                Colors.white,
                Colors.white,
                after ? Colors.transparent : Colors.white,
              ],
              stops: [0, fade, 1 - fade, 1],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }
}

// Static counterpart of MobilePageStrip, for tablet section heads.
class MobilePageLabel extends StatelessWidget
{
  final String text;

  const MobilePageLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: _labelStyle(Colors.white)),
          const SizedBox(height: _underlineGap),
          Container(
            height: _underlineHeight,
            decoration: const BoxDecoration(
              gradient: _goldRule,
              borderRadius: BorderRadius.all(Radius.circular(_underlineHeight / 2)),
            ),
          ),
        ],
      ),
    );
  }
}
