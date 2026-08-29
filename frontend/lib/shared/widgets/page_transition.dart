import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import 'casa_michela_loader.dart';

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

CustomTransitionPage<void> buildAppTransitionPage({
  required LocalKey key,
  required Widget child,
})
{
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    opaque: false,
    transitionDuration: _pageTransition,
    reverseTransitionDuration: _pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child)
    {
      return _ScreenTransition(animation: animation, child: child);
    },
  );
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

    if (slot == null)
    {
      return _WaveItem(
        progress: scope?.progress ?? 1,
        leaving: scope?.leaving ?? false,
        axis: scope?.axis ?? Axis.vertical,
        window: MediaQuery.sizeOf(context),
        child: child,
      );
    }

    Offset offset = Offset.zero;
    double opacity = 1;

    if (scope != null)
    {
      final Size window = MediaQuery.sizeOf(context);

      final bool sideways = scope.axis == Axis.horizontal;
      final double extent = sideways ? window.width : window.height;

      final double elapsed =
          _slotProgress(scope.progress, wait: _slotWait(slot), leaving: scope.leaving);

      final double travelled = scope.leaving
          ? _exitOffset(elapsed, _exitTravel(extent))
          : _enterOffset(elapsed, _enterTravel(extent));

      offset = sideways ? Offset(travelled, 0) : Offset(0, travelled);
      opacity = scope.leaving ? _exitOpacity(elapsed) : _enterOpacity(elapsed);
    }

    return Transform.translate(
      offset: offset,
      child: Opacity(opacity: opacity, child: child),
    );
  }
}

class _WaveItem extends SingleChildRenderObjectWidget
{
  final double progress;
  final bool leaving;
  final Axis axis;
  final Size window;

  const _WaveItem({
    required this.progress,
    required this.leaving,
    required this.axis,
    required this.window,
    required Widget super.child,
  });

  @override
  _RenderWaveItem createRenderObject(BuildContext context)
  {
    return _RenderWaveItem(progress, leaving, axis, window);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderWaveItem renderObject)
  {
    renderObject
      ..progress = progress
      ..leaving = leaving
      ..axis = axis
      ..window = window;
  }
}

class _RenderWaveItem extends RenderProxyBox
{
  double _progress;
  bool _leaving;
  Axis _axis;
  Size _window;

  Offset _shift = Offset.zero;

  double? _wait;

  _RenderWaveItem(this._progress, this._leaving, this._axis, this._window);

  bool get _moving => _leaving || _progress < 1;

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

  @override
  void performLayout()
  {
    super.performLayout();
    _wait = null;
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _moving;

  double _waitForPlace()
  {
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
      _shift = Offset.zero;
      layer = null;
      context.paintChild(child, offset);

      return;
    }

    final bool sideways = _axis == Axis.horizontal;
    final double extent = sideways ? _window.width : _window.height;

    final double wait = _wait ??= _waitForPlace();
    final double elapsed = _slotProgress(_progress, wait: wait, leaving: _leaving);

    final double travelled = _leaving
        ? _exitOffset(elapsed, _exitTravel(extent))
        : _enterOffset(elapsed, _enterTravel(extent));

    _shift = sideways ? Offset(travelled, 0) : Offset(0, travelled);

    final double opacity = _leaving ? _exitOpacity(elapsed) : _enterOpacity(elapsed);
    final int alpha = (opacity * 255).round().clamp(0, 255);

    if (alpha == 0)
    {
      layer = null;

      return;
    }

    if (alpha == 255)
    {
      layer = null;
      context.paintChild(child, offset + _shift);

      return;
    }

    layer = context.pushOpacity(
      offset + _shift,
      alpha,
      (PaintingContext inner, Offset innerOffset) => inner.paintChild(child, innerOffset),
      oldLayer: layer as OpacityLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform)
  {
    transform.translateByDouble(_shift.dx, _shift.dy, 0, 1);
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

  const PageTransitionScrollView({super.key, required Widget this.child}) : slivers = null;

  const PageTransitionScrollView.slivers({super.key, required List<Widget> this.slivers})
      : child = null;

  @override
  Widget build(BuildContext context)
  {
    final scope = _PageTransitionScope.maybeOf(context);

    final bool opening = scope != null && scope.moving && scope.axis == Axis.horizontal;
    final double overhang = opening ? MediaQuery.sizeOf(context).width : 0;

    final List<Widget>? slivers = this.slivers;

    return ClipRect(
      clipper: _SidewaysClip(overhang),
      child: slivers == null
          ? SingleChildScrollView(clipBehavior: Clip.none, child: child!)
          : CustomScrollView(clipBehavior: Clip.none, slivers: slivers),
    );
  }
}

class _SidewaysClip extends CustomClipper<Rect>
{
  final double overhang;

  const _SidewaysClip(this.overhang);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-overhang, 0, size.width + overhang, size.height);

  @override
  bool shouldReclip(_SidewaysClip oldClipper) => oldClipper.overhang != overhang;
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

double _enterOpacity(double elapsed) => (elapsed / 0.45).clamp(0.0, 1.0);

double _arrivalOpacity(double progress)
{
  return ((progress - _arrivalFadeStart) / (_arrivalFadeEnd - _arrivalFadeStart)).clamp(0.0, 1.0);
}

class _PageTransitionScope extends InheritedWidget
{
  final double progress;

  final bool leaving;

  final Axis axis;

  bool get moving => leaving || progress < 1;

  const _PageTransitionScope({
    required this.progress,
    required this.leaving,
    required this.axis,
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
        oldWidget.axis != axis;
  }
}

class ShellDestinations extends StatelessWidget
{
  final int currentIndex;

  final List<Widget> children;

  const ShellDestinations({
    super.key,
    required this.currentIndex,
    required this.children,
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
      children: children,
    );
  }
}

class PageSections extends StatelessWidget
{
  final int index;

  final Object? step;

  final List<Widget> children;

  const PageSections({
    super.key,
    required this.index,
    this.step,
    required this.children,
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

  final List<Widget> children;

  const _Handover({
    required this.index,
    required this.step,
    required this.axis,
    required this.fit,
    required this.announces,
    required this.children,
  });

  @override
  State<_Handover> createState() => _HandoverState();
}

class _HandoverState extends State<_Handover> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pageTransition,
    value: 1,
  );

  late int _arriving = widget.index;

  int? _leaving;

  Widget? _held;

  @override
  void initState()
  {
    super.initState();
    _controller.addListener(_onProgress);
    _controller.addStatusListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(_Handover oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.index != _arriving)
    {
      final int left = _arriving;

      _arriving = widget.index;
      _held = null;

      // Inside a moving page: skip the local handover, it would paint both
      // sections at once over the outer one.
      if (_PageTransitionScope.maybeOf(context)?.moving ?? false)
      {
        _leaving = null;
        _controller.value = 1;

        return;
      }

      _leaving = left;

      _controller.forward(from: 0);

      return;
    }

    if (widget.step == oldWidget.step || _leaving != null || _arriving >= oldWidget.children.length)
    {
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
    _controller.dispose();
    super.dispose();
  }

  // The leaving section is dropped at _exitEnd: held to the end of the handover
  // it would stay laid out, and visible, under the arriving one.
  void _onProgress()
  {
    if (_leaving != null && _controller.value >= _exitEnd)
    {
      setState(() => _leaving = null);
    }
  }

  void _onStatusChanged(AnimationStatus status)
  {
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
        ? 1
        : (arriving ? _arrivalOpacity(progress) : 1 - _arrivalOpacity(progress));

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
              progress: onScreen
                  ? (outer?.progress ?? (inPlace ? _reentryProgress(progress) : progress))
                  : 1,
              leaving: onScreen && (outer?.leaving ?? (inPlace ? emptying : leaving)),
              axis: onScreen ? (outer?.axis ?? widget.axis) : widget.axis,
              child: Opacity(
                opacity: opacity,
                child: emptying ? _held! : widget.children[index],
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

    final Animation<double>? covering = ModalRoute.of(context)?.secondaryAnimation;

    return AnimatedBuilder(
      animation: covering == null
          ? _controller
          : Listenable.merge([_controller, covering]),
      builder: (context, _)
      {
        final bool covered = (covering?.value ?? 0) > 0;

        return Stack(
          fit: widget.fit,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _child(i, _controller.value, outer, covered: covered),
          ],
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
  final Widget child;

  const _ScreenTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final overlayAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(animation);

    final pageOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    ]).animate(animation);

    return AnimatedBuilder(
      animation: overlayAnimation,
      builder: (context, _)
      {
        final double blurIntensity = overlayAnimation.value * 20.0;
        final double backgroundOpacity = overlayAnimation.value;

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
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurIntensity > 0.1 ? blurIntensity : 0.1,
                        sigmaY: blurIntensity > 0.1 ? blurIntensity : 0.1,
                      ),
                      child: Container(
                        color: Colors.white.withValues(
                          alpha: backgroundOpacity,
                        ),
                      ),
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
