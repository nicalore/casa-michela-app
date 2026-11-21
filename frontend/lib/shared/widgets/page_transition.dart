import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import 'casa_michela_loader.dart';
import 'scroll_edge_fade.dart';

const Duration _pageTransition = Duration(milliseconds: 1200);

const double _slotDelay = 0.024;
const int _lastDelayedSlot = 11;

const double _waveDown = 0.15;
const double _waveAcross = 0.075;

const double _exitSpan = 0.22;
const double _enterStart = 0.40;
const double _enterSpan = 0.32;

const double _listWait = PageTransitionItem.list * _slotDelay;

const double _slotSpread = _listWait + _waveDown + _waveAcross;

const double _exitEnd = _slotSpread + _exitSpan;
const double _enterEnd = _enterStart + _slotSpread + _enterSpan;

const double _reentryTurn = 0.5;

// Share of a screen transition over which the cover rises; opaque from then until it falls.
const double _coverRise = 0.35;
const double _coverHold = 0.30;

double _reentryProgress(double value)
{
  return value < _reentryTurn
      ? value / _reentryTurn * _exitEnd
      : _enterStart + (value - _reentryTurn) / (1 - _reentryTurn) * (_enterEnd - _enterStart);
}

const double _arrivalFadeStart = 0.36;
const double _arrivalFadeEnd = 0.46;

const double _runUp = 22;
const double _runUpShare = 0.32;

const double _overshoot = 7;
const double _overshootShare = 0.84;

double _exitTravel(double width) => (width * 0.50).clamp(260.0, 760.0);

double _enterTravel(double width) => (width * 0.22).clamp(130.0, 340.0);

Page<void> buildAppTransitionPage({
  required LocalKey key,
  required Widget child,
})
{
  return _AppTransitionPage(key: key, child: child);
}

class _AppTransitionPage extends Page<void>
{
  final Widget child;

  const _AppTransitionPage({required super.key, required this.child});

  @override
  Route<void> createRoute(BuildContext context) => _AppTransitionRoute(this);
}

// Reads the effects switch at each push and pop: a screen outlives a switch made while it is open.
class _AppTransitionRoute extends PageRoute<void>
{
  bool _plain = !VisualEffects.on;

  _AppTransitionRoute(_AppTransitionPage page) : super(settings: page);

  @override
  Duration get transitionDuration => _plain ? Duration.zero : _pageTransition;

  // Opaque once settled: the covered route stops painting and ticking.
  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  void _takeEffects()
  {
    _plain = !VisualEffects.on;
    controller!
      ..duration = transitionDuration
      ..reverseDuration = transitionDuration;
  }

  @override
  TickerFuture didPush()
  {
    _takeEffects();

    return super.didPush();
  }

  @override
  bool didPop(void result)
  {
    _takeEffects();

    return super.didPop(result);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation)
  {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: (settings as _AppTransitionPage).child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  )
  {
    if (_plain)
    {
      return child;
    }

    return _ProbedTransition(
      animation: animation,
      child: _ScreenTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
    );
  }
}

class _ProbedTransition extends StatefulWidget
{
  final Animation<double> animation;
  final Widget child;

  const _ProbedTransition({required this.animation, required this.child});

  @override
  State<_ProbedTransition> createState() => _ProbedTransitionState();
}

class _ProbedTransitionState extends State<_ProbedTransition>
{
  final TransitionProbe _probe = TransitionProbe();

  @override
  void initState()
  {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
    // The push started before this was built.
    _onStatus(widget.animation.status);
  }

  @override
  void didUpdateWidget(_ProbedTransition oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.animation, widget.animation))
    {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose()
  {
    widget.animation.removeStatusListener(_onStatus);
    _probe.cancel();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) => status.isAnimating ? _probe.start() : _probe.stop();

  @override
  Widget build(BuildContext context) => widget.child;
}

class PageTransitionItem extends StatelessWidget
{
  static const int frame = 0;

  static const int header = 1;

  static const int list = 2;

  final int? slot;
  final Widget child;

  const PageTransitionItem({
    super.key,
    required int this.slot,
    required this.child,
  });

  const PageTransitionItem.wave({
    super.key,
    required this.child,
  }) : slot = null;

  @override
  Widget build(BuildContext context)
  {
    final scope = _PageTransitionScope.maybeOf(context);
    final int? slot = this.slot;

    return _WaveItem(
      progress: scope?.progress ?? 1,
      leaving: scope?.leaving ?? false,
      axis: scope?.axis ?? Axis.vertical,
      reversed: scope?.reversed ?? false,
      window: MediaQuery.sizeOf(context),
      fixedWait: slot == null ? null : _slotWait(slot),
      child: child,
    );
  }
}

class _WaveItem extends SingleChildRenderObjectWidget
{
  final double progress;
  final bool leaving;
  final Axis axis;
  final bool reversed;
  final Size window;

  // A slot's wait; null: from the place in its scroll view.
  final double? fixedWait;

  const _WaveItem({
    required this.progress,
    required this.leaving,
    required this.axis,
    required this.reversed,
    required this.window,
    required this.fixedWait,
    required Widget super.child,
  });

  @override
  _RenderWaveItem createRenderObject(BuildContext context)
  {
    return _RenderWaveItem(progress, leaving, axis, reversed, window, fixedWait);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderWaveItem renderObject)
  {
    renderObject
      ..progress = progress
      ..leaving = leaving
      ..axis = axis
      ..reversed = reversed
      ..window = window
      ..fixedWait = fixedWait;
  }
}

class _RenderWaveItem extends RenderProxyBox
{
  double _progress;
  bool _leaving;
  Axis _axis;
  bool _reversed;
  Size _window;
  double? _fixedWait;

  double? _wait;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  _RenderWaveItem(this._progress, this._leaving, this._axis, this._reversed, this._window, this._fixedWait);

  bool get _moving => _leaving || _progress < 1;

  // How far through its way in: 0 while leaving, 1 at rest.
  double get arrival
  {
    if (_leaving)
    {
      return 0;
    }

    return _progress >= 1 ? 1 : _slotProgress(_progress, wait: _wait ?? _waitForPlace(), leaving: false);
  }

  set progress(double value)
  {
    if (_progress == value)
    {
      return;
    }

    final bool was = _moving;
    _progress = value;

    if (was != _moving)
    {
      _wait = null;
      markNeedsCompositingBitsUpdate();
    }

    markNeedsPaint();
  }

  set leaving(bool value)
  {
    if (_leaving == value)
    {
      return;
    }

    final bool was = _moving;
    _leaving = value;
    _wait = null;

    if (was != _moving)
    {
      markNeedsCompositingBitsUpdate();
    }

    markNeedsPaint();
  }

  set axis(Axis value)
  {
    if (_axis == value)
    {
      return;
    }

    _axis = value;
    markNeedsPaint();
  }

  set reversed(bool value)
  {
    if (_reversed == value)
    {
      return;
    }

    _reversed = value;
    markNeedsPaint();
  }

  set window(Size value)
  {
    if (_window == value)
    {
      return;
    }

    _window = value;
    _wait = null;
    markNeedsPaint();
  }

  set fixedWait(double? value)
  {
    if (_fixedWait == value)
    {
      return;
    }

    _fixedWait = value;
    _wait = null;
    markNeedsPaint();
  }

  @override
  void performLayout()
  {
    super.performLayout();
    _wait = null;
  }

  @override
  void dispose()
  {
    _clip.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _moving;

  double get _elapsed => _slotProgress(_progress, wait: _wait ??= _waitForPlace(), leaving: _leaving);

  Offset _shiftAt(double elapsed)
  {
    final bool sideways = _axis == Axis.horizontal;
    final double extent = sideways ? _window.width : _window.height;

    final double travelled = (_reversed ? -1 : 1) *
        (_leaving
            ? _exitOffset(elapsed, _exitTravel(extent))
            : _enterOffset(elapsed, _enterTravel(extent)));

    return sideways ? Offset(travelled, 0) : Offset(0, travelled);
  }

  // The nearest scroll view's visible area, here and at rest; null outside a scroll view.
  Rect? _restView()
  {
    final List<RenderObject> chain = [this];
    RenderObject? node = parent;

    while (node != null && node is! RenderAbstractViewport)
    {
      chain.add(node);
      node = node.parent;
    }

    if (node is! RenderBox || !node.hasSize)
    {
      return null;
    }

    chain.add(node);

    final Matrix4 transform = Matrix4.identity();

    for (var index = chain.length - 1; index > 0; index--)
    {
      // An enclosing block's shift is not part of the place at rest.
      if (chain[index] is! _RenderWaveItem)
      {
        chain[index].applyPaintTransform(chain[index - 1], transform);
      }
    }

    final Rect view = MatrixUtils.inverseTransformRect(transform, Offset.zero & node.size);

    // On the side blocks come in from, the scroll view's own edge cuts them, as when scrolling.
    final double reach = size.longestSide + _window.longestSide;

    return switch ((_axis, _reversed))
    {
      (Axis.vertical, false) => Rect.fromLTRB(view.left, view.top, view.right, view.bottom + reach),
      (Axis.vertical, true) => Rect.fromLTRB(view.left, view.top - reach, view.right, view.bottom),
      (Axis.horizontal, false) => Rect.fromLTRB(view.left, view.top, view.right + reach, view.bottom),
      (Axis.horizontal, true) => Rect.fromLTRB(view.left - reach, view.top, view.right, view.bottom),
    };
  }

  double _waitForPlace()
  {
    final double? fixed = _fixedWait;

    if (fixed != null)
    {
      return fixed;
    }

    final RenderObject? viewport = RenderAbstractViewport.maybeOf(this);

    if (viewport is! RenderBox || !viewport.hasSize || !hasSize)
    {
      return _listWait;
    }

    final Size view = viewport.size;

    if (view.isEmpty)
    {
      return _listWait;
    }

    final Offset here = localToGlobal(Offset.zero, ancestor: viewport);

    final double down = (here.dy / view.height).clamp(0.0, 1.0);
    final double across = (here.dx / view.width).clamp(0.0, 1.0);

    return _listWait + down * _waveDown + across * _waveAcross;
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    final RenderBox? child = this.child;

    if (child == null)
    {
      return;
    }

    if (!_moving)
    {
      layer = null;
      _clip.layer = null;
      context.paintChild(child, offset);

      return;
    }

    final double elapsed = _elapsed;
    final Offset shift = _shiftAt(elapsed);

    final double opacity = _leaving ? _exitOpacity(elapsed) : _enterOpacity(elapsed);
    final int alpha = (opacity * 255).round().clamp(0, 255);

    // Scroll views let moving blocks out: each shows only what showed of it at rest.
    final Rect? view = alpha == 0 ? null : _restView();
    final Rect bounds = Offset.zero & size;

    if (alpha == 0 || (view != null && !view.overlaps(bounds)))
    {
      layer = null;
      _clip.layer = null;

      return;
    }

    final bool cut = view != null &&
        (view.left > bounds.left || view.top > bounds.top || view.right < bounds.right || view.bottom < bounds.bottom);

    void paintShown(PaintingContext inner, Offset innerOffset)
    {
      if (!cut)
      {
        _clip.layer = null;
        inner.paintChild(child, innerOffset);

        return;
      }

      _clip.layer = inner.pushClipRect(
        needsCompositing,
        innerOffset,
        view,
        (PaintingContext clipped, Offset clippedOffset) => clipped.paintChild(child, clippedOffset),
        oldLayer: _clip.layer,
      );
    }

    if (alpha == 255)
    {
      layer = null;
      paintShown(context, offset + shift);

      return;
    }

    layer = context.pushOpacity(offset + shift, alpha, paintShown, oldLayer: layer as OpacityLayer?);
  }

  // Asked of whatever is not painted too, such as a block still faded out.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform)
  {
    if (_moving)
    {
      final Offset shift = _shiftAt(_elapsed);
      transform.translateByDouble(shift.dx, shift.dy, 0, 1);
    }
  }
}

List<Widget> pageTransitionBlocks(List<Widget> children)
{
  var slot = PageTransitionItem.header;

  return [
    for (final child in children)
      if (child is SizedBox && child.child == null)
        child
      else
        PageTransitionItem(slot: slot++, child: child),
  ];
}

class PageTransitionScrollView extends StatelessWidget
{
  final Widget? child;

  final List<Widget>? slivers;

  final ScrollController? controller;

  const PageTransitionScrollView({super.key, required Widget this.child, this.controller}) : slivers = null;

  const PageTransitionScrollView.slivers({super.key, required List<Widget> this.slivers, this.controller})
      : child = null;

  @override
  Widget build(BuildContext context)
  {
    final List<Widget>? slivers = this.slivers;

    return _TravelClip(
      sides: false,
      clipsAtRest: true,
      child: ScrollEdgeFade(
        child: slivers == null
            ? SingleChildScrollView(controller: controller, clipBehavior: Clip.none, child: child!)
            : CustomScrollView(controller: controller, clipBehavior: Clip.none, slivers: slivers),
      ),
    );
  }
}

// The clip of a scroll view of blocks: open while the page moves, except where it hides content.
class _TravelClip extends StatefulWidget
{
  // A vertical move opens the sides too.
  final bool sides;

  final bool clipsAtRest;

  final Widget child;

  const _TravelClip({required this.sides, required this.clipsAtRest, required this.child});

  @override
  State<_TravelClip> createState() => _TravelClipState();
}

class _TravelClipState extends State<_TravelClip>
{
  bool _overflows = false;

  bool _measure(ScrollMetricsNotification notification)
  {
    final ScrollMetrics metrics = notification.metrics;
    final bool overflows = metrics.maxScrollExtent > metrics.minScrollExtent;

    if (notification.depth == 0 && overflows != _overflows)
    {
      setState(() => _overflows = overflows);
    }

    return false;
  }

  @override
  Widget build(BuildContext context)
  {
    final bool moving = _PageMotion.maybeOf(context)?.moving ?? false;

    // Content that fits hides nothing past an edge: moving, it needs no cut.
    final Clip clip = moving
        ? (_overflows ? Clip.hardEdge : Clip.none)
        : (widget.clipsAtRest ? Clip.hardEdge : Clip.none);

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _measure,
      child: ClipRect(
        clipper: _OverhangClip(_travelOpening(context, sides: widget.sides)),
        clipBehavior: clip,
        child: widget.child,
      ),
    );
  }
}

// Open while the page moves, but on the side blocks come in from; [sides] also opens sideways.
EdgeInsets _travelOpening(BuildContext context, {required bool sides})
{
  final _PageMotion? motion = _PageMotion.maybeOf(context);

  if (motion == null || !motion.moving)
  {
    return EdgeInsets.zero;
  }

  final Size window = MediaQuery.sizeOf(context);

  if (motion.axis == Axis.horizontal)
  {
    return EdgeInsets.symmetric(horizontal: window.width);
  }

  final double across = sides ? window.width : 0;

  return motion.reversed
      ? EdgeInsets.only(left: across, right: across, bottom: window.height)
      : EdgeInsets.only(left: across, right: across, top: window.height);
}

class _OverhangClip extends CustomClipper<Rect>
{
  final EdgeInsets overhang;

  const _OverhangClip(this.overhang);

  @override
  Rect getClip(Size size) => overhang.inflateRect(Offset.zero & size);

  @override
  bool shouldReclip(_OverhangClip oldClipper) => oldClipper.overhang != overhang;
}

// A SingleChildScrollView of blocks: clipped at rest, open while the page moves.
class TransitionScrollView extends StatelessWidget
{
  final EdgeInsetsGeometry? padding;

  final ScrollPhysics? physics;

  final ScrollController? controller;

  final Widget child;

  const TransitionScrollView({super.key, this.padding, this.physics, this.controller, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final bool moving = _PageMotion.maybeOf(context)?.moving ?? false;

    return _TravelClip(
      sides: true,
      clipsAtRest: false,
      child: SingleChildScrollView(
        controller: controller,
        physics: physics,
        padding: padding,
        clipBehavior: moving ? Clip.none : Clip.hardEdge,
        child: child,
      ),
    );
  }
}

// Whether the page around is moving, and which way; changes twice a transition, not every frame.
class _PageMotion extends InheritedWidget
{
  final bool moving;

  final Axis axis;

  final bool reversed;

  const _PageMotion({required this.moving, required this.axis, required this.reversed, required super.child});

  static _PageMotion? maybeOf(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_PageMotion>();
  }

  @override
  bool updateShouldNotify(_PageMotion oldWidget) =>
      oldWidget.moving != moving || oldWidget.axis != axis || oldWidget.reversed != reversed;
}

// Room for shadows at the edges; under the least gap between sections and the parts around them.
const double _sectionsClipOutset = 14;

class _SectionsClip extends CustomClipper<Rect>
{
  const _SectionsClip();

  @override
  Rect getClip(Size size) => (Offset.zero & size).inflate(_sectionsClipOutset);

  @override
  bool shouldReclip(_SectionsClip oldClipper) => false;
}

double _slotProgress(double progress, {required double wait, required bool leaving})
{
  final double start = (leaving ? 0.0 : _enterStart) + wait;
  final double span = leaving ? _exitSpan : _enterSpan;

  return ((progress - start) / span).clamp(0.0, 1.0);
}

double _slotWait(int slot)
{
  return slot.clamp(0, _lastDelayedSlot) * _slotDelay;
}

double _exitOffset(double elapsed, double travel)
{
  if (elapsed <= _runUpShare)
  {
    return _runUp * Curves.easeOut.transform(elapsed / _runUpShare);
  }

  final double dash = (elapsed - _runUpShare) / (1 - _runUpShare);

  return _runUp + (-travel - _runUp) * Curves.easeIn.transform(dash);
}

double _enterOffset(double elapsed, double travel)
{
  if (elapsed <= _overshootShare)
  {
    return travel + (-_overshoot - travel) * Curves.easeOutCubic.transform(elapsed / _overshootShare);
  }

  final double settle = (elapsed - _overshootShare) / (1 - _overshootShare);

  return -_overshoot * (1 - Curves.easeInOut.transform(settle));
}

double _exitOpacity(double elapsed) => 1 - ((elapsed - 0.45) / 0.5).clamp(0.0, 1.0);

// Share of a block's way in over which it fades in; the rest it travels fully opaque.
const double _enterFade = 0.45;

double _enterOpacity(double elapsed) => (elapsed / _enterFade).clamp(0.0, 1.0);

double _arrivalOpacity(double progress)
{
  return ((progress - _arrivalFadeStart) / (_arrivalFadeEnd - _arrivalFadeStart)).clamp(0.0, 1.0);
}

class _PageTransitionScope extends InheritedWidget
{
  final double progress;

  final bool leaving;

  final Axis axis;

  final bool reversed;

  bool get moving => leaving || progress < 1;

  const _PageTransitionScope({
    required this.progress,
    required this.leaving,
    required this.axis,
    this.reversed = false,
    required super.child,
  });

  static _PageTransitionScope? maybeOf(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_PageTransitionScope>();
  }

  @override
  bool updateShouldNotify(_PageTransitionScope oldWidget)
  {
    return oldWidget.progress != progress ||
        oldWidget.leaving != leaving ||
        oldWidget.axis != axis ||
        oldWidget.reversed != reversed;
  }
}

class ShellDestinations extends StatelessWidget
{
  final int currentIndex;

  final List<Widget> children;

  final bool reversed;

  const ShellDestinations({
    super.key,
    required this.currentIndex,
    required this.children,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return _Handover(
      index: currentIndex,
      step: null,
      axis: Axis.horizontal,
      fit: StackFit.expand,
      announces: true,
      fadesWhenPlain: false,
      reversed: reversed,
      children: children,
    );
  }
}

class PageSections extends StatelessWidget
{
  final int index;

  final Object? step;

  final List<Widget> children;

  final bool reversed;

  const PageSections({
    super.key,
    required this.index,
    this.step,
    required this.children,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return _Handover(
      index: index,
      step: step,
      axis: Axis.vertical,
      fit: StackFit.loose,
      announces: false,
      fadesWhenPlain: true,
      reversed: reversed,
      children: children,
    );
  }
}

class _Handover extends StatefulWidget
{
  final int index;

  final Object? step;

  final Axis axis;
  final StackFit fit;

  final bool announces;

  // Effects off: sections fade in, whole areas switch at once.
  final bool fadesWhenPlain;

  final List<Widget> children;

  final bool reversed;

  const _Handover({
    required this.index,
    required this.step,
    required this.axis,
    required this.fit,
    required this.announces,
    required this.fadesWhenPlain,
    required this.children,
    this.reversed = false,
  });

  @override
  State<_Handover> createState() => _HandoverState();
}

class _HandoverState extends State<_Handover> with TickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pageTransition,
    value: 1,
  );

  // The arriving section fades in, the leaving one is gone at once.
  late final AnimationController _plainFade = AnimationController(
    vsync: this,
    duration: VisualEffects.plainFade,
    value: 1,
  );

  late int _arriving = widget.index;

  int? _leaving;

  Widget? _held;

  // Where to move once the cover coming down is opaque.
  int? _pending;

  // A screen pushed over this route, coming or going.
  Animation<double>? _covering;

  final TransitionProbe _probe = TransitionProbe();

  @override
  void initState()
  {
    super.initState();
    _controller.addListener(_onProgress);
    _controller.addStatusListener(_onStatusChanged);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final Animation<double>? covering = ModalRoute.of(context)?.secondaryAnimation;

    if (covering != _covering)
    {
      _covering?.removeListener(_onCoverProgress);
      _covering = covering?..addListener(_onCoverProgress);
    }
  }

  bool get _covered => _covering != null && !_covering!.isDismissed;

  // Still see-through: the cover has just started to rise.
  bool get _coverRising =>
      _covering?.status == AnimationStatus.forward && _covering!.value < _coverRise;

  void _moveNow(int index)
  {
    _arriving = index;
    _leaving = null;
    _held = null;
    _controller.value = 1;
  }

  // Deferred move runs once the cover is opaque, or as a handover if the cover lifted instead.
  void _onCoverProgress()
  {
    final int? pending = _pending;
    final Animation<double> covering = _covering!;

    if (pending == null)
    {
      return;
    }

    if (covering.value >= _coverRise)
    {
      setState(()
      {
        _pending = null;
        _moveNow(pending);
      });
    }
    else if (covering.isDismissed)
    {
      setState(()
      {
        _pending = null;
        _leaving = _arriving;
        _arriving = pending;
        _held = null;
      });
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(_Handover oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.index == _arriving)
    {
      _pending = null;
    }

    if (widget.index != _arriving)
    {
      // Under a cover still rising: stay put, the move would show through.
      if (_coverRising)
      {
        _pending = widget.index;

        return;
      }

      _pending = null;

      // Inside a moving page or under a screen the local handover would show through: jump instead.
      if ((_PageTransitionScope.maybeOf(context)?.moving ?? false) || _covered)
      {
        _moveNow(widget.index);

        return;
      }

      if (!VisualEffects.on)
      {
        _moveNow(widget.index);

        if (widget.fadesWhenPlain)
        {
          _plainFade.forward(from: 0);
        }

        return;
      }

      final int left = _arriving;

      _arriving = widget.index;
      _held = null;

      _leaving = left;

      _controller.forward(from: 0);

      return;
    }

    if (widget.step == oldWidget.step || _leaving != null || _arriving >= oldWidget.children.length)
    {
      return;
    }

    if (!VisualEffects.on)
    {
      _plainFade.forward(from: 0);

      return;
    }

    if (_held == null || _controller.value >= _reentryTurn)
    {
      _held = oldWidget.children[_arriving];
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose()
  {
    _covering?.removeListener(_onCoverProgress);
    _probe.cancel();
    _plainFade.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Dropped at _exitEnd: kept longer, the leaving section stays laid out under the arriving one.
  void _onProgress()
  {
    if (_leaving != null && _controller.value >= _exitEnd)
    {
      setState(() => _leaving = null);
    }
  }

  void _onStatusChanged(AnimationStatus status)
  {
    status.isAnimating ? _probe.start() : _probe.stop();

    if (status == AnimationStatus.completed && (_leaving != null || _held != null))
    {
      setState(()
      {
        _leaving = null;
        _held = null;
      });
    }
  }

  Widget _child(int index, double progress, _PageTransitionScope? outer, {required bool covered})
  {
    final bool arriving = index == _arriving;
    final bool leaving = index == _leaving;
    final bool onScreen = arriving || leaving;

    final bool inPlace = _held != null && arriving;
    final bool emptying = inPlace && progress < _reentryTurn;

    final bool upper = _leaving != null && index == (_arriving > _leaving! ? _arriving : _leaving!);

    final double opacity = !upper
        ? (arriving ? _plainFade.value : 1)
        : (arriving ? _arrivalOpacity(progress) : 1 - _arrivalOpacity(progress));

    final double shownProgress = onScreen
        ? (outer?.progress ?? (inPlace ? _reentryProgress(progress) : progress))
        : 1;
    final bool shownLeaving = onScreen && (outer?.leaving ?? (inPlace ? emptying : leaving));
    final Axis shownAxis = onScreen ? (outer?.axis ?? widget.axis) : widget.axis;
    final bool shownReversed = outer?.reversed ?? widget.reversed;

    return Offstage(
      offstage: !onScreen,
      child: TickerMode(
        enabled: onScreen,
        child: IgnorePointer(
          ignoring: !arriving || _controller.isAnimating || inPlace,
          child: _DestinationScope(
            current: widget.announces
                ? arriving && !covered
                : _DestinationScope.of(context),
            child: _PageTransitionScope(
              progress: shownProgress,
              leaving: shownLeaving,
              axis: shownAxis,
              reversed: shownReversed,
              child: _PageMotion(
                moving: shownLeaving || shownProgress < 1,
                axis: shownAxis,
                reversed: shownReversed,
                child: Opacity(
                  opacity: opacity,
                  child: emptying ? _held! : widget.children[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final enclosing = _PageTransitionScope.maybeOf(context);
    final outer = (enclosing != null && enclosing.moving) ? enclosing : null;

    final Animation<double>? covering = _covering;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _plainFade, covering]),
      builder: (context, _)
      {
        final bool covered = (covering?.value ?? 0) > 0;

        // Sections moving on their own keep to their area, off the fixed parts of the page.
        final bool kept = widget.axis == Axis.vertical &&
            outer == null &&
            (_leaving != null || _held != null || _controller.isAnimating);

        return ClipRect(
          clipper: const _SectionsClip(),
          clipBehavior: kept ? Clip.hardEdge : Clip.none,
          child: Stack(
            fit: widget.fit,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                _child(i, _controller.value, outer, covered: covered),
            ],
          ),
        );
      },
    );
  }
}

mixin SectionVisits<T extends StatefulWidget> on State<T>
{
  final Set<int> visitedSections = {};

  void openSection(int index, VoidCallback show)
  {
    if (!visitedSections.add(index))
    {
      setState(show);

      return;
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(show);
      }
    });
  }
}

mixin DestinationRefresh<T extends StatefulWidget> on State<T>
{
  bool? _wasShown;

  // As of the last dependency change; true before the first.
  bool get destinationShown => _wasShown ?? true;

  void onDestinationShown();

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final bool shown = _DestinationScope.of(context);

    if (_wasShown == false && shown)
    {
      onDestinationShown();
    }

    _wasShown = shown;
  }
}

// Whether the enclosing destination is on show and uncovered; true outside a shell.
bool isDestinationShown(BuildContext context) => _DestinationScope.of(context);

// As isDestinationShown, read without depending on it.
bool isDestinationShownNow(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_DestinationScope>()?.current ?? true;

// Whether the page around [context] is still coming in or going; read without depending on it.
bool isPageTransitionMoving(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_PageTransitionScope>()?.moving ?? false;

// How far the blocks holding [context] are on their way in: 0 while leaving, 1 at rest.
double _arrivalOf(BuildContext context)
{
  final _PageTransitionScope? scope = context.getInheritedWidgetOfExactType<_PageTransitionScope>();

  if (scope == null || !scope.moving)
  {
    return 1;
  }

  if (scope.leaving)
  {
    return 0;
  }

  double least = 1;
  bool inner = false;
  bool past = false;

  // Blocks inside blocks each carry it their own way: the latest to arrive counts.
  context.visitAncestorElements((element)
  {
    final Widget widget = element.widget;
    double? arrival;

    if (widget is _PageTransitionScope)
    {
      past = true;
    }
    else if (widget is PageTransitionItem && widget.slot != null)
    {
      final _PageTransitionScope? outer = element.getInheritedWidgetOfExactType<_PageTransitionScope>();

      arrival = outer == null || !outer.moving
          ? 1
          : outer.leaving
              ? 0
              : _slotProgress(outer.progress, wait: _slotWait(widget.slot!), leaving: false);
    }
    else if (widget is _WaveItem && element.renderObject is _RenderWaveItem)
    {
      arrival = (element.renderObject! as _RenderWaveItem).arrival;
    }

    if (arrival != null)
    {
      inner = inner || !past;

      if (arrival < least)
      {
        least = arrival;
      }
    }

    return true;
  });

  // Outside any block of its own section, it settles only with the whole section.
  return inner ? least : 0;
}

// Whether the part at [context] is still out of sight with its page: leaving, or not yet faded in.
bool isPageTransitionPartComing(BuildContext context) => _arrivalOf(context) < _enterFade;

// Whether the part at [context] still travels with its page, its block not yet at rest.
bool isPageTransitionPartMoving(BuildContext context) => _arrivalOf(context) < 1;

class _DestinationScope extends InheritedWidget
{
  final bool current;

  const _DestinationScope({required this.current, required super.child});

  static bool of(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_DestinationScope>()?.current ?? true;
  }

  @override
  bool updateShouldNotify(_DestinationScope oldWidget) => oldWidget.current != current;
}

class _ScreenTransition extends StatelessWidget
{
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _ScreenTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context)
  {
    final overlayAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: _coverRise,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: _coverHold),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1 - _coverRise - _coverHold,
      ),
    ]).animate(animation);

    final pageOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    ]).animate(animation);

    return AnimatedBuilder(
      animation: Listenable.merge([overlayAnimation, secondaryAnimation]),
      builder: (context, _)
      {
        final double blurIntensity = overlayAnimation.value * 20.0;
        final double backgroundOpacity = overlayAnimation.value;

        // A route on its way out under an arriving one is blurred by that one already.
        final bool covered = secondaryAnimation.value > 0;

        final Widget cover = Container(
          color: AppTheme.surface.withValues(alpha: backgroundOpacity),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: pageOpacity,
              child: child,
            ),
            if (overlayAnimation.value > 0)
              AbsorbPointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Skipped when invisible: opaque cover, another route's blur, or too faint.
                    if (backgroundOpacity >= 1 || covered || blurIntensity < 0.5)
                      cover
                    else
                      BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurIntensity > 0.1 ? blurIntensity : 0.1,
                          sigmaY: blurIntensity > 0.1 ? blurIntensity : 0.1,
                        ),
                        child: cover,
                      ),
                    Opacity(
                      opacity: overlayAnimation.value,
                      child: const CasaMichelaLoader(isOverlay: false),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
